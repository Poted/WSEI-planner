import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  light,
  dark,
  pusheen,
}

class ThemeProvider extends ChangeNotifier {
  AppThemeMode _currentAppThemeMode;

  ThemeProvider(this._currentAppThemeMode);

  AppThemeMode get currentAppThemeMode => _currentAppThemeMode;

  bool get isDarkMode => _currentAppThemeMode == AppThemeMode.dark;
  bool get isPusheenMode => _currentAppThemeMode == AppThemeMode.pusheen;

  ThemeMode get themeMode {
    if (_currentAppThemeMode == AppThemeMode.dark) return ThemeMode.dark;
    return ThemeMode.light;
  }

  Future<void> setAppThemeMode(AppThemeMode mode) async {
    if (_currentAppThemeMode == mode) return;

    _currentAppThemeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('appThemeMode', mode.index); // Zapisujemy indeks enum
  }

  static Future<ThemeProvider> create() async {
    final prefs = await SharedPreferences.getInstance();
    final savedModeIndex = prefs.getInt('appThemeMode');
    AppThemeMode initialMode;

    if (savedModeIndex != null && savedModeIndex >= 0 && savedModeIndex < AppThemeMode.values.length) {
      initialMode = AppThemeMode.values[savedModeIndex];
    } else {
      initialMode = AppThemeMode.light;
    }
    return ThemeProvider(initialMode);
  }
}