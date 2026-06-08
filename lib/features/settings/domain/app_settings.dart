import 'package:flutter/material.dart';

class AppSettings {
  const AppSettings({
    this.resetMinutes = 0,
    this.themeMode = ThemeMode.system,
    this.smartNotificationsEnabled = false,
    this.analyticsEnabled = true,
    this.showLifeBalanceScore = true,
  });

  factory AppSettings.defaults() => const AppSettings();

  factory AppSettings.fromJson(Map<String, Object?> json) {
    return AppSettings(
      resetMinutes: json['resetMinutes'] as int? ?? 0,
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == json['themeMode'],
        orElse: () => ThemeMode.system,
      ),
      smartNotificationsEnabled:
          json['smartNotificationsEnabled'] as bool? ?? false,
      analyticsEnabled: json['analyticsEnabled'] as bool? ?? true,
      showLifeBalanceScore: json['showLifeBalanceScore'] as bool? ?? true,
    );
  }

  final int resetMinutes;
  final ThemeMode themeMode;
  final bool smartNotificationsEnabled;
  final bool analyticsEnabled;
  final bool showLifeBalanceScore;

  String get resetTimeLabel {
    final hours = resetMinutes ~/ 60;
    final minutes = resetMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  AppSettings copyWith({
    int? resetMinutes,
    ThemeMode? themeMode,
    bool? smartNotificationsEnabled,
    bool? analyticsEnabled,
    bool? showLifeBalanceScore,
  }) {
    return AppSettings(
      resetMinutes: resetMinutes ?? this.resetMinutes,
      themeMode: themeMode ?? this.themeMode,
      smartNotificationsEnabled:
          smartNotificationsEnabled ?? this.smartNotificationsEnabled,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      showLifeBalanceScore: showLifeBalanceScore ?? this.showLifeBalanceScore,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'resetMinutes': resetMinutes,
      'themeMode': themeMode.name,
      'smartNotificationsEnabled': smartNotificationsEnabled,
      'analyticsEnabled': analyticsEnabled,
      'showLifeBalanceScore': showLifeBalanceScore,
    };
  }
}
