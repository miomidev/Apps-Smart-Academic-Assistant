import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/storage_service.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/focus/screens/focus_stats_screen.dart';
import '../../features/home/screens/main_scaffold.dart';
import '../../features/notes/screens/voice_capture_screen.dart';
import '../../features/rps/screens/rps_upload_screen.dart';
import '../../features/settings/screens/settings_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  final storage = ref.watch(storageServiceProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (BuildContext context, GoRouterState state) {
      final isLoading = authState.isLoading;
      final isAuthenticated = authState.asData?.value != null;
      final location = state.uri.path;

      // When splash is checking session, allow splash
      if (isLoading) return null;

      final isAuthRoute = location == '/login' || location == '/splash';
      final isOnboardingRoute = location == '/onboarding';

      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      if (isAuthenticated) {
        final hasCompletedOnboarding = storage.isOnboardingCompleted();
        if (!hasCompletedOnboarding && !isOnboardingRoute) {
          return '/onboarding';
        }
        if (hasCompletedOnboarding && (isAuthRoute || isOnboardingRoute)) {
          return '/';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) {
          final tabParam = state.uri.queryParameters['tab'];
          final initialIndex = tabParam != null ? int.tryParse(tabParam) ?? 0 : 0;
          return MainScaffold(initialIndex: initialIndex);
        },
      ),
      GoRoute(
        path: '/home',
        redirect: (context, state) => '/',
      ),
      GoRoute(
        path: '/notes/voice',
        builder: (context, state) {
          final courseId = state.uri.queryParameters['courseId'];
          return VoiceCaptureScreen(preselectedCourseId: courseId);
        },
      ),
      GoRoute(
        path: '/rps/upload',
        builder: (context, state) {
          final courseId = state.uri.queryParameters['courseId'];
          return RpsUploadScreen(initialCourseId: courseId);
        },
      ),
      GoRoute(
        path: '/focus/stats',
        builder: (context, state) => const FocusStatsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
