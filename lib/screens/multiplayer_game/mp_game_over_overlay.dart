import 'package:crush_block/services/multiplayer_service.dart';
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
                  color: AppColors.ink.withValues(alpha: 0.45),
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
                        padding: const EdgeInsets.symmetric(horizontal: 24),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderSoft,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPlayerResultRow(config),

          const SizedBox(height: AppSpacing.lg),

          // Title (승리! / 패배 / 무승부)
          Text(
            config.title,
            textAlign: TextAlign.center,
            style: AppTypography.title.copyWith(
              color: config.titleColor,
              fontWeight: FontWeight.w900,
            ),
          ),

          // Subtitle
          if (config.subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              config.subtitle!,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),

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
            icon: Icons.home_rounded,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: _PlayerResultBadge(
              label: '내 블록',
              nickname: widget.myNickname,
              color: AppColors.primary,
              icon: Icons.circle_rounded,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'VS',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSubtle,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontSize: 12,
              ),
            ),
          ),
          Flexible(
            child: _PlayerResultBadge(
              label: '상대 블록',
              nickname: widget.opponentNickname,
              color: AppColors.tileCoral,
              icon: Icons.change_history_rounded,
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
        title: '승리!',
        subtitle: subtitle,
        titleColor: AppColors.success,
      );
    }

    if (won == false) {
      return const _MpResultConfig(
        title: '패배',
        subtitle: null,
        titleColor: AppColors.danger,
      );
    }

    return const _MpResultConfig(
      title: '무승부',
      subtitle: '두 플레이어 모두 무승부입니다.',
      titleColor: AppColors.primary,
    );
  }
}

class _MpResultConfig {
  final String title;
  final String? subtitle;
  final Color titleColor;

  const _MpResultConfig({
    required this.title,
    required this.subtitle,
    required this.titleColor,
  });
}

class _PlayerResultBadge extends StatelessWidget {
  final String label;
  final String nickname;
  final Color color;
  final IconData icon;

  const _PlayerResultBadge({
    required this.label,
    required this.nickname,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppTypography.tiny.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          nickname,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption.copyWith(
            color: AppColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
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
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size(0, 44),
          textStyle: AppTypography.label.copyWith(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.borderSoft),
        minimumSize: const Size(0, 44),
        textStyle: AppTypography.label.copyWith(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    );
  }
}
