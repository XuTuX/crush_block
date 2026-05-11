import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../config/app_config.dart';
import '../constant.dart';
import 'auth_service.dart';

enum MultiplayerMode { ranked, friendly }

extension MultiplayerModeX on MultiplayerMode {
  bool get isRanked => this == MultiplayerMode.ranked;
  bool get isFriendly => this == MultiplayerMode.friendly;
  String get titleKr => isRanked ? '랭킹전' : '친선전';
  String get roomCodePrefix => isRanked ? 'R' : 'F';
}

class MultiplayerService extends GetxService with WidgetsBindingObserver {
  static const String gameKey = 'crush_block';
  static String get defaultServerUrl => AppConfig.gameServerUrl;
  static const Duration _connectionTimeout = Duration(seconds: 5);

  final String _clientId =
      'client_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 32)}';
  bool _availabilitySubscriptionActive = false;
  Map<String, dynamic>? _pendingQuickMatchPayload;
  Timer? _connectionTimeoutTimer;

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
  final turnExpiresAtMs = RxnInt();
  final turnDurationMs = 15000.obs;
  final serverTimeOffsetMs = 0.obs;
  final winner = RxnString();
  final winReason = RxnString();
  final walls = <Map<String, int>>[].obs;
  final lastMove = Rxn<Map<String, dynamic>>();

  bool isDebugMode = false;

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

    isBusy.value = true;
    isMatchmakingActive.value = true;
    errorMessage.value = null;
    _pendingQuickMatchPayload = {
      'userId': userId,
      'clientId': _clientId,
      'nickname': auth.userNickname.value ?? 'Player',
    };
    _ensureConnected();
    _sendPendingQuickMatch();
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
      'clientId': _clientId,
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
      'clientId': _clientId,
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
    socket?.emit('reconnect_room', {
      'roomId': roomId,
      'userId': userId,
      'clientId': _clientId,
    });
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
    
    if (isDebugMode) {
      final me = players.firstWhereOrNull((p) => p['is_me'] == true);
      if (me != null) {
        me['selectedBlock'] = blockType;
        players.refresh();
      }
      return;
    }
    
