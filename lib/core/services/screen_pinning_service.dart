import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final screenPinningServiceProvider = Provider<ScreenPinningService>((ref) {
  return ScreenPinningService();
});

class ScreenPinningService {
  static const MethodChannel _channel =
      MethodChannel('com.saa.app/screen_pinning');

  static Future<bool> startLockTask() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      debugPrint('[ScreenPinning] Not supported on current platform');
      return true;
    }
    try {
      final result = await _channel.invokeMethod<bool>('startLockTask');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[ScreenPinning] Failed to start lock task: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[ScreenPinning] Unexpected error: $e');
      return false;
    }
  }

  static Future<bool> stopLockTask() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final result = await _channel.invokeMethod<bool>('stopLockTask');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[ScreenPinning] Failed to stop lock task: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[ScreenPinning] Unexpected error: $e');
      return false;
    }
  }

  static Future<bool> isLockTaskActive() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('isLockTaskActive');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
