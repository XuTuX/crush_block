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
    final radius = BorderRadius.circular(cellSize * 0.16);
    final borderWidth = cellSize < 18 ? 1.1 : 1.8;
    final shadowOffset = cellSize < 18 ? 1.1 : 2.2;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1A1A).withValues(alpha: 0.9),
            blurRadius: 0,
            offset: Offset(shadowOffset, shadowOffset),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(color, Colors.white, 0.34)!,
                      color,
                      Color.lerp(color, const Color(0xFF1A1A1A), 0.16)!,
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                  borderRadius: radius,
                  border: Border.all(
                    color: const Color(0xFF1A1A1A),
                    width: borderWidth,
                  ),
                ),
              ),
            ),
            Positioned(
              left: cellSize * 0.16,
              top: cellSize * 0.14,
              right: cellSize * 0.24,
              height: cellSize * 0.18,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.26),
                  borderRadius: BorderRadius.circular(cellSize),
                ),
              ),
            ),
            Positioned(
              left: borderWidth,
              right: borderWidth,
              bottom: borderWidth,
              height: cellSize * 0.16,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(cellSize * 0.12),
                    bottomRight: Radius.circular(cellSize * 0.12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
