// tetris_block.dart
import 'package:flutter/material.dart';

class TetrisBlock extends StatelessWidget {
  final double cellSize;
  final List<Offset> shape;
  final Color color;
  final String? tokenPath;
  final String? portraitPath;
  final bool showBackground;

  const TetrisBlock({
    super.key,
    required this.shape,
    required this.color,
    required this.cellSize,
    this.tokenPath,
    this.portraitPath,
    this.showBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    double blockWidth = 3 * cellSize;
    double blockHeight = 3 * cellSize;

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
                    Container(
                      width: cellSize,
                      height: cellSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.rectangle,
                        color: color.withValues(alpha: 1.0),
                      ),
                    ),
                  if (tokenPath != null)
                    Image.asset(
                      tokenPath!,
                      width: cellSize * 0.85,
                      height: cellSize * 0.85,
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
