import 'package:link_your_area/constant.dart';
import 'package:flutter/material.dart';

import 'dart:ui' as ui;

/// 테두리를 별도로 그리는 CustomPainter 클래스
class GridBorderPainter extends CustomPainter {
  final List<List<int>> regionGrid;
  final int gridColumns;
  final double gridCellSize;
  final Paint thickBorder;

  // 이전 상태를 저장하여 최적화에 사용
  final List<List<int>>? oldRegionGrid;

  // 상수 정의
  static const double _strokeWidth = 6.0;
  static const Color _borderColor = charcoalBlack;

  GridBorderPainter(
    this.regionGrid,
    this.gridColumns,
    this.gridCellSize, {
    this.oldRegionGrid,
  }) : thickBorder = Paint()
          ..color = _borderColor
          ..strokeWidth = _strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    if (regionGrid.isEmpty || regionGrid[0].isEmpty) return;

    // Region ID -> Path mapping
    Map<int, Path> regionPaths = {};

    for (int row = 0; row < regionGrid.length; row++) {
      for (int col = 0; col < regionGrid[row].length; col++) {
        int region = regionGrid[row][col];
        // Create a path for the current cell
        // Slightly inflate to ensure overlap for union
        Rect cellRect = Rect.fromLTWH(
          col * gridCellSize,
          row * gridCellSize,
          gridCellSize,
          gridCellSize,
        );
        Path cellPath = Path()..addRect(cellRect);

        if (regionPaths.containsKey(region)) {
          // Merge this cell into the existing region path
          regionPaths[region] = Path.combine(
            ui.PathOperation.union,
            regionPaths[region]!,
            cellPath,
          );
        } else {
          regionPaths[region] = cellPath;
        }
      }
    }

    // Draw all region paths
    for (Path path in regionPaths.values) {
      canvas.drawPath(path, thickBorder);
    }
  }

  @override
  bool shouldRepaint(covariant GridBorderPainter oldDelegate) {
    // Check if grid dimensions changed
    if (oldRegionGrid == null ||
        oldRegionGrid!.length != regionGrid.length ||
        oldRegionGrid![0].length != regionGrid[0].length) {
      return true;
    }

    // Check content changes
    for (int row = 0; row < regionGrid.length; row++) {
      for (int col = 0; col < regionGrid[row].length; col++) {
        if (regionGrid[row][col] != oldRegionGrid![row][col]) {
          return true;
        }
      }
    }
    return false;
  }
}
