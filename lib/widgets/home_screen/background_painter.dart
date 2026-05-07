import 'dart:math';

import 'package:crush_block/theme/app_design_system.dart';
import 'package:flutter/material.dart';

class GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = AppColors.backgroundGradient
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final gridPaint = Paint()
      ..color = AppColors.ink.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    const gridSize = 40.0;

    for (var x = 0.0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final random = Random(42);
    final cellPaint = Paint()..style = PaintingStyle.fill;
    final maxX = max(1, (size.width / gridSize).floor());
    final maxY = max(1, (size.height / gridSize).floor());

    for (var i = 0; i < 9; i += 1) {
      final cx = random.nextInt(maxX);
      final cy = random.nextInt(maxY);
      final color = AppColors.areaPalette[random.nextInt(
        AppColors.areaPalette.length,
      )];
      cellPaint.color = color.withValues(alpha: 0.2);
      final rect = Rect.fromLTWH(
        cx * gridSize + 4,
        cy * gridSize + 4,
        gridSize - 8,
        gridSize - 8,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        cellPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
