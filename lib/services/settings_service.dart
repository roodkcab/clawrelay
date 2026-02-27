import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _keyServerUrl = 'server_url';
  static const _keyDefaultModel = 'default_model';
  static const _keyThemeMode = 'theme_mode';
  static const _keyMaxTurns = 'max_turns';

  static const defaultMaxTurns = 200;

  static const defaultServerUrl = 'http://localhost:50009';
  static const defaultModel = 'vllm/claude-sonnet-4-6';

  final SharedPreferences _prefs;

  SettingsService(this._prefs);

  String get serverUrl =>
      _prefs.getString(_keyServerUrl) ?? defaultServerUrl;

  Future<void> setServerUrl(String url) =>
      _prefs.setString(_keyServerUrl, url);

  String get model =>
      _prefs.getString(_keyDefaultModel) ?? defaultModel;

  Future<void> setDefaultModel(String model) =>
      _prefs.setString(_keyDefaultModel, model);

  ThemeMode get themeMode {
    final v = _prefs.getString(_keyThemeMode);
    return ThemeMode.values.firstWhere((e) => e.name == v, orElse: () => ThemeMode.system);
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(_keyThemeMode, mode.name);

  int get maxTurns => _prefs.getInt(_keyMaxTurns) ?? defaultMaxTurns;

  Future<void> setMaxTurns(int value) => _prefs.setInt(_keyMaxTurns, value);
}
