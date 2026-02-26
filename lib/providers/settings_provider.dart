import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/settings_service.dart';
import '../services/claude_api.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden');
});

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService(ref.watch(sharedPreferencesProvider));
});

final serverUrlProvider = StateProvider<String>((ref) {
  return ref.read(settingsServiceProvider).serverUrl;
});

final defaultModelProvider = StateProvider<String>((ref) {
  return ref.read(settingsServiceProvider).model;
});

final claudeApiProvider = Provider<ClaudeApi>((ref) {
  final url = ref.watch(serverUrlProvider);
  return ClaudeApi(baseUrl: url);
});

final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return ref.read(settingsServiceProvider).themeMode;
});
