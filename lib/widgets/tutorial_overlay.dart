import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crush_block/screens/tutorial_game_screen.dart';

void showTutorial(
  BuildContext context, {
  required VoidCallback onComplete,
  VoidCallback? onDismissed,
}) {
  Get.to(
    () => const TutorialGameScreen(),
    transition: Transition.rightToLeftWithFade,
    duration: const Duration(milliseconds: 500),
  )?.then((result) {
    if (result == true) {
      onComplete();
      return;
    }

    onDismissed?.call();
  });
}
