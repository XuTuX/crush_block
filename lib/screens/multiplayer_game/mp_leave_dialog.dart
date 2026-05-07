import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crush_block/services/multiplayer_service.dart';
import 'package:crush_block/theme/app_components.dart';
import 'package:crush_block/theme/app_design_system.dart';
import 'package:crush_block/theme/app_typography.dart';

void showMpLeaveDialog(BuildContext context) {
  Get.dialog(
    Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        constraints: const BoxConstraints(maxWidth: 340),
        child: AppModalSurface(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.exit_to_app_rounded,
                color: AppColors.danger,
                size: 28,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '정말 나갈까요?',
                textAlign: TextAlign.center,
                style: AppTypography.title.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.dangerSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '지금 나가면 즉시 패배 처리됩니다.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: AppActionButton(
                      label: '계속하기',
                      tone: AppButtonTone.secondary,
                      height: 46,
                      onPressed: () => Get.back(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppActionButton(
                      label: '나가기',
                      tone: AppButtonTone.destructive,
                      height: 46,
                      onPressed: () async {
                        final mpService = Get.find<MultiplayerService>();
                        await mpService.leaveRoom(countAsForfeit: true);
                        Get.back();
                        if (Get.key.currentState?.canPop() ?? false) {
                          Get.back();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    barrierColor: AppColors.ink.withValues(alpha: 0.5),
  );
}
