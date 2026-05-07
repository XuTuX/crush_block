import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constant.dart';
import '../controllers/multiplayer_game_controller.dart';
import '../services/multiplayer_service.dart';
import '../theme/app_design_system.dart';
import '../theme/app_typography.dart';
import 'multiplayer_game/mp_game_over_overlay.dart';
import 'multiplayer_game/mp_leave_dialog.dart';
import 'multiplayer_game/mp_shared_blocks.dart';
import 'multiplayer_game/multiplayer_board.dart';

class MultiplayerGameScreen extends StatefulWidget {
  final String roomId;
  final String myUserId;
  final String opponentUserId;
  final String myNickname;
  final String opponentNickname;
  final int? seed;
  final MultiplayerMode mode;

  const MultiplayerGameScreen({
    super.key,
    required this.roomId,
    this.seed,
    this.mode = MultiplayerMode.friendly,
    required this.myUserId,
    required this.opponentUserId,
    required this.myNickname,
    required this.opponentNickname,
  });

  @override
  State<MultiplayerGameScreen> createState() => _MultiplayerGameScreenState();
}

class _MultiplayerGameScreenState extends State<MultiplayerGameScreen> {
  late MultiplayerGameController controller;
  final MultiplayerService _service = Get.find<MultiplayerService>();
  final GlobalKey _gridKey = GlobalKey();
  int _currentRotation = 0;

  @override
  void initState() {
    super.initState();
    controller = Get.put(MultiplayerGameController(
      roomId: widget.roomId,
      seed: widget.seed,
      mode: widget.mode,
      myUserId: widget.myUserId,
      opponentUserId: widget.opponentUserId,
      myNickname: widget.myNickname,
      opponentNickname: widget.opponentNickname,
    ));
  }

