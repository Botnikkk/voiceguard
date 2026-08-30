import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum ButtonVariant { primary, danger, safe, outline }

class CustomButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final bool isLoading;
  final double height;

  const CustomButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.isLoading = false,
    this.height = 54,
  });

  Color get _bgColor {
    switch (variant) {
      case ButtonVariant.primary:
        return AppColors.accentBlue;
      case ButtonVariant.danger:
        return AppColors.dangerRed;
      case ButtonVariant.safe:
        return AppColors.safeGreen;
      case ButtonVariant.outline:
        return Colors.transparent;
    }
  }

  Color get _fgColor {
    if (variant == ButtonVariant.outline) return AppColors.textPrimary;
    if (variant == ButtonVariant.safe) return AppColors.bgDeepest;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: _fgColor),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 19, color: _fgColor),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: _fgColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          );

    return SizedBox(
      height: height,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _bgColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: variant == ButtonVariant.outline
                ? const BorderSide(color: AppColors.border)
                : BorderSide.none,
          ),
        ),
        child: child,
      ),
    );
  }
}
