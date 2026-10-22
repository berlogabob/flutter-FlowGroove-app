import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PowerReliability {
  PowerReliability({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.flowgroove/battery');

  final MethodChannel _channel;
  static const _setupSeenKey = 'power_setup_seen';

  Future<T?> _invoke<T>(String method) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      return await _channel.invokeMethod<T>(method);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<String> family() async =>
      await _invoke<String>('oemFamily') ?? 'other';

  Future<bool> ignoringOptimizations() async =>
      await _invoke<bool>('isIgnoringBatteryOptimizations') ?? false;

  Future<void> requestIgnoreOptimizations() async {
    await _invoke<void>('requestIgnoreBatteryOptimizations');
  }

  Future<bool> openVendorSettings() async =>
      await _invoke<bool>('openOemSettings') ?? false;

  Future<bool> setupSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_setupSeenKey) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> markSetupSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_setupSeenKey, true);
    } on MissingPluginException {
      // Older hosts may not expose preferences yet.
    } on PlatformException {
      // Battery guidance remains usable if preferences are unavailable.
    }
  }

  static String steps(String family) => switch (family) {
    'huawei' =>
      'Settings > Battery > App launch > FlowGroove > Manage manually > turn on Auto-launch, Secondary launch and Run in background',
    'xiaomi' =>
      'Security > Permissions > Autostart: allow FlowGroove; Settings > Apps > FlowGroove > Battery saver > No restrictions',
    'oppo' =>
      'Settings > Battery > FlowGroove > Allow background activity; allow auto-launch',
    'vivo' =>
      'Settings > Battery > Background power consumption > FlowGroove > Allow',
    'samsung' =>
      'Settings > Battery > Background usage limits > Never sleeping apps > add FlowGroove',
    _ => 'Allow unrestricted battery use for FlowGroove',
  };
}
