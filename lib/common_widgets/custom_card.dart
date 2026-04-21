import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_design_system.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final bool showBorder;

  const CustomCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = AppDesignSystem.radiusCard,
    this.backgroundColor,
    this.onTap,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    Widget cardWidget = Container(
      margin: margin ?? const EdgeInsets.all(AppDesignSystem.spacingSm),
      padding: padding ?? const EdgeInsets.all(AppDesignSystem.cardPadding), // 16px
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.cardBackground, // Slate 800 (#1E293B)
        borderRadius: radius, // 16px
        border: showBorder
            ? Border.all(color: AppColors.border, width: 1) // Slate 700 (#334155)
            : Border.all(color: AppColors.transparent, width: 0),
        boxShadow: AppDesignSystem.cardShadow, // 0 4px 6px rgba(0, 0, 0, 0.1)
      ),
      child: child,
    );

    if (onTap != null) {
      cardWidget = InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: cardWidget,
      );
    }

    return cardWidget;
  }
}
