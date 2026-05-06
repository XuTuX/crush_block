import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/multiplayer_service.dart';
import '../controllers/multiplayer_game_controller.dart';
import '../theme/app_design_system.dart';
import '../theme/app_typography.dart';
import 'multiplayer_game/mp_game_over_overlay.dart';
import 'multiplayer_game/mp_leave_dialog.dart';
import '../widgets/mp_buttons.dart';

class MultiplayerGameScreen extends StatefulWidget {
  final String roomId;
  final String myUserId;
  final String opponentUserId;
  final String myNickname;
  final String opponentNickname;
  final String myPortraitId;
  final String opponentPortraitId;
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
    required this.myPortraitId,
    required this.opponentPortraitId,
  });

  @override
  State<MultiplayerGameScreen> createState() => _MultiplayerGameScreenState();
}

class _MultiplayerGameScreenState extends State<MultiplayerGameScreen> {
  late MultiplayerGameController controller;
  final MultiplayerService _service = Get.find<MultiplayerService>();
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
    controller.myPortraitId.value = widget.myPortraitId;
    controller.opponentPortraitId.value = widget.opponentPortraitId;
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
                  myPortraitId: widget.myPortraitId,
                  opponentPortraitId: widget.opponentPortraitId,
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
              style: AppTypography.display.copyWith(
                color: AppColors.primary,
                fontSize: 28,
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
            style: AppTypography.display
                .copyWith(color: AppColors.primary, fontSize: 32),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: blocks
                .map((b) => GestureDetector(
                      onTap: () => controller.selectBlock(b),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: AppColors.primary, width: 2),
                        ),
                        child: Center(
                          child: Text(b,
                              style:
                                  AppTypography.display.copyWith(fontSize: 40)),
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

    final cellSize = MediaQuery.of(context).size.width / 11;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPlayerBanner(widget.opponentNickname, 'player2'),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              border: Border.all(color: AppColors.borderSoft, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(9, (y) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(9, (x) {
                    final cell = board[y][x];
                    Color c = AppColors.background;
                    if (cell == 'wall') {
                      c = AppColors.ink;
                    } else if (cell == controller.myRole) {
                      c = controller.myBlockColor.value;
                    } else if (cell == controller.opponentRole) {
                      c = controller.opponentBlockColor.value;
                    }

                    return GestureDetector(
                      onTap: () {
                        if (controller.isMyTurn.value) {
                          controller.placeBlock(x, y, _currentRotation);
                        }
                      },
                      child: Container(
                        width: cellSize,
                        height: cellSize,
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color:
                                  AppColors.borderSoft.withValues(alpha: 0.5)),
                        ),
                      ),
                    );
                  }),
                );
              }),
            ),
          ),
          const SizedBox(height: 20),
          if (controller.isMyTurn.value)
            ElevatedButton.icon(
              icon: const Icon(Icons.rotate_right),
              label: Text('블록 회전 ($_currentRotation)'),
              onPressed: () {
                setState(() {
                  _currentRotation = (_currentRotation + 1) % 4;
                });
              },
            ),
          const SizedBox(height: 10),
          _buildPlayerBanner(widget.myNickname, 'player1'),
        ],
      ),
    );
  }

  Widget _buildPlayerBanner(String name, String role) {
    final isTurn = _service.currentTurn.value == role;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: isTurn ? AppColors.primarySoft : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTurn ? AppColors.primary : AppColors.borderSoft,
          width: 2,
        ),
      ),
      child: Text(
        name,
        style: AppTypography.display.copyWith(
          fontSize: 24,
          color: isTurn ? AppColors.primary : AppColors.textMuted,
        ),
      ),
    );
  }
}
