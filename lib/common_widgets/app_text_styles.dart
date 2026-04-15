import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  // Typography scale based on design system
  // Headings use Inter / Poppins-style bold weight

  // Display: 32px / Bold
  // Headings: Inter / Poppins Bold
  static const TextStyle display = TextStyle(
    fontFamily: 'Inter', // Fallback to Inter, prefer Poppins if available
    fontSize: 32,
    fontWeight: FontWeight.w700, // Bold
    color: AppColors.textPrimary,
  );

  // Headline: 24px / SemiBold
  static const TextStyle headline = TextStyle(
    fontFamily: 'Inter',
    fontSize: 24,
    fontWeight: FontWeight.w600, // SemiBold
    color: AppColors.textPrimary,
  );

  // Title: 20px / SemiBold
  static const TextStyle title = TextStyle(
    fontFamily: 'Inter',
    fontSize: 20,
    fontWeight: FontWeight.w600, // SemiBold
    color: AppColors.textPrimary,
  );

  // Subtitle: 16px / Medium
  static const TextStyle subtitle = TextStyle(
    fontFamily: 'Inter', // Body: Inter / Roboto Regular
    fontSize: 16,
    fontWeight: FontWeight.w500, // Medium
    color: AppColors.textSecondary,
  );

  // Body: 14px / Regular
  static const TextStyle body = TextStyle(
    fontFamily: 'Inter', // Body: Inter / Roboto Regular
    fontSize: 14,
    fontWeight: FontWeight.w400, // Regular
    color: AppColors.textPrimary,
  );

  // Caption: 12px / Regular
  static const TextStyle caption = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w400, // Regular
    color: AppColors.textTertiary,
  );

  // Numeric styles (for stats, counters) – SF Mono / Roboto Mono
  static const TextStyle numeric = TextStyle(
    fontFamily: 'RobotoMono', // Numbers: SF Mono / Roboto Mono
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  // Button text styles
  static const TextStyle buttonLarge = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );

  static const TextStyle buttonMedium = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );

  static const TextStyle buttonSmall = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );

  // Legacy aliases (for backwards compatibility)
  static const TextStyle h1 = display;
  static const TextStyle h2 = headline;
  static const TextStyle h3 = title;
  static const TextStyle h4 = subtitle;
  static const TextStyle h5 = subtitle;
  static const TextStyle h6 = subtitle;

  static const TextStyle bodyLarge = subtitle;
  static const TextStyle bodyMedium = body;
  static const TextStyle bodySmall = caption;

  static const TextStyle quote = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    fontStyle: FontStyle.italic,
  );

  static const TextStyle overline = TextStyle(
    fontFamily: 'Inter',
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
    letterSpacing: 1.5,
  );
}
