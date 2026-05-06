import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/multiplayer_service.dart';

class MultiplayerGameController extends GetxController {
  final MultiplayerService _service = Get.find<MultiplayerService>();

  final String roomId;
  final int? seed;
  final MultiplayerMode mode;
  final String myUserId;
  final String opponentUserId;
  final String myNickname;
  final String opponentNickname;

  final myPortraitId = ''.obs;
  final opponentPortraitId = ''.obs;
  final myCharacterId = ''.obs;
  final opponentCharacterId = ''.obs;
  final myBlockColor = const Color(0xFFFF7043).obs;
  final opponentBlockColor = const Color(0xFF42A5F5).obs;

  final isMyTurn = false.obs;
  final gameFinishedRx = false.obs;
  final iWon = Rx<bool?>(null);
  final opponentLeftMessage = RxnString();
  final winnerUserId = RxnString();

  bool forfeitHandled = false;
  Worker? _roomWorker;
  Worker? _turnWorker;
  Worker? _winnerWorker;
  Worker? _playersWorker;

  MultiplayerGameController({
    required this.roomId,
    this.seed,
    this.mode = MultiplayerMode.friendly,
    required this.myUserId,
    required this.opponentUserId,
    required this.myNickname,
    required this.opponentNickname,
  });

  bool get gameFinished => _service.roomStatus.value == 'finished';

  String? get mySelectedBlock {
    final me = _myPlayer();
    return me == null ? null : me['selectedBlock']?.toString();
  }

  String? get opponentSelectedBlock {
    final opponent = _opponentPlayer();
    return opponent == null ? null : opponent['selectedBlock']?.toString();
  }

  String? get myRole => _myPlayer()?['role']?.toString();

  String? get opponentRole => _opponentPlayer()?['role']?.toString();

  @override
  void onInit() {
    super.onInit();
    _syncDerivedState();
    _roomWorker = ever(_service.roomStatus, (_) => _syncDerivedState());
    _turnWorker = ever(_service.currentTurn, (_) => _syncDerivedState());
    _winnerWorker = ever(_service.winner, (_) => _syncDerivedState());
    _playersWorker = ever(_service.players, (_) => _syncDerivedState());
  }

  @override
  void onClose() {
    _roomWorker?.dispose();
    _turnWorker?.dispose();
    _winnerWorker?.dispose();
    _playersWorker?.dispose();
    super.onClose();
  }

  void selectBlock(String blockType) {
    _service.selectBlock(blockType);
  }

  void placeBlock(int x, int y, int rotation) {
    _service.placeBlock(x, y, rotation);
  }

  Map<String, dynamic>? _myPlayer() {
    for (final player in _service.players) {
      if (player['user_id'] == myUserId) return player;
    }
    return null;
  }

  Map<String, dynamic>? _opponentPlayer() {
    for (final player in _service.players) {
      if (player['user_id'] != myUserId) return player;
    }
    return null;
  }

  void _syncDerivedState() {
    final me = _myPlayer();
    final myRole = me?['role']?.toString();
    isMyTurn.value = myRole != null && myRole == _service.currentTurn.value;
    gameFinishedRx.value = _service.roomStatus.value == 'finished';

    if (!gameFinishedRx.value ||
        myRole == null ||
        _service.winner.value == null) {
      iWon.value = null;
    } else {
      iWon.value = myRole == _service.winner.value;
    }

    if (_service.winReason.value == 'forfeit') {
      final opponent = _opponentPlayer();
      if (opponent != null && opponent['connected'] == false) {
        opponentLeftMessage.value = '상대가 게임을 떠났습니다.';
      }
    }
  }
}
