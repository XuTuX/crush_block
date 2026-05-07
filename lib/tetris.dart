// tetris_block.dart
import 'package:flutter/material.dart';

class TetrisBlock extends StatelessWidget {
  final double cellSize;
  final List<Offset> shape;
  final Color color;
  final String? tokenPath;
  final bool showBackground;
  final int columns;
  final int rows;

  const TetrisBlock({
    super.key,
    required this.shape,
    required this.color,
    required this.cellSize,
    this.tokenPath,
    this.showBackground = true,
    this.columns = 3,
    this.rows = 3,
  });

  @override
  Widget build(BuildContext context) {
    final blockWidth = columns * cellSize;
    final blockHeight = rows * cellSize;

    return SizedBox(
      width: blockWidth,
      height: blockHeight,
      child: Stack(
        children: shape.map((offset) {
          return Positioned(
            left: offset.dx * cellSize,
            top: offset.dy * cellSize,
            child: SizedBox(
              width: cellSize,
              height: cellSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (showBackground || tokenPath == null)
                    Padding(
                      padding: EdgeInsets.all(cellSize * 0.035),
                      child: _BlockCell(
                        color: color,
                        cellSize: cellSize,
                      ),
                    ),
                  if (tokenPath != null)
                    Image.asset(
                      tokenPath!,
                      width: cellSize * 0.78,
                      height: cellSize * 0.78,
                      fit: BoxFit.contain,
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BlockCell extends StatelessWidget {
  final Color color;
  final double cellSize;

  const _BlockCell({
    required this.color,
    required this.cellSize,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(cellSize * 0.14);
    final borderWidth = cellSize < 18 ? 1.0 : 1.3;

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: Border.all(
          color: const Color(0xFF1A1A1A).withValues(alpha: 0.28),
          width: borderWidth,
        ),
      ),
    );
  }
}
