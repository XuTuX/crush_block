import 'package:flutter/material.dart';

class MultiplayerDraggableBlock extends StatelessWidget {
  final int blockIndex;
  final double cellSize;
  final GlobalKey gridKey;

  const MultiplayerDraggableBlock({
    super.key,
    required this.blockIndex,
    required this.cellSize,
    required this.gridKey,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: cellSize * 2,
      child: const Center(child: Icon(Icons.extension_rounded)),
    );
  }
}
