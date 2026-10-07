import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';
import 'api_exception.dart';
import 'api_response.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  return ApiClient(storageService);
});

class ApiClient {
  final StorageService _storageService;
  late final Dio _dio;

  ApiClient(this._storageService) {
    _dio = Dio(
      BaseOptions(
        baseUrl: _storageService.getBaseUrl(),
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Dynamically refresh base url in case user configured it
          options.baseUrl = _storageService.getBaseUrl();

          final token = _storageService.getToken();
          if (token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          final response = error.response;
          String message = 'Terjadi kesalahan jaringan atau server';
          dynamic details;

          if (response?.data != null) {
            if (response!.data is Map<String, dynamic>) {
              final body = response.data as Map<String, dynamic>;
              message = body['message']?.toString() ??
                  body['error']?.toString() ??
                  message;
              details = body['data'];
            } else if (response.data is String) {
              message = response.data as String;
            }
          } else if (error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout) {
            message = 'Koneksi ke server batas waktu habis (timeout)';
          } else if (error.type == DioExceptionType.connectionError) {
            message =
                'Gagal terhubung ke server backend di ${_storageService.getBaseUrl()}';
          }

          return handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              type: error.type,
              error: ApiException(
                message: message,
                statusCode: response?.statusCode,
                details: details,
              ),
            ),
          );
        },
      ),
    );
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic data)? fromData,
  }) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      return _handleResponse(response, fromData);
    } on DioException catch (e) {
      throw _unwrapError(e);
    }
  }

  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic data)? fromData,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return _handleResponse(response, fromData);
    } on DioException catch (e) {
      throw _unwrapError(e);
    }
  }

  Future<T> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic data)? fromData,
  }) async {
    try {
      final response = await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return _handleResponse(response, fromData);
    } on DioException catch (e) {
      throw _unwrapError(e);
    }
  }

  Future<T> delete<T>(
    String path, {
    dynamic data,
    T Function(dynamic data)? fromData,
  }) async {
    try {
      final response = await _dio.delete(path, data: data);
      return _handleResponse(response, fromData);
    } on DioException catch (e) {
      throw _unwrapError(e);
    }
  }

  Future<T> uploadFile<T>(
    String path, {
    required FormData formData,
    T Function(dynamic data)? fromData,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );
      return _handleResponse(response, fromData);
    } on DioException catch (e) {
      throw _unwrapError(e);
    }
  }

  T _handleResponse<T>(Response response, T Function(dynamic data)? fromData) {
    final rawData = response.data;
    if (rawData is Map<String, dynamic>) {
      final apiResponse = ApiResponse.fromJson(rawData, fromData);
      if (apiResponse.isSuccess && apiResponse.data != null) {
        return apiResponse.data as T;
      } else if (apiResponse.data != null) {
        return apiResponse.data as T;
      }
    }

    if (fromData != null) {
      return fromData(rawData);
    }
    return rawData as T;
  }

  ApiException _unwrapError(DioException e) {
    if (e.error is ApiException) {
      return e.error as ApiException;
    }
    return ApiException(
      message: e.message ?? 'Terjadi kesalahan jaringan',
      statusCode: e.response?.statusCode,
    );
  }
}
