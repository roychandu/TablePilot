import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_design_system.dart';

class CustomTextField extends StatelessWidget {
  final String? labelText;
  final String? hintText;
  final String? errorText;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final int? maxLines;
  final int? maxLength;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;

  const CustomTextField({
    super.key,
    this.labelText,
    this.hintText,
    this.errorText,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.maxLength,
    this.prefixIcon,
    this.suffixIcon,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.inputFormatters,
    this.focusNode,
    this.autofocus = false,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelText != null) ...[
          Text(
            labelText!,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
        // Input height: 48px (for single-line fields)
        // Padding: 12px 16px, Rounded: 10px
        // Background: Slate 700, Border: Slate 600, Focus: Blue border + glow
        SizedBox(
          height: maxLines == 1
              ? AppDesignSystem.inputHeight
              : null, // 48px for single-line
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            enabled: enabled,
            readOnly: readOnly,
            maxLines: maxLines,
            maxLength: maxLength,
            onTap: onTap,
            onChanged: onChanged,
            onFieldSubmitted: onSubmitted,
            validator: validator,
            inputFormatters: inputFormatters,
            focusNode: focusNode,
            autofocus: autofocus,
            textInputAction: textInputAction,
            textCapitalization: textCapitalization,
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
              prefixIcon: prefixIcon,
              suffixIcon: suffixIcon,
              filled: true,
              fillColor: enabled
                  ? AppColors
                        .surface // Slate 700 (#334155)
                  : AppColors.surface.withOpacity(0.6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppDesignSystem.radiusInput,
                ), // 10px
                borderSide: BorderSide(
                  color: AppColors.borderMuted,
                ), // Slate 600 (#475569)
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppDesignSystem.radiusInput,
                ),
                borderSide: BorderSide(
                  color: AppColors.borderMuted,
                ), // Slate 600
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppDesignSystem.radiusInput,
                ),
                borderSide: const BorderSide(
                  color: AppColors.primary, // Blue border with glow effect
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppDesignSystem.radiusInput,
                ),
                borderSide: const BorderSide(color: AppColors.error, width: 2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppDesignSystem.radiusInput,
                ),
                borderSide: const BorderSide(color: AppColors.error, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppDesignSystem.spacingMd, // 16px
                vertical: 12, // 12px
              ),
              errorText: errorText,
            ),
          ),
        ),
      ],
    );
  }
}
