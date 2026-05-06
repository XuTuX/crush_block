import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:link_your_area/theme/app_components.dart';
import 'package:link_your_area/theme/app_design_system.dart';
import 'package:link_your_area/theme/app_typography.dart';

class CustomAlertDialog extends StatelessWidget {
  final String title;
  final String message;
  final String buttonText;

  const CustomAlertDialog({
    super.key,
    required this.title,
    required this.message,
    this.buttonText = '확인',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: AppModalSurface(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.subtitle.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppActionButton(
                label: buttonText,
                height: 48,
                onPressed: () => Get.back(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showCustomAlert(String title, String message) {
  Get.dialog(
    CustomAlertDialog(title: title, message: message),
    barrierColor: AppColors.ink.withValues(alpha: 0.5),
  );
}

class CustomConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final VoidCallback onConfirm;

  const CustomConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onConfirm,
    this.confirmText = '확인',
    this.cancelText = '취소',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: AppModalSurface(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.subtitle.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: AppActionButton(
                      label: cancelText,
                      tone: AppButtonTone.secondary,
                      height: 48,
                      onPressed: () => Get.back(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppActionButton(
                      label: confirmText,
                      height: 48,
                      onPressed: () {
                        Get.back();
                        onConfirm();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showCustomConfirm(
  String title,
  String message,
  VoidCallback onConfirm, {
  String confirmText = '확인',
  String cancelText = '취소',
}) {
  Get.dialog(
    CustomConfirmDialog(
      title: title,
      message: message,
      onConfirm: onConfirm,
      confirmText: confirmText,
      cancelText: cancelText,
    ),
    barrierColor: AppColors.ink.withValues(alpha: 0.5),
  );
}