    socket?.emit('select_block', {
      'roomId': roomId,
      'blockType': blockType,
    });
  }

  void placeBlock(int x, int y, int rotation) {
    final roomId = currentRoomId.value;
    if (roomId == null) return;
    
    if (isDebugMode) {
      // Mock placing a block for debug UI testing
      final me = players.firstWhereOrNull((p) => p['is_me'] == true);
      final role = me?['role']?.toString();
      final blockType = me?['selectedBlock']?.toString();
      
      if (me != null && role != null && blockType != null) {
        // Just a dummy simulation: set a few cells and clear selection
        final newBoard = List<List<String>>.from(board.map((row) => List<String>.from(row)));
        final placed = <Map<String, int>>[];
        
        // Very rough block filling just to trigger animations
        for (int dy = 0; dy < 2; dy++) {
          for (int dx = 0; dx < 2; dx++) {
             int cy = y + dy;
             int cx = x + dx;
             if (cy >= 0 && cy < gridRows && cx >= 0 && cx < gridColumns) {
               newBoard[cy][cx] = role;
               placed.add({'x': cx, 'y': cy});
             }
          }
        }
        
        board.value = newBoard;
        me['selectedBlock'] = null;
        lastMove.value = {
          'placedCells': placed,
          'clearedCells': [], // No mock clears to keep it simple
        };
        currentTurn.value = 'player2'; // switch turn to freeze
        players.refresh();
      }
      return;
    }
    
    socket?.emit('place_block', {
      'roomId': roomId,
      'x': x,
      'y': y,
      'rotation': rotation,
    });
  }

  Future<void> leaveRoom({bool countAsForfeit = false}) async {
    isDebugMode = false;
    final roomId = currentRoomId.value;
    final auth = Get.find<AuthService>();
    final userId = auth.user.value?.id;
    if (roomId != null) {
      socket?.emit('leave_room', {
        'roomId': roomId,
        'userId': userId,
        'clientId': _clientId,
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
    _pendingQuickMatchPayload = null;
    _connectionTimeoutTimer?.cancel();
    final userId = Get.find<AuthService>().user.value?.id;
    if (userId != null) {
      socket?.emit('cancel_queue', {'userId': userId, 'clientId': _clientId});
    }
    await leaveRoom();
    isMatchmakingActive.value = false;
    isBusy.value = false;
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
    _connectionTimeoutTimer?.cancel();
    socket?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  void _initSocket() {
    final serverUrl = defaultServerUrl;
    socket = socket_io.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'reconnection': true,
      'reconnectionAttempts': 20,
      'reconnectionDelay': 800,
    });

    socket?.onConnect((_) {
      debugPrint('Connected to Crush Block Socket.IO server: $serverUrl');
      _connectionTimeoutTimer?.cancel();
      errorMessage.value = null;
      _sendPendingQuickMatch();
      fetchAvailableRooms();
      refreshRoomPlayers();
    });

    socket?.onDisconnect((_) {
      debugPrint('Disconnected from Crush Block Socket.IO server');
    });

    socket?.onConnectError(_handleConnectionFailure);
    socket?.onError(_handleConnectionFailure);
    socket?.onReconnectFailed(_handleConnectionFailure);

    socket?.on('game_error', (data) {
      _applyUiMutation(() {
        errorMessage.value =
            data is Map ? data['message']?.toString() : '게임 서버 오류가 발생했습니다.';
        isBusy.value = false;
      });
    });

    socket?.on('queue_state', (data) {
      _applyUiMutation(() {
        final waiting = data is Map && data['waiting'] == true;
        isMatchmakingActive.value = waiting;
        isBusy.value = false;
        if (waiting) {
          errorMessage.value = null;
        }
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

  void _sendPendingQuickMatch() {
    final payload = _pendingQuickMatchPayload;
    if (payload == null) return;

    if (socket?.connected != true) {
      _scheduleConnectionTimeout();
      return;
    }

    debugPrint('Sending quick match queue request to $defaultServerUrl');
    socket?.emit('join_queue', payload);
    _pendingQuickMatchPayload = null;
    _connectionTimeoutTimer?.cancel();
  }

  void _scheduleConnectionTimeout() {
    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = Timer(_connectionTimeout, () {
      if (socket?.connected == true || _pendingQuickMatchPayload == null) {
        return;
      }
      _pendingQuickMatchPayload = null;
      _applyUiMutation(() {
        isBusy.value = false;
        isMatchmakingActive.value = false;
        errorMessage.value = _serverUnavailableMessage;
      });
    });
  }

  void _handleConnectionFailure(dynamic error) {
    debugPrint('Crush Block Socket.IO connection failed: $error');
    if (!_shouldKeepSocketWarm && _pendingQuickMatchPayload == null) return;

    _pendingQuickMatchPayload = null;
    _connectionTimeoutTimer?.cancel();
    _applyUiMutation(() {
      isBusy.value = false;
      isFetchingRooms.value = false;
      if (currentRoomId.value == null) {
        isMatchmakingActive.value = false;
      }
      errorMessage.value = _serverUnavailableMessage;
    });
  }

  String get _serverUnavailableMessage =>
      '게임 서버에 연결할 수 없습니다. game_server 폴더에서 npm install 후 npm start 또는 npm run dev를 실행해주세요.';

  void _applyRoomState(Map<String, dynamic> data) {
    currentRoomId.value = data['roomId']?.toString();
    currentRoomTitle.value = data['roomTitle']?.toString();
    roomStatus.value = data['status']?.toString() ?? 'idle';
    currentTurn.value = data['currentTurn']?.toString() ?? 'player1';
    final rawTurnExpiresAt = data['turnExpiresAt'];
    turnExpiresAtMs.value =
        rawTurnExpiresAt is num ? rawTurnExpiresAt.toInt() : null;
    final rawTurnDuration = data['turnDurationMs'];
    turnDurationMs.value =
        rawTurnDuration is num ? rawTurnDuration.toInt() : 15000;
    final rawServerNow = data['serverNow'];
    if (rawServerNow is num) {
      serverTimeOffsetMs.value =
          rawServerNow.toInt() - DateTime.now().millisecondsSinceEpoch;
    }
    winner.value = data['winner']?.toString();
    winReason.value = data['winReason']?.toString();
    final rawGameSeed = data['gameSeed'];
    gameSeed.value = rawGameSeed is num ? rawGameSeed.toInt() : null;
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
        final localSocketId = socket?.id;
        final remoteClientId = map['clientId']?.toString();
        final isMe = remoteClientId != null && remoteClientId.isNotEmpty
            ? remoteClientId == _clientId
            : localSocketId != null && map['socketId'] == localSocketId;
        return {
          'user_id': map['userId'],
          'socket_id': map['socketId'],
          'client_id': remoteClientId,
          'is_me': isMe,
          'profiles': {'nickname': map['nickname']},
          'is_ready': map['ready'] == true,
          'role': map['role'],
          'selectedBlock': map['selectedBlock'],
          'connected': map['connected'] == true,
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
    turnExpiresAtMs.value = null;
    turnDurationMs.value = 15000;
    serverTimeOffsetMs.value = 0;
    gameSeed.value = null;
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

  void startDebugOfflineGame() {
    isDebugMode = true;
    final auth = Get.find<AuthService>();
    final userId = auth.user.value?.id ?? 'debug_user_1';
    final nickname = auth.userNickname.value ?? 'Debug Player';

    _clearRoomState();
    
    currentRoomId.value = 'debug_room';
    currentRoomTitle.value = 'UI Debug Game';
    roomStatus.value = 'selecting'; // Start in selection phase
    currentTurn.value = 'player1';
    turnDurationMs.value = 60000;
    turnExpiresAtMs.value = DateTime.now().millisecondsSinceEpoch + 60000;
    
    final emptyBoard = List.generate(
      gridRows, 
      (_) => List.generate(gridColumns, (_) => 'empty')
    );
    board.value = emptyBoard;

    players.value = [
      {
        'user_id': userId,
        'client_id': _clientId,
        'is_me': true,
        'profiles': {'nickname': nickname},
        'is_ready': true,
        'role': 'player1',
        'selectedBlock': null,
        'connected': true,
      },
      {
        'user_id': 'debug_user_2',
        'client_id': 'dummy_client_2',
        'is_me': false,
        'profiles': {'nickname': 'Mock Opponent'},
        'is_ready': true,
        'role': 'player2',
        'selectedBlock': 'T',
        'connected': true,
      }
    ];
  }
}
