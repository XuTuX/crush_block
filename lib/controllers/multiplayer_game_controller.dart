import 'dart:async';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../constant.dart';
import '../services/multiplayer_service.dart';
import '../services/settings_service.dart';
import '../theme/app_design_system.dart';

class MultiplayerGameController extends GetxController {
  final MultiplayerService _service = Get.find<MultiplayerService>();

  final String roomId;
  final int? seed;
  final MultiplayerMode mode;
  final String myUserId;
  final String opponentUserId;
  final String myNickname;
  final String opponentNickname;

  final myBlockColor = AppColors.primary.obs;
  final opponentBlockColor = AppColors.tileCoral.obs;

  final isMyTurn = false.obs;
  final gameFinishedRx = false.obs;
  final iWon = Rx<bool?>(null);
  final opponentLeftMessage = RxnString();
  final hoverCells = <int>[].obs;
  final hoverColor = Rx<Color?>(null);
  final invalidCells = <int>[].obs;
  final lastPlacedCells = <int>[].obs;
  final lastClearedCells = <int>[].obs;
  final hasPendingPlacement = false.obs;

  Worker? _roomWorker;
  Worker? _turnWorker;
  Worker? _winnerWorker;
  Worker? _playersWorker;
  Worker? _lastMoveWorker;
  Timer? _lastPlacedTimer;
  Timer? _lastClearedTimer;
  Timer? _invalidPlacementTimer;
  int? _pendingStartCol;
  int? _pendingStartRow;
  int _pendingRotation = 0;

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

  String? get currentTurnSelectedBlock {
    return isMyTurn.value ? mySelectedBlock : opponentSelectedBlock;
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
    _lastMoveWorker = ever(_service.lastMove, (_) => _syncLastMoveEffects());
  }

  @override
  void onClose() {
    _roomWorker?.dispose();
    _turnWorker?.dispose();
    _winnerWorker?.dispose();
    _playersWorker?.dispose();
    _lastMoveWorker?.dispose();
    _lastPlacedTimer?.cancel();
    _lastClearedTimer?.cancel();
    _invalidPlacementTimer?.cancel();
    super.onClose();
  }

  void selectBlock(String blockType) {
    _service.selectBlock(blockType);
  }

  List<Offset> shapeFor(String blockType, int rotation) {
    final rotations = mpBlockShapesByType[blockType];
    if (rotations == null || rotations.isEmpty) return const [];
    final normalizedRotation =
        ((rotation % rotations.length) + rotations.length) % rotations.length;
    return rotations[normalizedRotation];
  }

  List<Offset> get selectedShape {
    final blockType = mySelectedBlock;
    if (blockType == null) return const [];
    return shapeFor(blockType, 0);
  }

  int visualColumnsFor(List<Offset> shape) {
    if (shape.isEmpty) return 3;
    final maxX = shape.map((offset) => offset.dx.toInt()).reduce((a, b) {
      return a > b ? a : b;
    });
    return maxX + 1 > 3 ? maxX + 1 : 3;
  }

  int visualRowsFor(List<Offset> shape) {
    if (shape.isEmpty) return 3;
    final maxY = shape.map((offset) => offset.dy.toInt()).reduce((a, b) {
      return a > b ? a : b;
    });
    return maxY + 1 > 3 ? maxY + 1 : 3;
  }

  Color get myPlacementColor => myBlockColor.value;

  Color get currentTurnBlockColor {
    return isMyTurn.value ? myBlockColor.value : opponentBlockColor.value;
  }

  bool canPlaceShapeAtStart(List<Offset> shape, int startRow, int startCol) {
    final board = _service.board;
    if (board.length != gridRows || shape.isEmpty) return false;

    for (final offset in shape) {
      final row = startRow + offset.dy.toInt();
      final col = startCol + offset.dx.toInt();
      if (row < 0 || row >= gridRows || col < 0 || col >= gridColumns) {
        return false;
      }
      if (board[row][col] != 'empty') {
        return false;
      }
    }
    return true;
  }

