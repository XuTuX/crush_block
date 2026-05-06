import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import 'auth_service.dart';
import 'shop_service.dart';

enum MultiplayerMode { ranked, friendly }

extension MultiplayerModeX on MultiplayerMode {
  bool get isRanked => this == MultiplayerMode.ranked;
  bool get isFriendly => this == MultiplayerMode.friendly;
  String get titleKr => isRanked ? '랭킹전' : '친선전';
  String get roomCodePrefix => isRanked ? 'R' : 'F';
}

class MultiplayerService extends GetxService with WidgetsBindingObserver {
  static const String gameKey = 'crush_block';
  static const String defaultServerUrl = 'http://localhost:3001';

  final ShopService _shopService = Get.find<ShopService>();
  bool _availabilitySubscriptionActive = false;

  final isBusy = false.obs;
  final errorMessage = RxnString();
  final currentRoomId = RxnString();
  final currentRoomTitle = RxnString();
  final roomStatus = 'idle'.obs;
  final isMatchmakingActive = false.obs;
  final players = <Map<String, dynamic>>[].obs;
  final availableRooms = <Map<String, dynamic>>[].obs;
  final isFetchingRooms = false.obs;
  final currentMode = MultiplayerMode.friendly.obs;
  final gameSeed = RxnInt();

  final board = <List<String>>[].obs;
  final currentTurn = 'player1'.obs;
  final winner = RxnString();
  final winReason = RxnString();
  final walls = <Map<String, int>>[].obs;
  final lastMove = Rxn<Map<String, dynamic>>();

