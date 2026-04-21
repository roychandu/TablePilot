import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class ThemeProvider extends ChangeNotifier {
  final ThemeService _themeService = ThemeService();
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    _themeMode = await _themeService.loadThemeMode();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    await _themeService.saveThemeMode(mode);
    notifyListeners();
  }

  bool isDarkMode(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }
}

/// Palette interface to ensure consistency between themes
abstract class AppPalette {
  Color get primary;
  Color get primaryHover;
  Color get primaryLight;
  Color get background;
  Color get cardBackground;
  Color get surface;
  Color get elevated;
  Color get textPrimary;
  Color get textSecondary;
  Color get textTertiary;
  Color get textDisabled;
  Color get border;
  Color get borderMuted;
  Color get divider;
  Color get success;
  Color get warning;
  Color get error;
  Color get info;
  Color get occupied;
  Color get accent1;
  Color get accent2;
}

/// Dark Mode Palette (Existing)
class DarkPalette implements AppPalette {
  @override get primary => const Color(0xFF6366F1); // Indigo 500
  @override get primaryHover => const Color(0xFF818CF8); // Indigo 400
  @override get primaryLight => const Color(0xFF312E81); // Indigo 900
  @override get background => const Color(0xFF111827); // Gray 900
  @override get cardBackground => const Color(0xFF1F2937); // Gray 800
  @override get surface => const Color(0xFF374151); // Gray 700
  @override get elevated => const Color(0xFF4B5563); // Gray 600
  @override get textPrimary => const Color(0xFFF9FAFB); // Gray 50
  @override get textSecondary => const Color(0xFFD1D5DB); // Gray 300
  @override get textTertiary => const Color(0xFF9CA3AF); // Gray 400
  @override get textDisabled => const Color(0xFF6B7280); // Gray 500
  @override get border => const Color(0xFF374151); // Gray 700
  @override get borderMuted => const Color(0xFF4B5563); // Gray 600
  @override get divider => const Color(0x26FFFFFF); // 15% white
  @override get success => const Color(0xFF10B981); // Emerald 500
  @override get warning => const Color(0xFFF59E0B); // Amber 500
  @override get error => const Color(0xFFEF4444); // Red 500
  @override get info => const Color(0xFF0EA5E9); // Sky 500
  @override get occupied => const Color(0xFF8B5CF6); // Violet 500
  @override get accent1 => const Color(0xFFEC4899); // Pink 500
  @override get accent2 => const Color(0xFF14B8A6); // Teal 500
}

/// Light Mode Palette (New)
class LightPalette implements AppPalette {
  @override get primary => const Color(0xFF4F46E5); // Indigo 600
  @override get primaryHover => const Color(0xFF4338CA); // Indigo 700
  @override get primaryLight => const Color(0xFFEEF2FF); // Indigo 50
  @override get background => const Color(0xFFF9FAFB); // Gray 50
  @override get cardBackground => const Color(0xFFFFFFFF); // White
  @override get surface => const Color(0xFFF3F4F6); // Gray 100
  @override get elevated => const Color(0xFFE5E7EB); // Gray 200
  @override get textPrimary => const Color(0xFF111827); // Gray 900
  @override get textSecondary => const Color(0xFF6B7280); // Gray 500
  @override get textTertiary => const Color(0xFF9CA3AF); // Gray 400
  @override get textDisabled => const Color(0xFFD1D5DB); // Gray 300
  @override get border => const Color(0xFFE5E7EB); // Gray 200
  @override get borderMuted => const Color(0xFFD1D5DB); // Gray 300
  @override get divider => const Color(0x1A000000); // 10% black
  @override get success => const Color(0xFF10B981); // Emerald 500
  @override get warning => const Color(0xFFF59E0B); // Amber 500
  @override get error => const Color(0xFFEF4444); // Red 500
  @override get info => const Color(0xFF0EA5E9); // Sky 500
  @override get occupied => const Color(0xFF8B5CF6); // Violet 500
  @override get accent1 => const Color(0xFFEC4899); // Pink 500
  @override get accent2 => const Color(0xFF14B8A6); // Teal 500
}
