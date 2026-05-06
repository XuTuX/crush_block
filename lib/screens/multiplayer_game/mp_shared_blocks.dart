import 'package:flutter/material.dart';

import '../../controllers/multiplayer_game_controller.dart';

class MpSharedBlocks extends StatelessWidget {
  final MultiplayerGameController controller;
  final double cellSize;
  final GlobalKey gridKey;

  const MpSharedBlocks({
    super.key,
    required this.controller,
    required this.cellSize,
    required this.gridKey,
  });

  @override
  Widget build(BuildContext context) {
    final block = controller.mySelectedBlock ?? '-';
    return SizedBox(
      height: cellSize * 2,
      child: Center(
        child: Text(
          '선택 블록: $block',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
