import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crush_block/services/database_service.dart';
import 'package:crush_block/theme/app_components.dart';
import 'package:crush_block/theme/app_design_system.dart';
import 'package:crush_block/theme/app_typography.dart';
import 'package:crush_block/utils/random_nickname_generator.dart';

class EditNicknameDialog extends StatefulWidget {
  final String currentNickname;
  final Future<String?> Function(String) onSave;
  final bool isInitialSetup;

  const EditNicknameDialog({
    super.key,
    required this.currentNickname,
    required this.onSave,
    this.isInitialSetup = false,
  });

  @override
  State<EditNicknameDialog> createState() => _EditNicknameDialogState();
}

class _EditNicknameDialogState extends State<EditNicknameDialog> {
  late TextEditingController controller;
  String? errorMessage;
  bool isSaving = false;
  bool isGenerating = false;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.currentNickname);
    if (widget.currentNickname.isEmpty) {
      _generateRandom();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _generateRandom() async {
    if (isGenerating) return;

    setState(() {
      isGenerating = true;
      errorMessage = null;
    });

    final dbService = Get.find<DatabaseService>();
    String candidate = '';
    var available = false;
    var attempts = 0;

    while (attempts < 10 && !available) {
      candidate = RandomNicknameGenerator.generate();
      available = await dbService.checkNicknameAvailable(candidate);
      attempts++;
    }

    if (!mounted) return;

    setState(() {
      isGenerating = false;
      if (available) {
        controller.text = candidate;
      } else {
        errorMessage = '랜덤 닉네임 생성에 실패했습니다. 다시 시도해주세요.';
      }
    });
  }

  Future<void> _handleSave() async {
    final newNick = controller.text.trim();
    if (newNick.isEmpty) {
      setState(() {
        errorMessage = '닉네임을 입력해주세요.';
      });
      return;
    }

    if (!widget.isInitialSetup && newNick == widget.currentNickname) {
      Get.back();
      return;
    }

    setState(() {
      isSaving = true;
    });

    final error = await widget.onSave(newNick);
    if (!mounted) return;

    if (error != null) {
      setState(() {
        errorMessage = error;
        isSaving = false;
      });
      return;
    }

    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final dialog = Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          child: AppModalSurface(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.isInitialSetup ? '닉네임 설정' : '닉네임 변경',
                  textAlign: TextAlign.center,
                  style: AppTypography.subtitle.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '게임에서 사용할 이름을 입력해주세요.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppTextInput(
                  controller: controller,
                  hintText: '닉네임 입력',
                  errorText: errorMessage,
                  onChanged: (_) {
                    if (errorMessage != null) {
                      setState(() {
                        errorMessage = null;
                      });
                    }
                  },
                  suffixIcon: isGenerating
                      ? Transform.scale(
                          scale: 0.45,
                          child: const CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2.4,
                          ),
                        )
                      : IconButton(
                          onPressed: _generateRandom,
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                  helperText: '새로고침으로 사용 가능한 랜덤 닉네임을 만들 수 있어요.',
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    if (!widget.isInitialSetup) ...[
                      Expanded(
                        child: AppActionButton(
                          label: '취소',
                          tone: AppButtonTone.secondary,
                          height: 48,
                          onPressed: () => Get.back(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      child: AppActionButton(
                        label: '저장',
                        isLoading: isSaving,
                        height: 48,
                        onPressed: isSaving ? null : _handleSave,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.isInitialSetup) {
      return PopScope(
        canPop: false,
        child: dialog,
      );
    }

    return dialog;
  }
}