  void updateHover(
    int centerRow,
    int centerCol,
    List<Offset> shape,
    Color color, {
    int originRow = 1,
    int originCol = 1,
    int rotation = 0,
    bool stagePlacement = false,
  }) {
    if (!isMyTurn.value || gameFinishedRx.value) {
      if (stagePlacement) {
        clearPendingPlacement();
      } else {
        clearHover();
      }
      return;
    }

    final startRow = centerRow - originRow;
    final startCol = centerCol - originCol;
    if (!canPlaceShapeAtStart(shape, startRow, startCol)) {
      if (stagePlacement) {
        clearPendingPlacement();
      } else {
        clearHover();
      }
      return;
    }

    final nextCells = _cellIndexesForShape(shape, startRow, startCol);

    if (stagePlacement) {
      _pendingStartCol = startCol;
      _pendingStartRow = startRow;
      _pendingRotation = rotation;
      hasPendingPlacement.value = true;
    }

    if (_sameCells(hoverCells, nextCells) && hoverColor.value == color) {
      return;
    }

    hoverCells.assignAll(nextCells);
    hoverColor.value = color;
  }

  void clearHover() {
    if (hoverCells.isNotEmpty) hoverCells.clear();
    if (hoverColor.value != null) hoverColor.value = null;
  }

  void showInvalidPlacement(
    int centerRow,
    int centerCol,
    List<Offset> shape, {
    int originRow = 1,
    int originCol = 1,
  }) {
    final startRow = centerRow - originRow;
    final startCol = centerCol - originCol;
    final nextCells = shape
        .map((offset) {
          final row = startRow + offset.dy.toInt();
          final col = startCol + offset.dx.toInt();
          if (row < 0 || row >= gridRows || col < 0 || col >= gridColumns) {
            return null;
          }
          return row * gridColumns + col;
        })
        .whereType<int>()
        .toList();

    invalidCells.assignAll(
      nextCells.isEmpty ? [centerRow * gridColumns + centerCol] : nextCells,
    );
    _invalidPlacementTimer?.cancel();
    _invalidPlacementTimer = Timer(const Duration(milliseconds: 360), () {
      invalidCells.clear();
    });
  }

  void clearPendingPlacement() {
    _pendingStartCol = null;
    _pendingStartRow = null;
    hasPendingPlacement.value = false;
    clearHover();
  }

  bool isPendingCell(int index) {
    return hasPendingPlacement.value && hoverCells.contains(index);
  }

  bool stageSelectedBlockAtCenter(
    int centerRow,
    int centerCol,
    int rotation, {
    int originRow = 1,
    int originCol = 1,
  }) {
    final blockType = mySelectedBlock;
    if (blockType == null || !isMyTurn.value || gameFinishedRx.value) {
      clearPendingPlacement();
      return false;
    }

    final shape = shapeFor(blockType, rotation);
    final startRow = centerRow - originRow;
    final startCol = centerCol - originCol;
    if (!canPlaceShapeAtStart(shape, startRow, startCol)) {
      clearPendingPlacement();
      return false;
    }

    _pendingStartCol = startCol;
    _pendingStartRow = startRow;
    _pendingRotation = rotation;
    hasPendingPlacement.value = true;

    final nextCells = _cellIndexesForShape(shape, startRow, startCol);
    hoverCells.assignAll(nextCells);
    hoverColor.value = myPlacementColor;
    _playSelectionHaptic();
    return true;
  }

  bool confirmPendingPlacement() {
    final startCol = _pendingStartCol;
    final startRow = _pendingStartRow;
    final blockType = mySelectedBlock;
    if (startCol == null ||
        startRow == null ||
        blockType == null ||
        !isMyTurn.value ||
        gameFinishedRx.value) {
      clearPendingPlacement();
      return false;
    }

    final shape = shapeFor(blockType, _pendingRotation);
    if (!canPlaceShapeAtStart(shape, startRow, startCol)) {
      clearPendingPlacement();
      return false;
    }

    _playSelectionHaptic();
    clearPendingPlacement();
    _service.placeBlock(startCol, startRow, _pendingRotation);
    return true;
  }

