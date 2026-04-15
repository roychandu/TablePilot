// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppDesignSystem {
  // Spacing system
  // XS: 4, SM: 8, MD: 16, LG: 24, XL: 32, 2XL: 48
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacing2Xl = 48.0;

  // Legacy aliases for existing usage
  static const double spacing4 = spacingXs;
  static const double spacing8 = spacingSm;
  static const double spacing12 = 12.0;
  static const double spacing16 = spacingMd;
  static const double spacing20 = 20.0;
  static const double spacing24 = spacingLg;
  static const double spacing32 = spacingXl;
  static const double spacing40 = 40.0;
  static const double spacing48 = spacing2Xl;
  static const double spacing56 = 56.0;
  static const double spacing64 = 64.0;

  // Padding
  static const double cardPadding = spacingMd;
  static const double screenGutter = spacingMd;
  static const double sectionGap = spacingLg;

  // Border Radius
  static const double radiusCard = 16.0;
  static const double radiusButton = 12.0;
  static const double radiusInput = 10.0;

  // Shadows
  // Card shadow: 0 4px 6px rgba(0, 0, 0, 0.1)
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: AppColors.black.withOpacity(0.1),
      blurRadius: 6,
      offset: const Offset(0, 4),
    ),
  ];

  // Button shadow for primary buttons
  static List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: AppColors.primary.withOpacity(0.3),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: AppColors.black.withOpacity(0.2),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];

  // Card Decoration
  static BoxDecoration cardDecoration = BoxDecoration(
    color: AppColors.cardBackground,
    borderRadius: BorderRadius.circular(radiusCard),
    border: Border.all(color: AppColors.border),
    boxShadow: cardShadow,
  );

  // Input Decoration (base)
  // Height: 48px, Padding: 12px 16px, Rounded: 10px
  // Background: Slate 700, Border: Slate 600, Focus: Blue border + glow
  static InputDecoration inputDecoration = InputDecoration(
    filled: true,
    fillColor: AppColors.surface, // Slate 700
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusInput),
      borderSide: BorderSide(color: AppColors.borderMuted), // Slate 600
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusInput),
      borderSide: BorderSide(color: AppColors.borderMuted), // Slate 600
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusInput),
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: spacingMd, // 16px
      vertical: 12, // 12px
    ),
  );

  // Input height constant
  static const double inputHeight = 48.0;
}
