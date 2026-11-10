import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

class SettingsService {
  static const _key = 'resqmesh_settings_v1';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return AppSettings.defaults();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return AppSettings.defaults();
      return AppSettings.fromJson(decoded);
    } catch (_) {
      return AppSettings.defaults();
    }
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
