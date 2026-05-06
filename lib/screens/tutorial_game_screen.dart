import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crush_block/controllers/tutorial_game_controller.dart';
import 'package:crush_block/theme/app_design_system.dart';
import 'package:crush_block/theme/app_typography.dart';
import 'package:crush_block/widgets/mp_buttons.dart';

class TutorialGameScreen extends StatefulWidget {
  const TutorialGameScreen({super.key});

  @override
  State<TutorialGameScreen> createState() => _TutorialGameScreenState();
}

class _TutorialGameScreenState extends State<TutorialGameScreen> {
  late final TutorialGameController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(TutorialGameController());
  }

  @override
  void dispose() {
    Get.delete<TutorialGameController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        'Crush Block',
                        style: AppTypography.subtitle.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      MpAppBarButton(
                        icon: Icons.close_rounded,
                        onPressed: () => Get.back(result: false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildBoardPreview(),
                        const SizedBox(height: 32),
                        Obx(() {
                          final page = controller.pages[controller.step.value];
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: Column(
                              key: ValueKey(controller.step.value),
                              children: [
                                Text(
                                  page.title,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.display.copyWith(
                                    color: AppColors.primary,
                                    fontSize: 34,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  page.body,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.body.copyWith(
                                    color: AppColors.textMuted,
                                    height: 1.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  Obx(() => Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: controller.step.value == 0
                                  ? null
                                  : controller.previous,
                              child: const Text('이전'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: controller.next,
                              child: Text(controller.isLast ? '완료' : '다음'),
                            ),
                          ),
                        ],
                      )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBoardPreview() {
    const preview = [
      [
        'empty',
        'empty',
        'empty',
        'empty',
        'wall',
        'empty',
        'empty',
        'empty',
        'empty'
      ],
      ['empty', 'p1', 'p1', 'p1', 'empty', 'empty', 'empty', 'empty', 'empty'],
      ['empty', 'empty', 'p1', 'empty', 'empty', 'empty', 'p2', 'p2', 'empty'],
      [
        'empty',
        'empty',
        'empty',
        'empty',
        'empty',
        'p2',
        'p2',
        'empty',
        'empty'
      ],
      ['wall', 'p1', 'p2', 'p1', 'p2', 'p1', 'p2', 'p1', 'wall'],
      [
        'empty',
        'empty',
        'empty',
        'empty',
        'empty',
        'empty',
        'empty',
        'empty',
        'empty'
      ],
      [
        'empty',
        'empty',
        'p2',
        'empty',
        'empty',
        'empty',
        'p1',
        'empty',
        'empty'
      ],
      ['empty', 'p2', 'p2', 'empty', 'empty', 'empty', 'p1', 'p1', 'empty'],
      [
        'empty',
        'empty',
        'empty',
        'empty',
        'wall',
        'empty',
        'empty',
        'empty',
        'empty'
      ],
    ];

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSoft, width: 2),
        ),
        child: Column(
          children: List.generate(9, (y) {
            return Expanded(
              child: Row(
                children: List.generate(9, (x) {
                  final cell = preview[y][x];
                  final color = switch (cell) {
                    'wall' => AppColors.ink,
                    'p1' => const Color(0xFFFF7043),
                    'p2' => const Color(0xFF42A5F5),
                    _ => AppColors.background,
                  };
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.borderSoft.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ),
      ),
    );
  }
}