  bool placeSelectedBlockAtCenter(
    int centerRow,
    int centerCol,
    int rotation, {
    int originRow = 1,
    int originCol = 1,
  }) {
    final blockType = mySelectedBlock;
    if (blockType == null || !isMyTurn.value || gameFinishedRx.value) {
      clearHover();
      return false;
    }

    final shape = shapeFor(blockType, rotation);
    final startRow = centerRow - originRow;
    final startCol = centerCol - originCol;
    final canPlace = canPlaceShapeAtStart(shape, startRow, startCol);
    clearHover();
    if (!canPlace) return false;

    _playSelectionHaptic();
    placeBlock(startCol, startRow, rotation);
    return true;
  }

  void placeBlock(int x, int y, int rotation) {
    final blockType = mySelectedBlock;
    if (blockType != null &&
        !canPlaceShapeAtStart(shapeFor(blockType, rotation), y, x)) {
      clearHover();
      return;
    }
    clearHover();
    _service.placeBlock(x, y, rotation);
  }

  Map<String, dynamic>? _myPlayer() {
    for (final player in _service.players) {
      if (player['is_me'] == true) return player;
    }
    for (final player in _service.players) {
      if (player['user_id'] == myUserId) return player;
    }
    return null;
  }

  Map<String, dynamic>? _opponentPlayer() {
    for (final player in _service.players) {
      if (player['is_me'] != true) return player;
    }
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
    if (!isMyTurn.value || gameFinishedRx.value) {
      clearPendingPlacement();
    }

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

  bool _sameCells(List<int> current, List<int> next) {
    if (current.length != next.length) return false;
    for (var i = 0; i < current.length; i += 1) {
      if (current[i] != next[i]) return false;
    }
    return true;
  }

  List<int> _cellIndexesForShape(
      List<Offset> shape, int startRow, int startCol) {
    return shape.map((offset) {
      final row = startRow + offset.dy.toInt();
      final col = startCol + offset.dx.toInt();
      return row * gridColumns + col;
    }).toList(growable: false);
  }

  void _syncLastMoveEffects() {
    final move = _service.lastMove.value;
    if (move == null) return;

    final placed = _extractMoveCellIndexes(move['placedCells']);
    if (placed.isNotEmpty) {
      lastPlacedCells.assignAll(placed);
      _lastPlacedTimer?.cancel();
      _lastPlacedTimer = Timer(const Duration(milliseconds: 300), () {
        lastPlacedCells.clear();
      });
    }

    final cleared = _extractMoveCellIndexes(move['clearedCells']);
    if (cleared.isNotEmpty) {
      lastClearedCells.assignAll(cleared);
      _lastClearedTimer?.cancel();
      _lastClearedTimer = Timer(const Duration(milliseconds: 800), () {
        lastClearedCells.clear();
      });
      _playMediumHaptic();
    }
  }

  List<int> _extractMoveCellIndexes(dynamic rawCells) {
    if (rawCells is! List) return const [];
    return rawCells
        .whereType<Map>()
        .map((cell) {
          final x = (cell['x'] as num?)?.toInt();
          final y = (cell['y'] as num?)?.toInt();
          if (x == null || y == null) return null;
          return y * gridColumns + x;
        })
        .whereType<int>()
        .toList(growable: false);
  }

  void _playSelectionHaptic() {
    if (_isHapticsOn) HapticFeedback.selectionClick();
  }

  void _playMediumHaptic() {
    if (_isHapticsOn) HapticFeedback.mediumImpact();
  }

  bool get _isHapticsOn {
    if (!Get.isRegistered<SettingsService>()) return true;
    return Get.find<SettingsService>().isHapticsOn.value;
  }
}
