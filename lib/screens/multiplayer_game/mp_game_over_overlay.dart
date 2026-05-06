import 'package:crush_block/services/database_service.dart';
import 'package:crush_block/services/multiplayer_service.dart';
import 'package:crush_block/services/shop_service.dart';
import 'package:crush_block/theme/app_components.dart';
import 'package:crush_block/theme/app_design_system.dart';
import 'package:crush_block/theme/app_typography.dart';
import 'package:crush_block/widgets/portrait_avatar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/multiplayer_game_controller.dart';

class MpGameOverOverlay extends StatefulWidget {
  final MultiplayerGameController controller;
  final MultiplayerMode mode;
  final String myNickname;
  final String opponentNickname;
  final String myPortraitId;
  final String opponentPortraitId;
  final String roomId;

  const MpGameOverOverlay({
    super.key,
    required this.controller,
    required this.mode,
    required this.myNickname,
    required this.opponentNickname,
    required this.myPortraitId,
    required this.opponentPortraitId,
    required this.roomId,
  });

  @override
  State<MpGameOverOverlay> createState() => _MpGameOverOverlayState();
}

class _MpGameOverOverlayState extends State<MpGameOverOverlay>
    with SingleTickerProviderStateMixin {
  bool _rankApplied = false;
  bool _resultProcessingStarted = false;
  RankedMatchResult? _rankResult;
  Worker? _gameFinishedWorker;

  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeIn = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideUp = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _gameFinishedWorker = ever<bool>(
      widget.controller.gameFinishedRx,
      (finished) {
        if (finished) {
          _handleGameFinished();
          _animController.forward();
        }
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.controller.gameFinishedRx.value) {
        _handleGameFinished();
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

  Future<void> _applyRankResult(bool? won) async {
    if (_rankApplied || !widget.mode.isRanked) return;
    _rankApplied = true;

    debugPrint('🏆 _applyRankResult: won=$won, mode=${widget.mode}');
    final dbService = Get.find<DatabaseService>();
    final result = await dbService.applyRankedMatchResult(won);
    debugPrint(
        '🏆 RankResult: before=${result.beforePoints}, after=${result.afterPoints}, delta=${result.delta}');
    if (!mounted) return;
    setState(() {
      _rankResult = result;
    });
  }

  Future<void> _handleGameFinished() async {
    if (_resultProcessingStarted) return;
    _resultProcessingStarted = true;

    final won = widget.controller.iWon.value;
    debugPrint(
        '🏆 _handleGameFinished: iWon=$won, isRanked=${widget.mode.isRanked}');

    if (widget.mode.isRanked) {
      await _applyRankResult(won);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!widget.controller.gameFinishedRx.value) {
        return const SizedBox.shrink();
      }

      final won = widget.controller.iWon.value;
      final opponentLeft = widget.controller.opponentLeftMessage.value;
      final wonByConnection = widget.controller.winnerUserId.value != null;
      final config = _buildResultConfig(
        won: won,
        wonByConnection: wonByConnection,
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: config.titleColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.08),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Portrait VS row
          _buildPortraitVersusRow(config),

          const SizedBox(height: AppSpacing.lg),

          // Title (승리! / 패배 / 무승부)
          Text(
            config.title,
            textAlign: TextAlign.center,
            style: AppTypography.display.copyWith(
              color: config.titleColor,
              fontSize: 40,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
              height: 1.1,
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

          // Ranked reward
          if (widget.mode.isRanked) ...[
            const SizedBox(height: AppSpacing.lg),
            _buildRankedReward(),
          ],

          const SizedBox(height: AppSpacing.xl),

          // Return button
          AppActionButton(
            label: '돌아가기',
            height: 48,
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

  Widget _buildRankedReward() {
    if (_rankResult == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            '포인트 계산 중...',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final result = _rankResult!;
    final delta = result.delta;
    final prefix = delta > 0 ? '+' : '';
    final valueColor = delta > 0
        ? AppColors.success
        : delta < 0
            ? AppColors.danger
            : AppColors.textMuted;
    final badgeIcon = delta > 0
        ? Icons.trending_up_rounded
        : delta < 0
            ? Icons.trending_down_rounded
            : Icons.horizontal_rule_rounded;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 메인 스코어 및 티어 영역
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(16),
          ),
          child: TweenAnimationBuilder<int>(
            tween:
                IntTween(begin: result.beforePoints, end: result.afterPoints),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        result.afterSummary.gradeIconPath,
                        width: 20,
                        height: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        result.afterSummary.gradeLabel,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$value',
                        style: AppTypography.display.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 32,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'P',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // 변화량 뱃지 영역 (+10점 등)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: valueColor,
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: valueColor.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                badgeIcon,
                color: AppColors.onPrimary,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                '$prefix$delta 점',
                style: AppTypography.label.copyWith(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitVersusRow(_MpResultConfig config) {
    final shopService = Get.find<ShopService>();
    final myCharacter = shopService.characterItemForId(
          widget.controller.myCharacterId.value,
        ) ??
        shopService.selectedCharacter;
    final opponentCharacter = shopService.characterItemForId(
          widget.controller.opponentCharacterId.value,
        ) ??
        shopService.characterItemForId(ShopService.characterCatalog.first.id) ??
        shopService.selectedCharacter;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // My portrait
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PortraitAvatar(
                  assetPath: shopService.portraitAssetForId(
                    widget.controller.myPortraitId.value.isNotEmpty
                        ? widget.controller.myPortraitId.value
                        : widget.myPortraitId,
                  ),
                  size: 68, // Increased size
                  accentColor: myCharacter.themeColor,
                  borderWidth: 2.0,
                  fit: BoxFit.contain, // Better for character slimes
                ),
                const SizedBox(height: 8),
                Text(
                  widget.myNickname,
                  textAlign: TextAlign.center,
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

          // VS label
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

          // Opponent portrait
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PortraitAvatar(
                  assetPath: shopService.portraitAssetForId(
                    widget.controller.opponentPortraitId.value.isNotEmpty
                        ? widget.controller.opponentPortraitId.value
                        : widget.opponentPortraitId,
                  ),
                  size: 68, // Increased size
                  accentColor: opponentCharacter.themeColor,
                  borderWidth: 2.0,
                  fit: BoxFit.contain, // Better for character slimes
                ),
                const SizedBox(height: 8),
                Text(
                  widget.opponentNickname,
                  textAlign: TextAlign.center,
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
        ],
      ),
    );
  }

  _MpResultConfig _buildResultConfig({
    required bool? won,
    required bool wonByConnection,
    required String? opponentLeft,
  }) {
    if (won == true) {
      String? subtitle;
      if (opponentLeft != null) {
        subtitle = opponentLeft;
      } else if (wonByConnection) {
        // Subtitle removed as per user request
      }
      return _MpResultConfig(
        title: '승리!',
        subtitle: subtitle,
        titleColor: AppColors.success,
      );
    }

    if (won == false) {
      String? subtitle;
      if (wonByConnection) {
        // Subtitle removed as per user request
      }
      return _MpResultConfig(
        title: '패배',
        subtitle: subtitle,
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
