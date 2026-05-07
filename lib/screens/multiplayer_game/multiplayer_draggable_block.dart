import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/multiplayer_game_controller.dart';
import '../../tetris.dart';

class MultiplayerDraggableBlock extends StatelessWidget {
  final int blockIndex;
  final double cellSize;
  final GlobalKey gridKey;
  final int rotation;

  const MultiplayerDraggableBlock({
    super.key,
    required this.blockIndex,
    required this.cellSize,
    required this.gridKey,
    required this.rotation,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MultiplayerGameController>();

    return Obx(
      () {
        final blockType = controller.mySelectedBlock;
        if (blockType == null) {
          return SizedBox(width: cellSize * 3, height: cellSize * 3);
        }

        final shape = controller.shapeFor(blockType, rotation);
        final color = controller.myPlacementColor;
        final columns = controller.visualColumnsFor(shape);
        final rows = controller.visualRowsFor(shape);
        final canDrag = controller.isMyTurn.value &&
            !controller.gameFinishedRx.value &&
            shape.isNotEmpty;

        final dockBlock = Opacity(
          opacity: canDrag ? 1 : 0.45,
          child: TetrisBlock(
            shape: shape,
            color: color,
            cellSize: cellSize * 0.72,
            columns: columns,
            rows: rows,
          ),
        );

        return Draggable<int>(
          data: blockIndex,
          maxSimultaneousDrags: canDrag ? 1 : 0,
          feedback: Material(
            color: Colors.transparent,
            child: TetrisBlock(
              shape: shape,
              color: color.withValues(alpha: 0.72),
              cellSize: cellSize,
              columns: columns,
              rows: rows,
            ),
          ),
          childWhenDragging: SizedBox(
            width: columns * cellSize * 0.72,
            height: rows * cellSize * 0.72,
          ),
          dragAnchorStrategy: (_, __, ___) {
            return Offset(columns * cellSize * 0.5, rows * cellSize);
          },
          onDragStarted: controller.clearHover,
          onDragUpdate: (details) {
            _handleDragUpdate(details, controller, shape, color, columns, rows);
          },
          onDragEnd: (details) {
            _handleDragEnd(details, controller, columns, rows);
          },
          onDraggableCanceled: (_, __) => controller.clearHover(),
          child: SizedBox(
            width: columns * cellSize * 0.72,
            height: rows * cellSize * 0.72,
            child: dockBlock,
          ),
        );
      },
    );
  }

  void _handleDragUpdate(
    DragUpdateDetails details,
    MultiplayerGameController controller,
    List<Offset> shape,
    Color color,
    int columns,
    int rows,
  ) {
    final gridBox = gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (gridBox == null) return;

    final anchor = Offset(columns * cellSize * 0.5, rows * cellSize);
    final dropPosition = details.globalPosition - anchor;
    final gridPosition = gridBox.localToGlobal(Offset.zero);

    final centerX = dropPosition.dx + columns * cellSize * 0.5;
    final centerY = dropPosition.dy + rows * cellSize * 0.5;
    final relativeX = centerX - gridPosition.dx;
    final relativeY = centerY - gridPosition.dy;

    final centerColumn = (relativeX / cellSize).floor();
    final centerRow = (relativeY / cellSize).floor();

    controller.updateHover(
      centerRow,
      centerColumn,
      shape,
      color,
      originRow: rows ~/ 2,
      originCol: columns ~/ 2,
    );
  }

  void _handleDragEnd(
    DraggableDetails details,
    MultiplayerGameController controller,
    int columns,
    int rows,
  ) {
    final gridBox = gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (gridBox == null) {
      controller.clearHover();
      return;
    }

    final dropPosition = details.offset;
    final gridPosition = gridBox.localToGlobal(Offset.zero);

    final centerX = dropPosition.dx + columns * cellSize * 0.5;
    final centerY = dropPosition.dy + rows * cellSize * 0.5;
    final relativeX = centerX - gridPosition.dx;
    final relativeY = centerY - gridPosition.dy;

    final centerColumn = (relativeX / cellSize).floor();
    final centerRow = (relativeY / cellSize).floor();

    controller.placeSelectedBlockAtCenter(
      centerRow,
      centerColumn,
      rotation,
      originRow: rows ~/ 2,
      originCol: columns ~/ 2,
    );
  }
}
