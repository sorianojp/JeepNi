import 'package:flutter/material.dart';

class MapRecenterButton extends StatelessWidget {
  const MapRecenterButton({
    super.key,
    required this.enabled,
    required this.color,
    required this.heroTag,
    required this.onPressed,
    this.alignment = Alignment.bottomRight,
    this.padding,
  });

  final bool enabled;
  final Color color;
  final String heroTag;
  final VoidCallback onPressed;
  final AlignmentGeometry alignment;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final bottomOffset = MediaQuery.sizeOf(context).height * 0.16;

    return Align(
      alignment: alignment,
      child: Padding(
        padding: padding ?? EdgeInsets.only(right: 16, bottom: bottomOffset),
        child: FloatingActionButton.small(
          heroTag: heroTag,
          elevation: 4,
          backgroundColor: enabled
              ? Colors.white.withValues(alpha: 0.96)
              : Colors.grey.shade200.withValues(alpha: 0.96),
          foregroundColor: enabled ? color : Colors.grey,
          onPressed: enabled ? onPressed : null,
          child: const Icon(Icons.my_location),
        ),
      ),
    );
  }
}