  @override
  void dispose() {
    Get.delete<MultiplayerGameController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (controller.gameFinished) {
          await _service.leaveRoom();
          if (Get.key.currentState?.canPop() ?? false) Get.back();
        } else {
          showMpLeaveDialog(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Obx(() {
            final status = _service.roomStatus.value;
            return Stack(
              children: [
                if (status == 'selecting') _buildSelectionPhase(),
                if (status == 'playing' || status == 'finished')
                  _buildPlayingPhase(),
                if (status == 'finished')
                  MpGameOverOverlay(
                    controller: controller,
                    mode: widget.mode,
                    myNickname: widget.myNickname,
                    opponentNickname: widget.opponentNickname,
                    roomId: widget.roomId,
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSelectionPhase() {
    final mySelection = controller.mySelectedBlock;
    if (mySelection != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$mySelection 선택 완료',
              style: AppTypography.title.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: 10),
            Text(
              '상대방을 기다리는 중',
              style: AppTypography.body.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    final blocks = ['I', 'O', 'T', 'L', 'J', 'S', 'Z'];
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '블록 선택',
                      style: AppTypography.title.copyWith(
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: blocks
                          .map(
                            (block) => InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => controller.selectBlock(block),
                              child: Container(
                                width: 62,
                                height: 62,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.borderSoft,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    block,
                                    style: AppTypography.subtitle.copyWith(
                                      color: AppColors.ink,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayingPhase() {
    final board = _service.board;
    if (board.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final useSideRail = constraints.maxWidth >= 620 &&
            constraints.maxWidth > constraints.maxHeight;
        if (useSideRail) {
          return _buildSideRailLayout(constraints);
        }

        return _buildStackedLayout(constraints);
      },
    );
  }

  Widget _buildStackedLayout(BoxConstraints constraints) {
    final padding = constraints.maxWidth < 380 ? 10.0 : 14.0;
    final gap = constraints.maxHeight < 650 ? 10.0 : 14.0;
    final maxContentWidth =
        constraints.maxWidth > 520 ? 430.0 : constraints.maxWidth - padding * 2;
    final gridSize = _calculateStackedGridSize(
      constraints,
      padding: padding,
      gap: gap,
      maxContentWidth: maxContentWidth,
    );
    final cellSize = gridSize / gridColumns;
    final minHeight = constraints.maxHeight > padding * 2
        ? constraints.maxHeight - padding * 2
        : 0.0;
    final contentHeight = 54 + gap + gridSize + 10 + gap + cellSize * 3.05 + 26;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: minHeight,
          ),
          child: Center(
            child: SizedBox(
              width: maxContentWidth,
              height: contentHeight,
              child: Column(
                children: [
                  SizedBox(height: 54, child: _buildMatchHeader()),
                  SizedBox(height: gap),
                  _buildBoardPanel(gridSize, cellSize),
                  SizedBox(height: gap),
                  _buildControlTray(cellSize),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSideRailLayout(BoxConstraints constraints) {
    const padding = 16.0;
    const gap = 18.0;
    final railWidth = (constraints.maxWidth * 0.28).clamp(220, 264).toDouble();
    final gridByWidth =
        constraints.maxWidth - padding * 2 - gap - railWidth - 10;
    final gridByHeight = constraints.maxHeight - padding * 2 - 10;
    final gridSize = gridByWidth < gridByHeight ? gridByWidth : gridByHeight;
    final clampedGridSize = gridSize.clamp(180, 560).toDouble();
    final cellSize = clampedGridSize / gridColumns;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(padding),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildBoardPanel(clampedGridSize, cellSize),
              const SizedBox(width: gap),
              SizedBox(
                width: railWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 54, child: _buildMatchHeader()),
                    const SizedBox(height: gap),
                    _buildControlTray(cellSize),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateStackedGridSize(
    BoxConstraints constraints, {
    required double padding,
    required double gap,
    required double maxContentWidth,
  }) {
    const headerHeight = 54.0;
    const boardPadding = 10.0;
    const trayPadding = 26.0;
    const previewRatio = 3.05 / gridColumns;
    final maxByWidth = maxContentWidth - 10;
    final maxByHeight = (constraints.maxHeight -
            padding * 2 -
            headerHeight -
            gap * 2 -
            boardPadding -
            trayPadding) /
        (1 + previewRatio);
    final gridSize = maxByWidth < maxByHeight ? maxByWidth : maxByHeight;
    return gridSize.clamp(160, 560).toDouble();
  }

  Widget _buildMatchHeader() {
    return Obx(() {
      final isMyTurn = controller.isMyTurn.value;
      final finished = controller.gameFinishedRx.value;

      return Row(
        children: [
          Expanded(
            child: _PlayerChip(
              nickname: widget.myNickname,
              label: '나',
              color: AppColors.primary,
              icon: Icons.circle_rounded,
              active: isMyTurn && !finished,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _TurnBadge(
              label: finished
                  ? _winnerText()
                  : isMyTurn
                      ? '내 턴'
                      : '상대 턴',
              active: isMyTurn && !finished,
            ),
          ),
          Expanded(
            child: _PlayerChip(
              nickname: widget.opponentNickname,
              label: '상대',
              color: AppColors.tileCoral,
              icon: Icons.change_history_rounded,
              active: !isMyTurn && !finished,
              alignEnd: true,
            ),
          ),
        ],
      );
    });
  }

  Widget _buildBoardPanel(double gridSize, double cellSize) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: SizedBox(
        key: _gridKey,
        width: gridSize,
        height: gridSize,
        child: MultiplayerBoard(
          controller: controller,
          gridSize: gridSize,
          cellSize: cellSize,
          pulseValue: 0,
        ),
      ),
    );
  }

  Widget _buildControlTray(double cellSize) {
    final block = MpSharedBlocks(
      controller: controller,
      cellSize: cellSize,
      gridKey: _gridKey,
      rotation: _currentRotation,
      onRotate: _rotateCurrentBlock,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          _TrayAction(
            tooltip: '다시 시작',
            icon: Icons.refresh_rounded,
            onPressed: _restartGame,
          ),
          Expanded(
            child: Center(
              child: block,
            ),
          ),
          _TrayAction(
            tooltip: '나가기',
            icon: Icons.logout_rounded,
            onPressed: () {
              if (controller.gameFinished) {
                _leaveFinishedGame();
              } else {
                showMpLeaveDialog(context);
              }
            },
          ),
        ],
      ),
    );
  }

  void _rotateCurrentBlock() {
    final canPlay =
        controller.isMyTurn.value && !controller.gameFinishedRx.value;
    if (!canPlay) return;

    controller.clearHover();
    setState(() {
      _currentRotation = (_currentRotation + 1) % rotationUnit;
    });
  }

  Future<void> _restartGame() async {
    await _service.leaveRoom(countAsForfeit: !controller.gameFinished);
    _service.configureMode(MultiplayerMode.ranked);
    await _service.quickMatch();
    if (Get.key.currentState?.canPop() ?? false) Get.back();
  }

  Future<void> _leaveFinishedGame() async {
    await _service.leaveRoom();
    if (Get.key.currentState?.canPop() ?? false) Get.back();
  }

  String _winnerText() {
    final won = controller.iWon.value;
    if (won == true) return '내가 이겼습니다';
    if (won == false) return '상대가 이겼습니다';
    return '무승부입니다';
  }
}

class _PlayerChip extends StatelessWidget {
  final String nickname;
  final String label;
  final Color color;
  final IconData icon;
  final bool active;
  final bool alignEnd;

  const _PlayerChip({
    required this.nickname,
    required this.label,
    required this.color,
    required this.icon,
    required this.active,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? color.withValues(alpha: 0.32) : AppColors.borderSoft,
        ),
      ),
      child: Row(
        mainAxisAlignment:
            alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!alignEnd) _BlockMark(color: color, icon: icon),
          if (!alignEnd) const SizedBox(width: 7),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTypography.tiny.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (alignEnd) const SizedBox(width: 7),
          if (alignEnd) _BlockMark(color: color, icon: icon),
        ],
      ),
    );
  }
}

class _TurnBadge extends StatelessWidget {
  final String label;
  final bool active;

  const _TurnBadge({
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 58, maxWidth: 92),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? AppColors.primary : AppColors.borderSoft,
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.caption.copyWith(
          color: active ? AppColors.onPrimary : AppColors.textMuted,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _BlockMark extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _BlockMark({
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.16)),
      ),
      child: Icon(icon, size: 13, color: AppColors.onPrimary),
    );
  }
}

class _TrayAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _TrayAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 42, height: 42),
        iconSize: 20,
        color: AppColors.textMuted,
        icon: Icon(icon),
      ),
    );
  }
}
