import 'package:flutter/material.dart';

class HighlightPainter extends CustomPainter {
  final Rect highlightRect;
  final Color color;

  HighlightPainter({
    required this.highlightRect,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final RRect rrect = RRect.fromRectAndRadius(
      highlightRect,
      const Radius.circular(4),
    );

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant HighlightPainter oldDelegate) {
    return oldDelegate.highlightRect != highlightRect ||
        oldDelegate.color != color;
  }
}
