import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constant.dart';
import '../controllers/multiplayer_game_controller.dart';
import '../services/multiplayer_service.dart';
import '../theme/app_design_system.dart';
import '../theme/app_typography.dart';
import '../widgets/home_screen/background_painter.dart';
import 'multiplayer_game/mp_game_over_overlay.dart';
import 'multiplayer_game/mp_leave_dialog.dart';
import 'multiplayer_game/mp_shared_blocks.dart';
import 'multiplayer_game/multiplayer_board.dart';
import 'package:google_fonts/google_fonts.dart';

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
  int _turnSecondsRemaining = 15;
  int _localTurnStartedAtMs = DateTime.now().millisecondsSinceEpoch;
  Timer? _turnTimer;
  final List<Worker> _turnClockWorkers = [];

  @override
  void initState() {
    super.initState();
    controller = Get.put(
      MultiplayerGameController(
        roomId: widget.roomId,
        seed: widget.seed,
        mode: widget.mode,
        myUserId: widget.myUserId,
        opponentUserId: widget.opponentUserId,
        myNickname: widget.myNickname,
        opponentNickname: widget.opponentNickname,
      ),
      tag: widget.roomId,
    );
    _turnClockWorkers
      ..add(ever(_service.currentTurn, (_) => _resetLocalTurnClock()))
      ..add(ever(_service.turnExpiresAtMs, (_) => _syncTurnClock()))
      ..add(ever(_service.roomStatus, (_) => _resetLocalTurnClock()));
    _startTurnClock();
  }

  @override
  void dispose() {
    for (final worker in _turnClockWorkers) {
      worker.dispose();
    }
    _turnTimer?.cancel();
    Get.delete<MultiplayerGameController>(tag: widget.roomId);
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
        body: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: GridPatternPainter()),
            ),
            SafeArea(
              child: Obx(() {
                final status = _service.roomStatus.value;
                return Stack(
                  children: [
                    if (status == 'selecting') _buildSelectionPhase(),
                    if (status == 'playing' || status == 'finished')
                      _buildPlayingPhase(),
                    if (status == 'playing' || status == 'selecting') ...[
                      Obx(() => controller.isOpponentDisconnected
                          ? const _NetworkStatusOverlay()
                          : const SizedBox.shrink()),
                      _YourTurnOverlay(controller: controller),
                    ],
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
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionPhase() {
    final mySelection = controller.mySelectedBlock;
    if (mySelection != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.tileAmber,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.ink, width: AppStroke.strong),
            boxShadow: AppShadows.hard(offset: 3),
          ),
          child: Text(
            '$mySelection 선택 완료',
            style: AppTypography.subtitle.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
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
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: blocks
                      .map(
                        (block) => InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => controller.selectBlock(block),
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.ink,
                                width: AppStroke.strong,
                              ),
                              boxShadow: AppShadows.hard(offset: 3),
                            ),
                            child: Center(
                              child: Text(
                                block,
                                style: AppTypography.title.copyWith(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
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
        return _BoardShakeWrapper(
          controller: controller,
          child: _buildStackedLayout(constraints),
        );
      },
    );
  }

  Widget _buildStackedLayout(BoxConstraints constraints) {
    final padding = constraints.maxWidth < 380 ? 10.0 : 14.0;
    final gap = constraints.maxHeight < 650 ? 10.0 : 16.0;
    final maxContentWidth =
        (constraints.maxWidth - padding * 2).clamp(0.0, 820.0).toDouble();
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 142, child: _buildMatchHeader()),
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

  double _calculateStackedGridSize(
    BoxConstraints constraints, {
    required double padding,
    required double gap,
    required double maxContentWidth,
  }) {
    const headerHeight = 142.0;
    const boardPadding = 8.0;
    const trayPadding = 36.0;
    const previewRatio = 2.75 / gridColumns;
    final maxByWidth = maxContentWidth - 8;
    final maxByHeight = (constraints.maxHeight -
            padding * 2 -
            headerHeight -
            gap * 2 -
            boardPadding -
            trayPadding) /
        (1 + previewRatio);
    final gridSize = maxByWidth < maxByHeight ? maxByWidth : maxByHeight;
    return gridSize.clamp(120, 560).toDouble();
  }

  Widget _buildMatchHeader() {
    return Obx(() {
      final myScore = _scoreForRole(controller.myRole);
      final opponentScore = _scoreForRole(controller.opponentRole);

      return Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ScoreBlock(
                    label: 'YOU',
                    score: _formatScore(myScore),
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(
                  width: 96,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'VS',
                        style: AppTypography.title.copyWith(
                          color: AppColors.ink.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _TimerBadge(
                        label: _formatTurnClock(),
                        urgent: _turnSecondsRemaining <= 5,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _ScoreBlock(
                    label: 'OPPONENT',
                    score: _formatScore(opponentScore),
                    color: AppColors.tileCoral,
                    alignEnd: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _buildBoardPanel(double gridSize, double cellSize) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ink, width: AppStroke.strong),
        boxShadow: AppShadows.hard(offset: 4),
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
          rotation: _currentRotation,
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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ink, width: AppStroke.strong),
        boxShadow: AppShadows.hard(offset: 4),
      ),
      child: Center(
        child: block,
      ),
    );
  }

  void _rotateCurrentBlock() {
    final canPlay =
        controller.isMyTurn.value && !controller.gameFinishedRx.value;
    if (!canPlay) return;

    controller.clearPendingPlacement();
    setState(() {
      _currentRotation = (_currentRotation + 1) % rotationUnit;
    });
  }

  int _scoreForRole(String? role) {
    if (role == null) return 0;
    var total = 0;
    for (final row in _service.board) {
      for (final cell in row) {
        if (cell == role) total += 1;
      }
    }
    return total;
  }

  String _formatScore(int score) {
    return score.clamp(0, 99).toString().padLeft(2, '0');
  }

  String _formatTurnClock() {
    final minutes = _turnSecondsRemaining ~/ 60;
    final seconds = _turnSecondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _syncTurnClock() {
    if (!mounted) return;
    setState(() => _turnSecondsRemaining = _calculateTurnSecondsRemaining());
  }

  void _resetLocalTurnClock() {
    _localTurnStartedAtMs = DateTime.now().millisecondsSinceEpoch;
    _syncTurnClock();
  }

  int _calculateTurnSecondsRemaining() {
    final durationMs = _service.turnDurationMs.value;
    final expiresAt = _service.turnExpiresAtMs.value;
    if (_service.roomStatus.value != 'playing') {
      return (durationMs / 1000).ceil();
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final remainingMs = expiresAt == null
        ? durationMs - (now - _localTurnStartedAtMs)
        : expiresAt - (now + _service.serverTimeOffsetMs.value);
    if (remainingMs <= 0) return 0;
    return (remainingMs / 1000).ceil();
  }

  void _startTurnClock() {
    _turnTimer?.cancel();
    _syncTurnClock();
    _turnTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || controller.gameFinishedRx.value) return;
      _syncTurnClock();
    });
  }
}

class _ScoreBlock extends StatelessWidget {
  final String label;
  final String score;
  final Color color;
  final bool alignEnd;

  const _ScoreBlock({
    required this.label,
    required this.score,
    required this.color,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment:
              alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: alignEnd ? TextAlign.right : TextAlign.left,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            score,
            style: GoogleFonts.blackHanSans(
              color: color,
              fontSize: 58,
              height: 1,
              letterSpacing: 0,
              shadows: [
                Shadow(
                  color: AppColors.ink.withValues(alpha: 0.18),
                  offset: const Offset(2, 2),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimerBadge extends StatelessWidget {
  final String label;
  final bool urgent;

  const _TimerBadge({
    required this.label,
    required this.urgent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 84),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: urgent ? AppColors.dangerSoft : AppColors.tileAmber,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.ink,
          width: AppStroke.strong,
        ),
        boxShadow: AppShadows.hard(offset: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: AppTypography.subtitle.copyWith(
              color: urgent ? AppColors.dangerStrong : AppColors.ink,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkStatusOverlay extends StatelessWidget {
  const _NetworkStatusOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.dangerStrong,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppShadows.hard(offset: 2),
            border: Border.all(color: AppColors.ink, width: AppStroke.strong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.surface,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '상대방 연결을 기다리는 중...',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.surface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _YourTurnOverlay extends StatefulWidget {
  final MultiplayerGameController controller;

  const _YourTurnOverlay({required this.controller});

  @override
  State<_YourTurnOverlay> createState() => _YourTurnOverlayState();
}

class _YourTurnOverlayState extends State<_YourTurnOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  Worker? _turnWorker;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.5, end: 1.1)
              .chain(CurveTween(curve: Curves.easeOutBack)),
          weight: 15),
      TweenSequenceItem(
          tween: Tween(begin: 1.1, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.8)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 15),
    ]).animate(_animController);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 75),
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 15),
    ]).animate(_animController);

    _turnWorker = ever(widget.controller.isMyTurn, (isMyTurn) {
      if (isMyTurn && !widget.controller.gameFinishedRx.value) {
        _animController.forward(from: 0.0);
      }
    });
  }

  @override
  void dispose() {
    _turnWorker?.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            if (_animController.isDismissed) return const SizedBox.shrink();
            return Center(
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Transform.translate(
                    offset: const Offset(0, -50),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.ink, width: AppStroke.strong),
                        boxShadow: AppShadows.hard(offset: 4),
                      ),
                      child: Text(
                        'YOUR TURN!',
                        style: GoogleFonts.blackHanSans(
                          color: AppColors.ink,
                          fontSize: 42,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BoardShakeWrapper extends StatefulWidget {
  final MultiplayerGameController controller;
  final Widget child;

  const _BoardShakeWrapper({
    required this.controller,
    required this.child,
  });

  @override
  State<_BoardShakeWrapper> createState() => _BoardShakeWrapperState();
}

class _BoardShakeWrapperState extends State<_BoardShakeWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Worker? _placedWorker;
  Worker? _clearedWorker;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _placedWorker = ever(widget.controller.lastPlacedCells, (cells) {
      if (cells.isNotEmpty) {
        _animController.duration = const Duration(milliseconds: 150);
        _animController.forward(from: 0.0);
      }
    });
    _clearedWorker = ever(widget.controller.lastClearedCells, (cells) {
      if (cells.isNotEmpty) {
        _animController.duration = const Duration(milliseconds: 350);
        _animController.forward(from: 0.0);
      }
    });
  }

  @override
  void dispose() {
    _placedWorker?.dispose();
    _clearedWorker?.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final double t = _animController.value;
        if (t == 0.0 || t == 1.0) return child!;
        
        final double offset = 5 * math.sin(t * math.pi * 4) * (1 - t);
        return Transform.translate(
          offset: Offset(offset, offset / 2),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

