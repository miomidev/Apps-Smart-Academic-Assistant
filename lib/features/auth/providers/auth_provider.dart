import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/services/storage_service.dart';
import '../models/user_model.dart';

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final storageService = ref.watch(storageServiceProvider);
  return AuthNotifier(apiClient, storageService);
});

final authProvider = authStateProvider;

class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final ApiClient _apiClient;
  final StorageService _storageService;

  AuthNotifier(this._apiClient, this._storageService)
      : super(const AsyncValue.loading()) {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    state = const AsyncValue.loading();
    try {
      final token = _storageService.getToken();
      if (token.isEmpty) {
        state = const AsyncValue.data(null);
        return;
      }

      final user = await _apiClient.get<UserModel>(
        '/me',
        fromData: (data) => UserModel.fromJson(data as Map<String, dynamic>),
      );

      await _storageService.setCachedUserJson(jsonEncode(user.toJson()));
      state = AsyncValue.data(user);
    } catch (e) {
      // Check offline cache if server is temporarily unreachable
      final cachedJson = _storageService.getCachedUserJson();
      if (cachedJson != null) {
        try {
          final user =
              UserModel.fromJson(jsonDecode(cachedJson) as Map<String, dynamic>);
          state = AsyncValue.data(user);
          return;
        } catch (_) {}
      }
      state = const AsyncValue.data(null);
    }
  }

  Future<bool> loginWithDevBypass() async {
    state = const AsyncValue.loading();
    try {
      await _storageService.setToken(ApiConfig.devToken);
      final user = await _apiClient.get<UserModel>(
        '/me',
        fromData: (data) => UserModel.fromJson(data as Map<String, dynamic>),
      );
      await _storageService.setCachedUserJson(jsonEncode(user.toJson()));
      state = AsyncValue.data(user);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(
        e is ApiException ? e.message : 'Gagal login dev bypass: $e',
        st,
      );
      return false;
    }
  }

  Future<bool> updateProfile({required String name, String? university}) async {
    final currentUser = state.value;
    if (currentUser == null) return false;

    try {
      final updated = await _apiClient.patch<UserModel>(
        '/me',
        data: {
          'name': name,
          if (university != null) 'university': university,
        },
        fromData: (data) => UserModel.fromJson(data as Map<String, dynamic>),
      );
      await _storageService.setCachedUserJson(jsonEncode(updated.toJson()));
      state = AsyncValue.data(updated);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    try {
      await _apiClient.delete('/me');
      await _storageService.clearAll();
      state = const AsyncValue.data(null);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    await _storageService.removeToken();
    state = const AsyncValue.data(null);
  }
}
