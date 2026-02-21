import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeOption {
  final String id;
  final String name;
  final List<Color> gradient;

  const AppThemeOption({
    required this.id,
    required this.name,
    required this.gradient,
  });

  Color get seedColor => gradient.first;
}

class AppSettingsState {
  final String themeId;
  final ThemeMode themeMode;
  final bool biometricLoginEnabled;
  final String adminAiModel;

  const AppSettingsState({
    required this.themeId,
    required this.themeMode,
    required this.biometricLoginEnabled,
    required this.adminAiModel,
  });

  AppSettingsState copyWith({
    String? themeId,
    ThemeMode? themeMode,
    bool? biometricLoginEnabled,
    String? adminAiModel,
  }) {
    return AppSettingsState(
      themeId: themeId ?? this.themeId,
      themeMode: themeMode ?? this.themeMode,
      biometricLoginEnabled:
          biometricLoginEnabled ?? this.biometricLoginEnabled,
      adminAiModel: adminAiModel ?? this.adminAiModel,
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettingsState> {
  static const _kThemeId = 'app_theme_id';
  static const _kThemeMode = 'app_theme_mode';
  static const _kBiometricEnabled = 'biometric_login_enabled';
  static const _kAdminAiModel = 'admin_ai_model';

  AppSettingsNotifier()
      : super(const AppSettingsState(
          themeId: 'ocean_blue',
          themeMode: ThemeMode.system,
          biometricLoginEnabled: false,
          adminAiModel: 'google/gemini-2.0-flash-001',
        )) {
    _load();
  }

  static ThemeMode _themeModeFromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static const List<AppThemeOption> themes = [
    AppThemeOption(
      id: 'ocean_blue',
      name: 'Ocean Blue',
      gradient: [Color(0xFF2563EB), Color(0xFF06B6D4)],
    ),
    AppThemeOption(
      id: 'royal_purple',
      name: 'Royal Purple',
      gradient: [Color(0xFF7C3AED), Color(0xFFEC4899)],
    ),
    AppThemeOption(
      id: 'sunset_orange',
      name: 'Sunset Orange',
      gradient: [Color(0xFFF97316), Color(0xFFF43F5E)],
    ),
    AppThemeOption(
      id: 'forest_green',
      name: 'Forest Green',
      gradient: [Color(0xFF10B981), Color(0xFF22C55E)],
    ),
    AppThemeOption(
      id: 'golden_amber',
      name: 'Golden Amber',
      gradient: [Color(0xFFF59E0B), Color(0xFFFDE047)],
    ),
    AppThemeOption(
      id: 'cherry_red',
      name: 'Cherry Red',
      gradient: [Color(0xFFEF4444), Color(0xFFFB7185)],
    ),
    AppThemeOption(
      id: 'midnight',
      name: 'Midnight',
      gradient: [Color(0xFF0F172A), Color(0xFF334155)],
    ),
    AppThemeOption(
      id: 'aqua_mint',
      name: 'Aqua Mint',
      gradient: [Color(0xFF14B8A6), Color(0xFFA7F3D0)],
    ),
    AppThemeOption(
      id: 'coffee_brown',
      name: 'Coffee Brown',
      gradient: [Color(0xFF92400E), Color(0xFFD97706)],
    ),
    AppThemeOption(
      id: 'lavender_sky',
      name: 'Lavender Sky',
      gradient: [Color(0xFFA78BFA), Color(0xFF60A5FA)],
    ),
  ];

  static AppThemeOption themeById(String id) {
    return themes.firstWhere(
      (t) => t.id == id,
      orElse: () => themes.first,
    );
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeId = prefs.getString(_kThemeId);
    final themeMode = prefs.getString(_kThemeMode);
    final bio = prefs.getBool(_kBiometricEnabled);
    final adminAiModel = prefs.getString(_kAdminAiModel);

    state = state.copyWith(
      themeId: themeId ?? state.themeId,
      themeMode: _themeModeFromString(themeMode),
      biometricLoginEnabled: bio ?? state.biometricLoginEnabled,
      adminAiModel: adminAiModel ?? state.adminAiModel,
    );
  }

  Future<void> setTheme(String themeId) async {
    state = state.copyWith(themeId: themeId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeId, themeId);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, _themeModeToString(mode));
  }

  Future<void> setBiometricLoginEnabled(bool enabled) async {
    state = state.copyWith(biometricLoginEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBiometricEnabled, enabled);
  }

  Future<void> setAdminAiModel(String model) async {
    state = state.copyWith(adminAiModel: model);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAdminAiModel, model);
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettingsState>((ref) {
  return AppSettingsNotifier();
});
