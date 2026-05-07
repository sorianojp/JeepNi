import 'package:flutter/material.dart';

import '../core/app_ui.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.suffixIcon,
    this.onSubmitted,
    this.fillColor = AppUi.formSurface,
    this.focusColor = AppUi.primaryBlue,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;
  final Color fillColor;
  final Color focusColor;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      obscureText: obscureText,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: fillColor,
        contentPadding: AppUi.fieldContentPadding,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppUi.fieldRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppUi.fieldRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppUi.fieldRadius),
          borderSide: BorderSide(color: focusColor, width: 1.4),
        ),
      ),
    );
  }
}
