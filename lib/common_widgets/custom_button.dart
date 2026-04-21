import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_design_system.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final bool isGhost;
  final bool isSecondary;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double height;
  final double borderRadius;
  final IconData? icon;
  final bool isFullWidth;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.isGhost = false,
    this.isSecondary = false,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height = 48,
    this.borderRadius = AppDesignSystem.radiusButton,
    this.icon,
    this.isFullWidth = false,
  });

  bool get _isDisabled => onPressed == null || isLoading;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    if (isGhost) {
      // Ghost button – no background, blue text
      final btn = TextButton(
        onPressed: _isDisabled ? null : onPressed,
        style: TextButton.styleFrom(
          foregroundColor: textColor ?? AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
        child: _buildButtonContent(
          effectiveTextColor: textColor ?? AppColors.primary,
        ),
      );
      return _wrapSized(btn);
    }

    if (isOutlined) {
      // Outlined button – blue border, blue text, rounded 12px
      final btn = OutlinedButton(
        onPressed: _isDisabled ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor ?? AppColors.primary,
          side: BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: radius), // 12px
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        child: _buildButtonContent(
          effectiveTextColor: textColor ?? AppColors.primary,
        ),
      );
      return _wrapSized(btn);
    }

    // Solid button – primary gradient or secondary fill
    final isPrimary = !isSecondary;
    final fgColor = textColor ?? AppColors.white;

    final btn = ElevatedButton(
      onPressed: _isDisabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.transparent,
        shadowColor: isPrimary 
            ? AppColors.primary.withOpacity(0.3)
            : AppColors.black.withOpacity(0.15),
        elevation: isPrimary ? 4 : 2,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [
                    AppColors.primaryGradientStart, // #3B82F6
                    AppColors.primaryGradientEnd,   // #2563EB
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isPrimary ? null : (backgroundColor ?? AppColors.surface), // Slate 700
          boxShadow: isPrimary ? AppDesignSystem.buttonShadow : null,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          alignment: Alignment.center,
          child: _buildButtonContent(effectiveTextColor: fgColor),
        ),
      ),
    );

    return _wrapSized(btn);
  }

  Widget _wrapSized(Widget child) {
    if (isFullWidth) {
      return SizedBox(width: double.infinity, height: height, child: child);
    }
    if (width != null) {
      return SizedBox(width: width, height: height, child: child);
    }
    return SizedBox(height: height, child: child);
  }

  Widget _buildButtonContent({required Color effectiveTextColor}) {
    if (isLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
        ),
      );
    }

    final style = AppTextStyles.buttonLarge.copyWith(color: effectiveTextColor);

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: effectiveTextColor),
          const SizedBox(width: 8),
          Text(text, style: style),
        ],
      );
    }

    return Text(text, style: style);
  }
}
