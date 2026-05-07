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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '블록 선택',
              style: AppTypography.title.copyWith(color: AppColors.ink),
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
                          border: Border.all(color: AppColors.borderSoft),
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
    );
  }

  Widget _buildPlayingPhase() {
    final board = _service.board;
    if (board.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        final gridSize = _calculateGridSize(constraints, isLandscape);
        final cellSize = gridSize / gridColumns;
        final matchHeader = _buildMatchHeader();
        final boardPanel = _buildBoardPanel(gridSize, cellSize);
        final boardKey = _BoardKey();
        final statusLine = _buildStatusLine();
        final blockDock = _buildBlockDock(cellSize, isLandscape);
        final bottomActions = _buildBottomActions();

        if (isLandscape) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: gridSize + 12),
                        child: matchHeader,
                      ),
                      const SizedBox(height: 12),
                      boardPanel,
                      const SizedBox(height: 8),
                      boardKey,
                    ],
                  ),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: 240,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        statusLine,
                        const SizedBox(height: 14),
                        blockDock,
                        const SizedBox(height: 12),
                        bottomActions,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                matchHeader,
                const SizedBox(height: 12),
                boardPanel,
                const SizedBox(height: 8),
                boardKey,
                const SizedBox(height: 16),
                statusLine,
                const SizedBox(height: 10),
                blockDock,
                const SizedBox(height: 10),
                bottomActions,
              ],
            ),
          ),
        );
      },
    );
  }

  double _calculateGridSize(BoxConstraints constraints, bool isLandscape) {
    if (isLandscape) {
      var gridSize = constraints.maxHeight * 0.72;
      final maxWidth = constraints.maxWidth * 0.58;
      if (gridSize > maxWidth) gridSize = maxWidth;
      if (gridSize > 560) gridSize = 560;
      return gridSize;
    }

    var gridSize = constraints.maxWidth * 0.9;
    if (constraints.maxWidth > 600) {
      gridSize = constraints.maxWidth * 0.58;
      if (gridSize > 600) gridSize = 600;
    }
    final maxGridHeight = constraints.maxHeight * 0.48;
    if (gridSize > maxGridHeight) gridSize = maxGridHeight;
    return gridSize;
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
                  ? '종료'
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

  Widget _buildStatusLine() {
    return Obx(() {
      final isMyTurn = controller.isMyTurn.value;
      final statusText = controller.gameFinishedRx.value
          ? _winnerText()
          : isMyTurn
              ? '블록을 보드에 놓으세요'
              : '상대가 두는 중입니다';

      return Text(
        statusText,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.bodySmall.copyWith(
          color: isMyTurn ? AppColors.primary : AppColors.textMuted,
          fontWeight: FontWeight.w800,
        ),
      );
    });
  }

  Widget _buildBlockDock(double cellSize, bool isLandscape) {
    final block = MpSharedBlocks(
      controller: controller,
      cellSize: cellSize,
      gridKey: _gridKey,
      rotation: _currentRotation,
    );

    return Obx(() {
      final canPlay =
          controller.isMyTurn.value && !controller.gameFinishedRx.value;

      return ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isLandscape ? double.infinity : 300,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      canPlay ? '둘 블록' : '대기',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '회전',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    iconSize: 19,
                    color: AppColors.ink,
                    disabledColor: AppColors.textSubtle,
                    icon: const Icon(Icons.rotate_right_rounded),
                    onPressed: canPlay
                        ? () {
                            controller.clearHover();
                            setState(() {
                              _currentRotation =
                                  (_currentRotation + 1) % rotationUnit;
                            });
                          }
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              block,
            ],
          ),
        ),
      );
    });
  }

  Widget _buildBottomActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _QuietAction(
          label: '다시 시작',
          icon: Icons.refresh_rounded,
          onPressed: _restartGame,
        ),
        const SizedBox(width: 8),
        _QuietAction(
          label: '나가기',
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
    );
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
      constraints: const BoxConstraints(minWidth: 64),
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

class _BoardKey extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 6,
      children: [
        _KeyItem(label: '빈 칸', color: AppColors.surface),
        _KeyItem(label: '벽', color: Color(0xFF40444C), icon: Icons.close),
        _KeyItem(
          label: '사용 불가',
          color: AppColors.backgroundSoft,
          icon: Icons.block_rounded,
        ),
      ],
    );
  }
}

class _KeyItem extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _KeyItem({
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: icon == null
              ? null
              : Icon(
                  icon,
                  size: 9,
                  color: color == const Color(0xFF40444C)
                      ? AppColors.surface
                      : AppColors.textSubtle,
                ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.tiny.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _QuietAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _QuietAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 15),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textMuted,
        minimumSize: const Size(0, 30),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        textStyle: AppTypography.caption.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}
