import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/multiplayer_service.dart';
import '../../theme/app_design_system.dart';

class MultiplayerBoard extends StatelessWidget {
  final double gridSize;
  final double cellSize;
  final double pulseValue;

  const MultiplayerBoard({
    super.key,
    required this.gridSize,
    required this.cellSize,
    required this.pulseValue,
  });

  @override
  Widget build(BuildContext context) {
    final service = Get.find<MultiplayerService>();
    return Obx(() {
      final board = service.board;
      if (board.length != 9) {
        return const SizedBox.shrink();
      }
      return SizedBox.square(
        dimension: gridSize,
        child: Column(
          children: List.generate(9, (y) {
            return Expanded(
              child: Row(
                children: List.generate(9, (x) {
                  final cell = board[y][x];
                  final color = switch (cell) {
                    'wall' => AppColors.ink,
                    'player1' => const Color(0xFFFF7043),
                    'player2' => const Color(0xFF42A5F5),
                    _ => AppColors.background,
                  };
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: AppColors.borderSoft),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ),
      );
    });
  }
}
