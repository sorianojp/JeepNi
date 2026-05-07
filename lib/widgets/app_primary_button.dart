import 'package:flutter/material.dart';

import '../core/app_ui.dart';

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor = AppUi.primaryBlue,
    this.foregroundColor = Colors.white,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final disabledBackgroundColor = backgroundColor.withValues(alpha: 0.65);
    final textStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: foregroundColor,
      fontWeight: FontWeight.w700,
    );

    final child = isLoading
        ? SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
            ),
          )
        : icon == null
        ? Text(label, style: textStyle)
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foregroundColor),
              const SizedBox(width: 10),
              Text(label, style: textStyle),
            ],
          );

    return SizedBox(
      width: double.infinity,
      height: AppUi.buttonHeight,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: disabledBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppUi.buttonRadius),
          ),
        ),
        child: child,
      ),
    );
  }
}
