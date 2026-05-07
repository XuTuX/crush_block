import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constant.dart';
import '../../controllers/multiplayer_game_controller.dart';
import '../../services/multiplayer_service.dart';
import '../../theme/app_design_system.dart';

class MultiplayerBoard extends StatelessWidget {
  final MultiplayerGameController controller;
  final double gridSize;
  final double cellSize;
  final double pulseValue;

  const MultiplayerBoard({
    super.key,
    required this.controller,
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
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridColumns,
          ),
          itemCount: gridRows * gridColumns,
          itemBuilder: (context, index) {
            return Obx(() {
              final liveBoard = service.board;
              if (liveBoard.length != gridRows) {
                return const SizedBox.shrink();
              }

              final row = index ~/ gridColumns;
              final col = index % gridColumns;
              final cell = liveBoard[row][col];
              final isHover = controller.hoverCells.contains(index);
              final isPlaced = controller.lastPlacedCells.contains(index);
              final isCleared = controller.lastClearedCells.contains(index);
              final color = _cellColor(cell, isHover);
              final isFilled = cell != 'empty' || isHover;

              return AnimatedScale(
                scale: isPlaced ? 1.02 : 1,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.all(1),
                  decoration: _cellDecoration(
                    color: color,
                    isFilled: isFilled,
                    isHover: isHover,
                    isCleared: isCleared,
                  ),
                  child: _cellMarker(cell, isHover),
                ),
              );
            });
          },
        ),
      );
    });
  }

  Color _cellColor(String cell, bool isHover) {
    if (cell == 'wall') return AppColors.ink;
    if (cell == controller.myRole) return controller.myBlockColor.value;
    if (cell == controller.opponentRole) {
      return controller.opponentBlockColor.value;
    }
    if (isHover) {
      return (controller.hoverColor.value ?? controller.myPlacementColor)
          .withValues(alpha: 0.42);
    }
    return AppColors.background;
  }

  BoxDecoration _cellDecoration({
    required Color color,
    required bool isFilled,
    required bool isHover,
    required bool isCleared,
  }) {
    if (!isFilled) {
      return BoxDecoration(
        color: AppColors.backgroundSoft,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: AppColors.borderSoft.withValues(alpha: 0.7),
        ),
      );
    }

    final baseColor = isHover ? color.withValues(alpha: 0.58) : color;
    return BoxDecoration(
      color: baseColor,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(
        color: isCleared
            ? AppColors.success
            : isHover
                ? AppColors.primary
                : AppColors.ink.withValues(alpha: 0.24),
        width: isHover || isCleared ? 1.4 : 1,
      ),
    );
  }

  Widget? _cellMarker(String cell, bool isHover) {
    if (isHover) {
      return Icon(
        Icons.add_rounded,
        color: AppColors.primary.withValues(alpha: 0.82),
        size: cellSize * 0.48,
      );
    }

    if (cell == controller.myRole) {
      return Icon(
        Icons.circle_rounded,
        color: AppColors.onPrimary.withValues(alpha: 0.92),
        size: cellSize * 0.42,
      );
    }

    if (cell == controller.opponentRole) {
      return Icon(
        Icons.change_history_rounded,
        color: AppColors.onPrimary.withValues(alpha: 0.94),
        size: cellSize * 0.5,
      );
    }

    if (cell == 'wall') {
      return Icon(
        Icons.close_rounded,
        color: AppColors.surface,
        size: cellSize * 0.52,
      );
    }

    return null;
  }
}
