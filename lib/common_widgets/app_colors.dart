import 'package:flutter/material.dart';

class AppColors {
  // Primary theme – Ocean Blue
  static const Color primary = Color(0xFF6FD373); // Blue 500
  static const Color primaryHover = Color(0xFF2563EB); // Blue 600
  static const Color primaryLight = Color(0xFF60A5FA); // Blue 400

  // Backgrounds
  static const Color background = Color(0xFF0F172A); // Slate 900
  static const Color cardBackground = Color(0xFF1E293B); // Slate 800
  static const Color surface = Color(0xFF334155); // Slate 700
  static const Color elevated = Color(0xFF475569); // Slate 600

  // Text colors
  static const Color textPrimary = Color(0xFFF8FAFC); // Slate 50
  static const Color textSecondary = Color(0xFFCBD5E1); // Slate 300
  static const Color textTertiary = Color(0xFF94A3B8); // Slate 400
  static const Color textDisabled = Color(0xFF64748B); // Slate 500
  static const Color textLight = Color(0x80F8FAFC); // 50% primary text
  static const Color primaryText = textPrimary;
  static const Color primaryTextLight = textSecondary;

  // Status colors
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color error = Color(0xFFEF4444); // Red 500
  static const Color info = Color(0xFF06B6D4); // Cyan 500
  static const Color occupied = Color(0xFF8B5CF6); // Violet 500

  // Accent colors
  static const Color accent1 = Color(0xFFEC4899); // Pink 500
  static const Color accent2 = Color(0xFF14B8A6); // Teal 500

  // Button gradients (primary)
  static const Color primaryGradientStart = Color(0xFF3B82F6);
  static const Color primaryGradientEnd = Color(0xFF2563EB);

  // Borders / dividers suitable for dark UI
  static const Color border = Color(0xFF334155); // Slate 700
  static const Color borderMuted = Color(0xFF475569); // Slate 600
  static const Color divider = Color(0x26FFFFFF); // subtle white divider

  // Shadow
  static const Color shadow = Color(0x1A000000);

  // Common colors (for compatibility)
  static const Color white = Color(0xFFFFFFFF); // Pure white
  static const Color black = Color(0xFF000000); // Pure black
  static const Color transparent = Color(0x00000000); // Transparent

  // Additional semantic colors for UI elements
  static const Color disabled = Color(
    0x6664748B,
  ); // ~40% Slate 500 for disabled states
  static const Color overlay = Color(0x80000000); // 50% black overlay

  static const Color appleButtonColor = Color(0xFFFFFFFF);
  static const Color appleButtonTextColor = Color(0xFF000000);

  // Compatibility aliases (map old names to the new palette to avoid breakages)
  static const Color mainBackground = background;
  static const Color text1 = textPrimary;
  static const Color text2 = textSecondary;
  static const Color highlight = error;

  static const Color background2 = surface;
  static const Color background3 = cardBackground;
  static const Color ctaPrimary = primary;
  static const Color ctaSecondary = primaryHover;

  // Legacy semantic roles
  static const Color secondary = accent1;
  static const Color secondaryDark = accent1;
  static const Color secondaryLight = accent1;

  static const Color textFieldBackground = surface;

  static const Color ctaPrimaryGradientStart = primaryGradientStart;
  static const Color ctaPrimaryGradientEnd = primaryGradientEnd;
  static const Color ctaSecondaryGradientStart = primaryGradientStart;
  static const Color ctaSecondaryGradientEnd = primaryGradientEnd;

  static const Color sageMint = background;
  static const Color coralRose = primary;
  static const Color lavenderMist = surface;
  static const Color deepCharcoal = textPrimary;
  static const Color warmGray = textSecondary;
}
