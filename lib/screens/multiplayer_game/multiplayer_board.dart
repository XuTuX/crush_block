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
  final int rotation;

  const MultiplayerBoard({
    super.key,
    required this.controller,
    required this.gridSize,
    required this.cellSize,
    required this.pulseValue,
    required this.rotation,
  });

  @override
  Widget build(BuildContext context) {
    final service = Get.find<MultiplayerService>();
    return Obx(() {
      final board = service.board;
      if (board.length != gridRows) {
        return const SizedBox.shrink();
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox.square(
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
                final isInvalid = controller.invalidCells.contains(index);
                final isPlaced = controller.lastPlacedCells.contains(index);
                final isCleared = controller.lastClearedCells.contains(index);
                final isUnavailable = _isUnavailable(cell);
                final color = _cellColor(cell, isHover);
                final isFilled = cell != 'empty' || isHover || isUnavailable;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _handleCellTap(row, col, index),
                  child: AnimatedScale(
                    scale: isInvalid
                        ? 0.94
                        : isPlaced
                            ? 1.025
                            : 1,
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOutCubic,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.all(0.8),
                      decoration: _cellDecoration(
                        cell: cell,
                        color: color,
                        isFilled: isFilled,
                        isHover: isHover,
                        isInvalid: isInvalid,
                        isCleared: isCleared,
                        isPlaced: isPlaced,
                        isUnavailable: isUnavailable,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(cellSize * 0.12),
                        child: Center(child: _cellMarker(cell, isHover)),
                      ),
                    ),
                  ),
                );
              });
            },
          ),
        ),
      );
    });
  }

  Color _cellColor(String cell, bool isHover) {
    if (cell == 'wall') return const Color(0xFF24272C);
    if (_isUnavailable(cell)) return const Color(0xFFF2F3F5);
    if (cell == controller.myRole) return controller.myBlockColor.value;
    if (cell == controller.opponentRole) {
      return controller.opponentBlockColor.value;
    }
    if (isHover) {
      return (controller.hoverColor.value ?? controller.myPlacementColor)
          .withValues(alpha: 0.14);
    }
    return AppColors.surface;
  }

  BoxDecoration _cellDecoration({
    required String cell,
    required Color color,
    required bool isFilled,
    required bool isHover,
    required bool isInvalid,
    required bool isCleared,
    required bool isPlaced,
    required bool isUnavailable,
  }) {
    final radius = BorderRadius.circular(cellSize * 0.12);

    if (isInvalid) {
      return BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: radius,
        border: Border.all(
          color: AppColors.dangerStrong.withValues(alpha: 0.78),
          width: 1.6,
        ),
      );
    }

    if (!isFilled) {
      return BoxDecoration(
        color: AppColors.surface,
        borderRadius: radius,
        border: Border.all(
          color: const Color(0xFFEAEAEA),
          width: 0.8,
        ),
      );
    }

    if (cell == 'wall') {
      return BoxDecoration(
        color: color,
        borderRadius: radius,
        border: Border.all(
          color: const Color(0xFF15171A),
          width: 1,
        ),
      );
    }

    if (isUnavailable) {
      return BoxDecoration(
        color: color,
        borderRadius: radius,
        border: Border.all(
          color: const Color(0xFFD8DADF),
          width: 1,
        ),
      );
    }

    if (isHover) {
      return BoxDecoration(
        color: color,
        borderRadius: radius,
        border: Border.all(
          color: controller.myBlockColor.value.withValues(alpha: 0.55),
          width: 1.2,
        ),
      );
    }

    return BoxDecoration(
      color: color,
      borderRadius: radius,
      border: Border.all(
        color: isCleared
            ? AppColors.success.withValues(alpha: 0.55)
            : isPlaced
                ? AppColors.ink.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.48),
        width: isCleared || isPlaced ? 1.1 : 0.8,
      ),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.18),
          blurRadius: 5,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget? _cellMarker(String cell, bool isHover) {
    if (isHover) {
      return Container(
        width: cellSize * 0.18,
        height: cellSize * 0.18,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.72),
          shape: BoxShape.circle,
        ),
      );
    }

    if (cell == 'wall') {
      return Icon(
        Icons.close_rounded,
        color: const Color(0xFFB6BAC0),
        size: cellSize * 0.42,
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

  void _handleCellTap(int row, int col, int index) {
    if (!controller.isMyTurn.value || controller.gameFinishedRx.value) return;
    if (controller.isPendingCell(index)) {
      controller.confirmPendingPlacement();
      return;
    }

    final blockType = controller.mySelectedBlock;
    if (blockType == null) return;

    final shape = controller.shapeFor(blockType, rotation);
    final columns = controller.visualColumnsFor(shape);
    final rows = controller.visualRowsFor(shape);
    final staged = controller.stageSelectedBlockAtCenter(
      row,
      col,
      rotation,
      originRow: rows ~/ 2,
      originCol: columns ~/ 2,
    );
    if (!staged) {
      controller.showInvalidPlacement(
        row,
        col,
        shape,
        originRow: rows ~/ 2,
        originCol: columns ~/ 2,
      );
    }
  }

  bool _isUnavailable(String cell) {
    return cell == 'blocked' || cell == 'disabled' || cell == 'unavailable';
  }
}
