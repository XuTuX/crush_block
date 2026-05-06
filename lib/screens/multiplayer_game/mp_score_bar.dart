import 'package:flutter/material.dart';

import '../../controllers/multiplayer_game_controller.dart';

class MpScoreBar extends StatelessWidget {
  final MultiplayerGameController controller;
  final bool isMe;
  final String nickname;
  final String portraitId;

  const MpScoreBar({
    super.key,
    required this.controller,
    required this.isMe,
    required this.nickname,
    required this.portraitId,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(nickname),
      subtitle: Text(isMe ? '내 플레이어' : '상대 플레이어'),
    );
  }
}
