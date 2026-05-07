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
              final isUnavailable = _isUnavailable(cell);
              final color = _cellColor(cell, isHover);
              final isFilled = cell != 'empty' || isHover || isUnavailable;

              return AnimatedScale(
                scale: isPlaced ? 1.02 : 1,
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.all(1),
                  decoration: _cellDecoration(
                    cell: cell,
                    color: color,
                    isFilled: isFilled,
                    isHover: isHover,
                    isCleared: isCleared,
                    isPlaced: isPlaced,
                    isUnavailable: isUnavailable,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      isFilled ? cellSize * 0.18 : cellSize * 0.12,
                    ),
                    child: Center(child: _cellMarker(cell, isHover)),
                  ),
                ),
              );
            });
          },
        ),
      );
    });
  }

  Color _cellColor(String cell, bool isHover) {
    if (cell == 'wall') return const Color(0xFF40444C);
    if (_isUnavailable(cell)) return AppColors.backgroundSoft;
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
    required String cell,
    required Color color,
    required bool isFilled,
    required bool isHover,
    required bool isCleared,
    required bool isPlaced,
    required bool isUnavailable,
  }) {
    final radius = BorderRadius.circular(
      isFilled ? cellSize * 0.18 : cellSize * 0.12,
    );

    if (!isFilled) {
      return BoxDecoration(
        color: AppColors.surface,
        borderRadius: radius,
        border: Border.all(
          color: AppColors.borderSoft,
          width: 1,
        ),
      );
    }

    if (cell == 'wall') {
      return BoxDecoration(
        color: color,
        borderRadius: radius,
        border: Border.all(
          color: AppColors.ink.withValues(alpha: 0.36),
          width: 1.2,
        ),
      );
    }

    if (isUnavailable) {
      return BoxDecoration(
        color: color,
        borderRadius: radius,
        border: Border.all(
          color: AppColors.ink.withValues(alpha: 0.08),
          width: 1,
        ),
      );
    }

    if (isHover) {
      return BoxDecoration(
        color: color.withValues(alpha: 0.22),
        borderRadius: radius,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.72),
          width: 1.4,
        ),
      );
    }

    return BoxDecoration(
      color: color,
      borderRadius: radius,
      border: Border.all(
        color: isCleared
            ? AppColors.success
            : isPlaced
                ? AppColors.primary
                : AppColors.ink.withValues(alpha: 0.24),
        width: isCleared || isPlaced ? 1.7 : 1.1,
      ),
    );
  }

  Widget? _cellMarker(String cell, bool isHover) {
    if (isHover) {
      return Icon(
        Icons.add_rounded,
        color: AppColors.primary.withValues(alpha: 0.78),
        size: cellSize * 0.42,
      );
    }

    if (cell == controller.myRole) {
      return Icon(
        Icons.circle_rounded,
        color: AppColors.onPrimary.withValues(alpha: 0.86),
        size: cellSize * 0.34,
      );
    }

    if (cell == controller.opponentRole) {
      return Icon(
        Icons.change_history_rounded,
        color: AppColors.onPrimary.withValues(alpha: 0.9),
        size: cellSize * 0.4,
      );
    }

    if (cell == 'wall') {
      return Icon(
        Icons.close_rounded,
        color: AppColors.surface.withValues(alpha: 0.74),
        size: cellSize * 0.38,
      );
    }

    if (_isUnavailable(cell)) {
      return Icon(
        Icons.block_rounded,
        color: AppColors.textSubtle,
        size: cellSize * 0.34,
      );
    }

    return null;
  }

  bool _isUnavailable(String cell) {
    return cell == 'blocked' || cell == 'disabled' || cell == 'unavailable';
  }
}
