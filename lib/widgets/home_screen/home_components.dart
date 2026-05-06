import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crush_block/services/auth_service.dart';
import 'package:crush_block/services/database_service.dart';
import 'package:crush_block/services/shop_service.dart';
import 'package:crush_block/theme/app_components.dart';
import 'package:crush_block/theme/app_design_system.dart';
import 'package:crush_block/theme/app_typography.dart';
import 'package:crush_block/widgets/brand_assets.dart';
import 'package:crush_block/widgets/portrait_avatar.dart';

class HomeLogo extends StatelessWidget {
  const HomeLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppBrandLogo();
  }
}

class NicknameCard extends StatelessWidget {
  final AuthService authService;
  final DatabaseService dbService;
  final bool showRankProgress;

  const NicknameCard({
    super.key,
    required this.authService,
    required this.dbService,
    this.showRankProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    final shopService = Get.find<ShopService>();

    return Obx(() {
      final nickname = authService.userNickname.value;
      final isLoading = authService.isLoading.value;

      return AppSurface(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          children: [
            if (isLoading)
              const SizedBox(
                height: 52,
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: AppColors.ink,
                      strokeWidth: 2.2,
                    ),
                  ),
                ),
              )
            else if (nickname != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Obx(
                    () => PortraitAvatar(
                      assetPath: shopService.selectedPortrait.assetPath,
                      size: 80, // Increased size from 64 to 80
                      accentColor: AppColors.primary,
                      borderWidth: 0,
                      glowOpacity: 0,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(
                      width: AppSpacing.md), // Changed spacing from sm to md
                  Flexible(
                    child: Text(
                      nickname,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.subtitle.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Obx(() {
                dbService.rankedSummaryRefreshToken.value;

                return FutureBuilder<RankedProfileSummary>(
                  future: dbService.getMyRankedSummary(),
                  builder: (context, snapshot) {
                    final summary = snapshot.data ??
                        dbService.myRankedSummary.value ??
                        DatabaseService.buildRankedSummary(0);

                    return Column(
                      children: [
                        _StatBadge(
                          value: '${summary.gradeLabel}  ${summary.points}점',
                          backgroundColor: AppColors.surfaceMuted,
                          leading: Image.asset(
                            summary.gradeIconPath,
                            width: 22,
                            height: 22,
                          ),
                        ),
                        if (showRankProgress) ...[
                          const SizedBox(height: AppSpacing.sm),
                          RankProgressStrip(summary: summary),
                        ],
                      ],
                    );
                  },
                );
              }),
            ] else
              Text(
                '로그인하여 기록과 랭킹을 저장하세요',
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      );
    });
  }
}

class RankProgressPanel extends StatelessWidget {
  final AuthService authService;
  final DatabaseService dbService;

  const RankProgressPanel({
    super.key,
    required this.authService,
    required this.dbService,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final nickname = authService.userNickname.value;

      if (authService.isLoading.value || nickname == null) {
        return const SizedBox.shrink();
      }

      dbService.rankedSummaryRefreshToken.value;

      return FutureBuilder<RankedProfileSummary>(
        future: dbService.getMyRankedSummary(),
        builder: (context, snapshot) {
          final summary = snapshot.data ??
              dbService.myRankedSummary.value ??
              DatabaseService.buildRankedSummary(0);
          return RankProgressStrip(summary: summary);
        },
      );
    });
  }
}

class RankProgressStrip extends StatelessWidget {
  final RankedProfileSummary summary;

  const RankProgressStrip({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final helperText = summary.isMaxGrade
        ? '최고 티어에 도달했어요'
        : '다음 ${summary.nextGradeLabel}까지 ${summary.pointsToNextGrade}점';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!summary.isMaxGrade && summary.nextGradeLabel != null) ...[
                Image.asset(
                  DatabaseService.gradeIconPathForLabel(
                      summary.nextGradeLabel!),
                  width: 18,
                  height: 18,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  helperText,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                summary.isMaxGrade
                    ? '${summary.points}점'
                    : '${summary.pointsIntoGrade}/${summary.pointsInTier}점',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.round),
            child: LinearProgressIndicator(
              value: summary.progressToNextGrade,
              minHeight: 6,
              backgroundColor: AppColors.borderSoft,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final Widget leading;
  final String value;
  final Color backgroundColor;

  const _StatBadge({
    required this.leading,
    required this.value,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          leading,
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppActionButton(
      label: label,
      onPressed: onPressed,
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  const SecondaryButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppActionButton(
      label: label,
      icon: icon,
      tone: AppButtonTone.secondary,
      onPressed: onPressed,
    );
  }
}

class ProfileButton extends StatelessWidget {
  final AuthService authService;
  final VoidCallback onProfileTap;
  final VoidCallback onLoginTap;

  const ProfileButton({
    super.key,
    required this.authService,
    required this.onProfileTap,
    required this.onLoginTap,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (authService.isLoading.value) {
        return const AppIconCircleButton(
          icon: Icons.more_horiz_rounded,
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              color: AppColors.ink,
              strokeWidth: 2,
            ),
          ),
        );
      }

      if (authService.loginSuccess.value) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.9, end: 1),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: const AppIconCircleButton(
                icon: Icons.check_rounded,
                backgroundColor: AppColors.successSoft,
                foregroundColor: AppColors.success,
              ),
            );
          },
        );
      }

      return AppIconCircleButton(
        icon: authService.user.value == null
            ? Icons.person_outline_rounded
            : Icons.settings_rounded,
        onTap: authService.user.value == null ? onLoginTap : onProfileTap,
        foregroundColor: AppColors.ink,
      );
    });
  }
}
