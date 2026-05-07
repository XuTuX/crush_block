import 'package:flutter/material.dart';

import '../../controllers/multiplayer_game_controller.dart';
import 'multiplayer_draggable_block.dart';

class MpSharedBlocks extends StatelessWidget {
  final MultiplayerGameController controller;
  final double cellSize;
  final GlobalKey gridKey;
  final int rotation;
  final VoidCallback onRotate;

  const MpSharedBlocks({
    super.key,
    required this.controller,
    required this.cellSize,
    required this.gridKey,
    required this.rotation,
    required this.onRotate,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: cellSize * 3.05,
      child: Center(
        child: MultiplayerDraggableBlock(
          blockIndex: 0,
          cellSize: cellSize,
          gridKey: gridKey,
          rotation: rotation,
          onRotate: onRotate,
        ),
      ),
    );
  }
}
