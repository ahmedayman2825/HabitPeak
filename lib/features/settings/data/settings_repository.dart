import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_settings.dart';

class SettingsRepository {
  static const String _resetMinutesKey = 'settings.reset_minutes';
  static const String _themeModeKey = 'settings.theme_mode';
  static const String _smartNotificationsKey = 'settings.smart_notifications';
  static const String _analyticsEnabledKey = 'settings.analytics_enabled';
  static const String _lifeBalanceKey = 'settings.life_balance_score';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      resetMinutes: prefs.getInt(_resetMinutesKey) ?? 0,
      themeMode: _themeFromName(prefs.getString(_themeModeKey)),
      smartNotificationsEnabled: prefs.getBool(_smartNotificationsKey) ?? false,
      analyticsEnabled: prefs.getBool(_analyticsEnabledKey) ?? true,
      showLifeBalanceScore: prefs.getBool(_lifeBalanceKey) ?? true,
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_resetMinutesKey, settings.resetMinutes);
    await prefs.setString(_themeModeKey, settings.themeMode.name);
    await prefs.setBool(
      _smartNotificationsKey,
      settings.smartNotificationsEnabled,
    );
    await prefs.setBool(_analyticsEnabledKey, settings.analyticsEnabled);
    await prefs.setBool(_lifeBalanceKey, settings.showLifeBalanceScore);
  }

  ThemeMode _themeFromName(String? name) {
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == name,
      orElse: () => ThemeMode.system,
    );
  }
}
