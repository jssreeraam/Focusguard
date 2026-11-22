import 'package:flutter/services.dart';

/// Native Android bridge: Accessibility blocker, Device Admin, Monotonic Lock,
/// Wakelock, Offline Brown Noise, and Daily Revision Notifications.
class Blocker {
  static const _c = MethodChannel('focusguard/blocker');

  static Future<List<Map<String, String>>> apps() async {
    try {
      final l = await _c.invokeMethod<List>('apps') ?? [];
      return l.map((e) => Map<String, String>.from(e as Map)).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> setLockDuration(List<String> pkgs, Duration duration) async {
    try {
      await _c.invokeMethod('setLock', {
        'pkgs': pkgs,
        'durationMs': duration.inMilliseconds,
      });
    } catch (_) {}
  }

  static Future<void> clearLock() async {
    try {
      await _c.invokeMethod('clearLock');
    } catch (_) {}
  }

  static Future<int> lockRemainingMs() async {
    try {
      return await _c.invokeMethod<int>('lockRemainingMs') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> setAntiTamper({
    required bool strict,
    required bool blockAllSettings,
  }) async {
    try {
      await _c.invokeMethod('setAntiTamper', {
        'strict': strict,
        'blockAllSettings': blockAllSettings,
      });
    } catch (_) {}
  }

  static Future<bool> enabled() async {
    try {
      return await _c.invokeMethod<bool>('enabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openSettings() async {
    try {
      await _c.invokeMethod('openSettings');
    } catch (_) {}
  }

  static Future<bool> isAdminEnabled() async {
    try {
      return await _c.invokeMethod<bool>('isAdminEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestAdmin() async {
    try {
      await _c.invokeMethod('requestAdmin');
    } catch (_) {}
  }

  static Future<bool> isBatteryIgnored() async {
    try {
      return await _c.invokeMethod<bool>('isBatteryIgnored') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestBatteryIgnore() async {
    try {
      await _c.invokeMethod('requestBatteryIgnore');
    } catch (_) {}
  }

  static Future<void> requestNotificationPermission() async {
    try {
      await _c.invokeMethod('requestNotificationPermission');
    } catch (_) {}
  }

  static Future<void> setWakelock(bool on) async {
    try {
      await _c.invokeMethod('setWakelock', {'on': on});
    } catch (_) {}
  }

  static Future<void> setBrownNoise(bool on) async {
    try {
      await _c.invokeMethod('setBrownNoise', {'on': on});
    } catch (_) {}
  }

  static Future<void> scheduleDailyReminder({
    required bool on,
    required int hour,
    required int minute,
    required String body,
  }) async {
    try {
      await _c.invokeMethod('scheduleDailyReminder', {
        'on': on,
        'hour': hour,
        'minute': minute,
        'body': body,
      });
    } catch (_) {}
  }

  static Future<void> showNotification(String title, String body) async {
    try {
      await _c.invokeMethod('showNotification', {'title': title, 'body': body});
    } catch (_) {}
  }
}
