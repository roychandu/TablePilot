import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  // Typography scale based on design system
  // Headings use Inter / Poppins-style bold weight

  // Display: 32px / Bold
  // Headings: Inter / Poppins Bold
  static TextStyle display = TextStyle(
    fontFamily: 'Inter', // Fallback to Inter, prefer Poppins if available
    fontSize: 32,
    fontWeight: FontWeight.w700, // Bold
    color: AppColors.textPrimary,
  );

  // Headline: 24px / SemiBold
  static TextStyle headline = TextStyle(
    fontFamily: 'Inter',
    fontSize: 24,
    fontWeight: FontWeight.w600, // SemiBold
    color: AppColors.textPrimary,
  );

  // Title: 20px / SemiBold
  static TextStyle title = TextStyle(
    fontFamily: 'Inter',
    fontSize: 20,
    fontWeight: FontWeight.w600, // SemiBold
    color: AppColors.textPrimary,
  );

  // Subtitle: 16px / Medium
  static TextStyle subtitle = TextStyle(
    fontFamily: 'Inter', // Body: Inter / Roboto Regular
    fontSize: 16,
    fontWeight: FontWeight.w500, // Medium
    color: AppColors.textSecondary,
  );

  // Body: 14px / Regular
  static TextStyle body = TextStyle(
    fontFamily: 'Inter', // Body: Inter / Roboto Regular
    fontSize: 14,
    fontWeight: FontWeight.w400, // Regular
    color: AppColors.textPrimary,
  );

  // Caption: 12px / Regular
  static TextStyle caption = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w400, // Regular
    color: AppColors.textTertiary,
  );

  // Numeric styles (for stats, counters) – SF Mono / Roboto Mono
  static TextStyle numeric = TextStyle(
    fontFamily: 'RobotoMono', // Numbers: SF Mono / Roboto Mono
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  // Button text styles
  static TextStyle buttonLarge = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );

  static TextStyle buttonMedium = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );

  static TextStyle buttonSmall = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );

  // Legacy aliases (for backwards compatibility)
  static TextStyle h1 = display;
  static TextStyle h2 = headline;
  static TextStyle h3 = title;
  static TextStyle h4 = subtitle;
  static TextStyle h5 = subtitle;
  static TextStyle h6 = subtitle;

  static TextStyle bodyLarge = subtitle;
  static TextStyle bodyMedium = body;
  static TextStyle bodySmall = caption;

  static TextStyle quote = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    fontStyle: FontStyle.italic,
  );

  static TextStyle overline = TextStyle(
    fontFamily: 'Inter',
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
    letterSpacing: 1.5,
  );
}
