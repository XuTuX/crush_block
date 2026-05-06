import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/multiplayer_game_controller.dart';

class MpTurnIndicator extends StatelessWidget {
  final MultiplayerGameController controller;

  const MpTurnIndicator({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() => Text(controller.isMyTurn.value ? '내 턴' : '상대 턴'));
  }
}