  socket_io.Socket? socket;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _initSocket();
  }

  void configureMode(MultiplayerMode mode) {
    currentMode.value = mode;
  }

  Future<void> quickMatch() async {
    final auth = Get.find<AuthService>();
    final userId = auth.user.value?.id;
    if (userId == null) {
      errorMessage.value = '로그인이 필요합니다.';
      return;
    }

    _ensureConnected();
    isBusy.value = true;
    isMatchmakingActive.value = true;
    errorMessage.value = null;
    socket?.emit('join_queue', {
      'userId': userId,
      'nickname': auth.userNickname.value ?? 'Player',
    });
    isBusy.value = false;
  }

  Future<void> createRoom({String? roomTitle}) async {
    final auth = Get.find<AuthService>();
    final userId = auth.user.value?.id;
    if (userId == null) {
      errorMessage.value = '로그인이 필요합니다.';
      return;
    }

    _ensureConnected();
    isBusy.value = true;
    errorMessage.value = null;
    socket?.emit('create_room', {
      'userId': userId,
      'nickname': auth.userNickname.value ?? 'Player',
      'roomTitle': roomTitle?.trim().isEmpty == true ? null : roomTitle?.trim(),
    });
    isBusy.value = false;
  }

  Future<void> joinRoomById(String roomId) async {
    final auth = Get.find<AuthService>();
    final userId = auth.user.value?.id;
    if (userId == null) {
      errorMessage.value = '로그인이 필요합니다.';
      return;
    }

    _ensureConnected();
    isBusy.value = true;
    errorMessage.value = null;
    socket?.emit('join_room', {
      'roomId': roomId,
      'userId': userId,
      'nickname': auth.userNickname.value ?? 'Player',
    });
    isBusy.value = false;
  }

  Future<void> toggleReady(bool ready) async {
    final roomId = currentRoomId.value;
    if (roomId == null) return;
    socket?.emit('set_ready', {'roomId': roomId, 'ready': ready});
  }

  Future<void> refreshRoomPlayers() async {
    final roomId = currentRoomId.value;
    final auth = Get.find<AuthService>();
    final userId = auth.user.value?.id;
    if (roomId == null || userId == null) return;
    socket?.emit('reconnect_room', {'roomId': roomId, 'userId': userId});
  }

  Future<void> fetchAvailableRooms() async {
    _ensureConnected();
    isFetchingRooms.value = true;
    socket?.emit('list_rooms');
    await Future<void>.delayed(const Duration(milliseconds: 250));
    isFetchingRooms.value = false;
  }

  void selectBlock(String blockType) {
    final roomId = currentRoomId.value;
    if (roomId == null) return;
    socket?.emit('select_block', {
      'roomId': roomId,
      'blockType': blockType,
    });
  }

  void placeBlock(int x, int y, int rotation) {
    final roomId = currentRoomId.value;
    if (roomId == null) return;
    socket?.emit('place_block', {
      'roomId': roomId,
      'x': x,
      'y': y,
      'rotation': rotation,
    });
  }

  Future<void> leaveRoom({bool countAsForfeit = false}) async {
    final roomId = currentRoomId.value;
    final auth = Get.find<AuthService>();
    final userId = auth.user.value?.id;
    if (roomId != null) {
      socket?.emit('leave_room', {
        'roomId': roomId,
        'userId': userId,
        'countAsForfeit': countAsForfeit,
      });
    }
    _clearRoomState();
  }

  void startAvailableRoomsSubscription() {
    _availabilitySubscriptionActive = true;
    unawaited(fetchAvailableRooms());
  }

  void stopAvailableRoomsSubscription() {
    _availabilitySubscriptionActive = false;
    if (currentRoomId.value == null && !isMatchmakingActive.value) {
      socket?.disconnect();
    }
  }

  void resetOnLogout() {
    leaveRoom();
  }

  Future<void> cancelMatchmaking() async {
    await leaveRoom();
    isMatchmakingActive.value = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_shouldKeepSocketWarm) {
        _ensureConnected();
        refreshRoomPlayers();
        fetchAvailableRooms();
      }
    }
  }

  @override
  void onClose() {
    socket?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  void _initSocket() {
    socket = socket_io.io(defaultServerUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'reconnection': true,
      'reconnectionAttempts': 20,
      'reconnectionDelay': 800,
    });

    socket?.onConnect((_) {
      debugPrint('Connected to Crush Block Socket.IO server');
      errorMessage.value = null;
      fetchAvailableRooms();
      refreshRoomPlayers();
    });

    socket?.onDisconnect((_) {
      debugPrint('Disconnected from Crush Block Socket.IO server');
    });

    socket?.on('game_error', (data) {
      _applyUiMutation(() {
        errorMessage.value =
            data is Map ? data['message']?.toString() : '게임 서버 오류가 발생했습니다.';
      });
    });

    socket?.on('available_rooms', (data) {
      _applyUiMutation(() {
        final raw = data is List ? data : const [];
        availableRooms.value = raw
            .whereType<Map>()
            .map((room) => Map<String, dynamic>.from(room))
            .toList();
        isFetchingRooms.value = false;
      });
    });

    socket?.on('room_state', (data) {
      if (data is! Map) return;
      _applyUiMutation(() => _applyRoomState(Map<String, dynamic>.from(data)));
    });
  }

  bool get _shouldKeepSocketWarm {
    return _availabilitySubscriptionActive ||
        currentRoomId.value != null ||
        isMatchmakingActive.value;
  }

  void _ensureConnected() {
    if (socket?.connected == true) return;
    socket?.connect();
  }

  void _applyRoomState(Map<String, dynamic> data) {
    currentRoomId.value = data['roomId']?.toString();
    currentRoomTitle.value = data['roomTitle']?.toString();
    roomStatus.value = data['status']?.toString() ?? 'idle';
    currentTurn.value = data['currentTurn']?.toString() ?? 'player1';
    winner.value = data['winner']?.toString();
    winReason.value = data['winReason']?.toString();
    isMatchmakingActive.value = false;

    final rawBoard = data['board'];
    if (rawBoard is List) {
      board.value = rawBoard
          .whereType<List>()
          .map((row) => row.map((cell) => cell.toString()).toList())
          .toList();
    }

    final rawWalls = data['walls'];
    if (rawWalls is List) {
      walls.value = rawWalls.whereType<Map>().map((wall) {
        return {
          'x': (wall['x'] as num).toInt(),
          'y': (wall['y'] as num).toInt(),
        };
      }).toList();
    }

    final rawLastMove = data['lastMove'];
    lastMove.value =
        rawLastMove is Map ? Map<String, dynamic>.from(rawLastMove) : null;

    final rawPlayers = data['players'];
    if (rawPlayers is List) {
      players.value = rawPlayers.whereType<Map>().map((player) {
        final map = Map<String, dynamic>.from(player);
        return {
          'user_id': map['userId'],
          'profiles': {'nickname': map['nickname']},
          'is_ready': map['ready'] == true,
          'role': map['role'],
          'selectedBlock': map['selectedBlock'],
          'connected': map['connected'] == true,
          'portrait_id': _shopService.defaultPortraitId,
        };
      }).toList();
    }
  }

  void _clearRoomState() {
    isMatchmakingActive.value = false;
    currentRoomId.value = null;
    currentRoomTitle.value = null;
    roomStatus.value = 'idle';
    currentTurn.value = 'player1';
    winner.value = null;
    winReason.value = null;
    lastMove.value = null;
    players.clear();
    board.clear();
    walls.clear();
    if (_availabilitySubscriptionActive) {
      unawaited(fetchAvailableRooms());
    } else {
      availableRooms.clear();
      isFetchingRooms.value = false;
    }
  }

  void _applyUiMutation(VoidCallback mutation) {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle) {
      mutation();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => mutation());
    }
  }
}
