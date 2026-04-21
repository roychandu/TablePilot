import 'package:flutter/material.dart';
import '../provider/theme_provider.dart';

class AppColors {
  static AppPalette _palette = DarkPalette();

  static void updatePalette(AppPalette palette) {
    _palette = palette;
  }

  // Primary theme
  static Color get primary => _palette.primary;
  static Color get primaryHover => _palette.primaryHover;
  static Color get primaryLight => _palette.primaryLight;

  // Backgrounds
  static Color get background => _palette.background;
  static Color get cardBackground => _palette.cardBackground;
  static Color get surface => _palette.surface;
  static Color get elevated => _palette.elevated;

  // Text colors
  static Color get textPrimary => _palette.textPrimary;
  static Color get textSecondary => _palette.textSecondary;
  static Color get textTertiary => _palette.textTertiary;
  static Color get textDisabled => _palette.textDisabled;
  static Color get textLight => _palette.textPrimary.withOpacity(0.5);
  static Color get primaryText => textPrimary;
  static Color get primaryTextLight => textSecondary;

  // Status colors
  static Color get success => _palette.success;
  static Color get warning => _palette.warning;
  static Color get error => _palette.error;
  static Color get info => _palette.info;
  static Color get occupied => _palette.occupied;

  // Accent colors
  static Color get accent1 => _palette.accent1;
  static Color get accent2 => _palette.accent2;

  // Button gradients (primary)
  static Color get primaryGradientStart => primary;
  static Color get primaryGradientEnd => primaryHover;

  // Borders / dividers
  static Color get border => _palette.border;
  static Color get borderMuted => _palette.borderMuted;
  static Color get divider => _palette.divider;

  // Shadow
  static Color get shadow => const Color(0x1A000000);

  // Common colors
  static Color get white => const Color(0xFFFFFFFF);
  static Color get black => const Color(0xFF000000);
  static Color get transparent => const Color(0x00000000);

  static Color get disabled => _palette.textDisabled.withOpacity(0.4);
  static Color get overlay => const Color(0x80000000);

  static Color get appleButtonColor => white;
  static Color get appleButtonTextColor => black;

  // Compatibility aliases
  static Color get mainBackground => background;
  static Color get text1 => textPrimary;
  static Color get text2 => textSecondary;
  static Color get highlight => error;

  static Color get background2 => surface;
  static Color get background3 => cardBackground;
  static Color get ctaPrimary => primary;
  static Color get ctaSecondary => primaryHover;

  static Color get secondary => accent1;
  static Color get secondaryDark => accent1;
  static Color get secondaryLight => accent1;

  static Color get textFieldBackground => surface;

  static Color get ctaPrimaryGradientStart => primary;
  static Color get ctaPrimaryGradientEnd => primaryHover;
  static Color get ctaSecondaryGradientStart => primary;
  static Color get ctaSecondaryGradientEnd => primaryHover;

  static Color get sageMint => background;
  static Color get coralRose => primary;
  static Color get lavenderMist => surface;
  static Color get deepCharcoal => textPrimary;
  static Color get warmGray => textSecondary;
}
