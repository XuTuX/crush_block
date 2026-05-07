import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constant.dart';
import '../services/multiplayer_service.dart';
import '../controllers/multiplayer_game_controller.dart';
import '../theme/app_components.dart';
import '../theme/app_design_system.dart';
import '../theme/app_typography.dart';
import 'multiplayer_game/mp_game_over_overlay.dart';
import 'multiplayer_game/mp_leave_dialog.dart';
import 'multiplayer_game/mp_shared_blocks.dart';
import 'multiplayer_game/multiplayer_board.dart';
import '../widgets/mp_buttons.dart';

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
          if (Get.key.currentState?.canPop() ?? false) {
            Get.back();
          }
        } else {
          showMpLeaveDialog(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: Obx(() {
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
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      automaticallyImplyLeading: false,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 20,
      title: Text(
        'Crush Block',
        style: AppTypography.subtitle.copyWith(
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
      ),
      actions: [
        MpAppBarButton(
          icon: Icons.home_rounded,
          onPressed: () async {
            if (controller.gameFinished) {
              await _service.leaveRoom();
              if (Get.key.currentState?.canPop() ?? false) {
                Get.back();
              }
            } else {
              showMpLeaveDialog(context);
            }
          },
        ),
        const SizedBox(width: 16),
      ],
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
              '$mySelection 블록 선택 완료',
              style: AppTypography.title.copyWith(
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '상대방을 기다리는 중...',
              style: AppTypography.body.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    final blocks = ['I', 'O', 'T', 'L', 'J', 'S', 'Z'];
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '블록을 선택하세요',
            style: AppTypography.title.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            alignment: WrapAlignment.center,
            children: blocks
                .map((block) => GestureDetector(
                      onTap: () => controller.selectBlock(block),
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.borderSoft,
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            block,
                            style: AppTypography.title.copyWith(
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
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
        final boardPanel = _buildBoardPanel(gridSize, cellSize);
        final blockDock = _buildBlockDock(cellSize, isLandscape);
        final statusPanel = _buildGameStatusPanel();
        final legend = _buildLegend();

        if (isLandscape) {
          return Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    statusPanel,
                    const SizedBox(height: 12),
                    boardPanel,
                  ],
                ),
                const SizedBox(width: 24),
                SizedBox(
                  width: 240,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      legend,
                      const SizedBox(height: 18),
                      blockDock,
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: statusPanel,
              ),
              const SizedBox(height: 12),
              boardPanel,
              const SizedBox(height: 14),
              blockDock,
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: legend,
              ),
            ],
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

    var gridSize = constraints.maxWidth * 0.86;
    if (constraints.maxWidth > 600) {
      gridSize = constraints.maxWidth * 0.6;
      if (gridSize > 600) gridSize = 600;
    }
    final maxGridHeight = constraints.maxHeight * 0.54;
    if (gridSize > maxGridHeight) gridSize = maxGridHeight;
    return gridSize;
  }

  Widget _buildBoardPanel(double gridSize, double cellSize) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.borderSoft),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SizedBox(
        key: _gridKey,
        height: gridSize,
        width: gridSize,
        child: MultiplayerBoard(
          controller: controller,
          gridSize: gridSize,
          cellSize: cellSize,
          pulseValue: 0,
        ),
      ),
    );
  }

  Widget _buildBlockDock(double cellSize, bool isLandscape) {
    final controls = Obx(() {
      final canRotate =
          controller.isMyTurn.value && !controller.gameFinishedRx.value;
      return IconButton(
        tooltip: '회전',
        icon: const Icon(Icons.rotate_right_rounded),
        onPressed: canRotate
            ? () {
                controller.clearHover();
                setState(() {
                  _currentRotation = (_currentRotation + 1) % rotationUnit;
                });
              }
            : null,
      );
    });

    final block = MpSharedBlocks(
      controller: controller,
      cellSize: cellSize,
      gridKey: _gridKey,
      rotation: _currentRotation,
    );

    if (isLandscape) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          controls,
          const SizedBox(height: 12),
          block,
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        block,
        const SizedBox(width: 10),
        controls,
      ],
    );
  }

  Widget _buildGameStatusPanel() {
    return Obx(() {
      final myRole = controller.myRole;
      final isMyTurn = controller.isMyTurn.value;
      final turnRole = _service.currentTurn.value;
      final turnName =
          turnRole == myRole ? widget.myNickname : widget.opponentNickname;
      final statusText = controller.gameFinishedRx.value
          ? _winnerText()
          : isMyTurn
              ? '내 차례입니다. 블록을 보드에 놓으세요.'
              : '상대 차례입니다. 잠시 기다려 주세요.';

      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _TurnDot(active: isMyTurn),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '현재 턴: $turnName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.subtitle.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              statusText,
              style: AppTypography.bodySmall.copyWith(
                color: isMyTurn ? AppColors.primary : AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppActionButton(
                    label: '다시 시작',
                    icon: Icons.refresh_rounded,
                    height: 42,
                    tone: AppButtonTone.secondary,
                    onPressed: _restartGame,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppActionButton(
                    label: '나가기',
                    icon: Icons.exit_to_app_rounded,
                    height: 42,
                    tone: AppButtonTone.secondary,
                    onPressed: () {
                      if (controller.gameFinished) {
                        _leaveFinishedGame();
                      } else {
                        showMpLeaveDialog(context);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Future<void> _restartGame() async {
    await _service.leaveRoom(countAsForfeit: !controller.gameFinished);
    _service.configureMode(MultiplayerMode.ranked);
    await _service.quickMatch();
    if (Get.key.currentState?.canPop() ?? false) {
      Get.back();
    }
  }

  Future<void> _leaveFinishedGame() async {
    await _service.leaveRoom();
    if (Get.key.currentState?.canPop() ?? false) {
      Get.back();
    }
  }

  String _winnerText() {
    final won = controller.iWon.value;
    if (won == true) return '게임 종료: 내가 이겼습니다.';
    if (won == false) return '게임 종료: 상대가 이겼습니다.';
    return '게임 종료: 무승부입니다.';
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '블록 안내',
            style: AppTypography.label.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              _LegendItem(
                label: '내 블록',
                color: AppColors.primary,
                icon: Icons.circle_rounded,
              ),
              _LegendItem(
                label: '상대 블록',
                color: AppColors.tileCoral,
                icon: Icons.change_history_rounded,
              ),
              _LegendItem(
                label: '빈 칸',
                color: AppColors.surfaceMuted,
                icon: Icons.crop_square_rounded,
              ),
              _LegendItem(
                label: '벽',
                color: AppColors.ink,
                icon: Icons.close_rounded,
                dark: true,
              ),
              _LegendItem(
                label: '사용 불가',
                color: AppColors.backgroundSoft,
                icon: Icons.block_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TurnDot extends StatelessWidget {
  final bool active;

  const _TurnDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.tileCoral,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool dark;

  const _LegendItem({
    required this.label,
    required this.color,
    required this.icon,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = dark ? AppColors.surface : AppColors.ink;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: AppColors.ink.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, size: 13, color: foreground),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
