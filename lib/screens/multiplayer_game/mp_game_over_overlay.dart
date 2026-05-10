import 'package:crush_block/services/multiplayer_service.dart';
import 'package:crush_block/theme/app_components.dart';
import 'package:crush_block/theme/app_design_system.dart';
import 'package:crush_block/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/multiplayer_game_controller.dart';

class MpGameOverOverlay extends StatefulWidget {
  final MultiplayerGameController controller;
  final MultiplayerMode mode;
  final String myNickname;
  final String opponentNickname;
  final String roomId;

  const MpGameOverOverlay({
    super.key,
    required this.controller,
    required this.mode,
    required this.myNickname,
    required this.opponentNickname,
    required this.roomId,
  });

  @override
  State<MpGameOverOverlay> createState() => _MpGameOverOverlayState();
}

class _MpGameOverOverlayState extends State<MpGameOverOverlay>
    with SingleTickerProviderStateMixin {
  Worker? _gameFinishedWorker;

  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _fadeIn = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideUp = Tween<double>(begin: 12, end: 0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _gameFinishedWorker = ever<bool>(
      widget.controller.gameFinishedRx,
      (finished) {
        if (finished) {
          _animController.forward();
        }
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.controller.gameFinishedRx.value) {
        _animController.forward();
      }
    });
  }

  @override
  void dispose() {
    _gameFinishedWorker?.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!widget.controller.gameFinishedRx.value) {
        return const SizedBox.shrink();
      }

      final won = widget.controller.iWon.value;
      final opponentLeft = widget.controller.opponentLeftMessage.value;
      final config = _buildResultConfig(
        won: won,
        opponentLeft: opponentLeft,
      );

      return Positioned.fill(
        child: FadeTransition(
          opacity: _fadeIn,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  color: AppColors.ink.withValues(alpha: 0.36),
                ),
              ),
              SafeArea(
                child: AnimatedBuilder(
                  animation: _slideUp,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _slideUp.value),
                      child: child,
                    );
                  },
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: _buildResultCard(config),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildResultCard(_MpResultConfig config) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.ink,
          width: AppStroke.strong,
        ),
        boxShadow: AppShadows.liftedCard,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: config.titleColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  config.title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.subtitle.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildPlayerResultRow(config),
          if (config.subtitle != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.ink,
                  width: AppStroke.soft,
                ),
              ),
              child: Text(
                config.subtitle!,
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _OverlayActionButton(
            label: '다시 시작',
            icon: Icons.refresh_rounded,
            filled: true,
            onPressed: () async {
              final mpService = Get.find<MultiplayerService>();
              await mpService.leaveRoom();
              mpService.configureMode(MultiplayerMode.ranked);
              await mpService.quickMatch();
              if (Get.key.currentState?.canPop() ?? false) {
                Get.back();
              }
            },
          ),
          const SizedBox(height: 8),
          _OverlayActionButton(
            label: '나가기',
            icon: Icons.arrow_back_rounded,
            onPressed: () async {
              final mpService = Get.find<MultiplayerService>();
              await mpService.leaveRoom();
              if (Get.key.currentState?.canPop() ?? false) {
                Get.back();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerResultRow(_MpResultConfig config) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ink, width: AppStroke.soft),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PlayerResultBadge(
              label: '나',
              nickname: widget.myNickname,
              color: AppColors.primary,
              icon: Icons.circle_rounded,
              active: config.winnerSide == _WinnerSide.me,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              width: 1,
              height: 38,
              color: AppColors.ink,
            ),
          ),
          Expanded(
            child: _PlayerResultBadge(
              label: '상대',
              nickname: widget.opponentNickname,
              color: AppColors.tileCoral,
              icon: Icons.change_history_rounded,
              active: config.winnerSide == _WinnerSide.opponent,
              alignEnd: true,
            ),
          ),
        ],
      ),
    );
  }

  _MpResultConfig _buildResultConfig({
    required bool? won,
    required String? opponentLeft,
  }) {
    if (won == true) {
      String? subtitle;
      if (opponentLeft != null) {
        subtitle = opponentLeft;
      }
      return _MpResultConfig(
        title: '승리',
        subtitle: subtitle,
        titleColor: AppColors.primary,
        winnerSide: _WinnerSide.me,
      );
    }

    if (won == false) {
      return const _MpResultConfig(
        title: '패배',
        subtitle: null,
        titleColor: AppColors.danger,
        winnerSide: _WinnerSide.opponent,
      );
    }

    return const _MpResultConfig(
      title: '무승부',
      subtitle: null,
      titleColor: AppColors.textMuted,
      winnerSide: _WinnerSide.none,
    );
  }
}

enum _WinnerSide { me, opponent, none }

class _MpResultConfig {
  final String title;
  final String? subtitle;
  final Color titleColor;
  final _WinnerSide winnerSide;

  const _MpResultConfig({
    required this.title,
    required this.subtitle,
    required this.titleColor,
    required this.winnerSide,
  });
}

class _PlayerResultBadge extends StatelessWidget {
  final String label;
  final String nickname;
  final Color color;
  final IconData icon;
  final bool active;
  final bool alignEnd;

  const _PlayerResultBadge({
    required this.label,
    required this.nickname,
    required this.color,
    required this.icon,
    required this.active,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment:
              alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!alignEnd) _ResultMark(color: color, icon: icon),
            if (!alignEnd) const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: alignEnd
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppTypography.tiny.copyWith(
                      color: active ? color : AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    nickname,
                    textAlign: alignEnd ? TextAlign.right : TextAlign.left,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.ink,
                      fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (alignEnd) const SizedBox(width: 8),
            if (alignEnd) _ResultMark(color: color, icon: icon),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 2,
          width: 48,
          decoration: BoxDecoration(
            color: active ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ],
    );
  }
}

class _ResultMark extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _ResultMark({
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}

class _OverlayActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onPressed;

  const _OverlayActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return AppActionButton(
        label: label,
        icon: icon,
        height: 46,
        onPressed: onPressed,
      );
    }

    return AppActionButton(
      label: label,
      icon: icon,
      tone: AppButtonTone.secondary,
      height: 46,
      onPressed: onPressed,
    );
  }
}
