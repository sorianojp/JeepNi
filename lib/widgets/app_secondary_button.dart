import 'package:flutter/material.dart';

import '../core/app_ui.dart';

class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.foregroundColor = AppUi.primaryBlue,
    this.backgroundColor = Colors.white,
    this.borderColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: foregroundColor,
      fontWeight: FontWeight.w700,
    );

    return SizedBox(
      width: double.infinity,
      height: AppUi.buttonHeight,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundColor,
          backgroundColor: backgroundColor,
          side: BorderSide(
            color: borderColor ?? foregroundColor.withValues(alpha: 0.18),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppUi.buttonRadius),
          ),
        ),
        child: Text(label, style: textStyle),
      ),
    );
  }
}
