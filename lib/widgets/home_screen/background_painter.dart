import 'package:link_your_area/theme/app_design_system.dart';
import 'package:flutter/material.dart';

/// Minimal soft gradient background for the home screen.
class GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Subtle top-to-bottom gradient wash
    final bgPaint = Paint()
      ..shader = AppColors.backgroundGradient
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
