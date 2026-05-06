import 'dart:async';
import 'dart:io';

import 'package:link_your_area/config/app_config.dart';
import 'package:link_your_area/services/multiplayer_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:link_your_area/models/character_item.dart';
import 'package:link_your_area/models/portrait_item.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ShopIconItem {
  final String id;
  final String name;
  final IconData icon;
  final int price;

  const ShopIconItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.price,
  });
}

/// 블록 색상 아이템
class ShopBlockColorItem {
  final String id;
  final String name;
  final String description;
  final int price;
  final Color color;

  const ShopBlockColorItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.color,
  });
}

/// 블록 무늬 아이템 — 나중에 실제 렌더링 확장 예정
class ShopPatternItem {
  final String id;
  final String name;
  final int price;
  final IconData icon;
  final bool comingSoon;

  const ShopPatternItem({
    required this.id,
    required this.name,
    required this.price,
    required this.icon,
    this.comingSoon = false,
  });
}

class ShopCoinPackage {
  final String id;
  final String name;
  final int estimatedPriceKrw;
  final int coinAmount;
  final String badge;

  const ShopCoinPackage({
    required this.id,
    required this.name,
    required this.estimatedPriceKrw,
    required this.coinAmount,
    required this.badge,
  });
}

class ShopService extends GetxService {
  final RxInt coins = 0.obs;
  final RxString equippedIconId = 'default_face'.obs;
  final RxString equippedBlockSkinId = 'blue'.obs;
  final RxString equippedSecondaryBlockSkinId = 'red'.obs;
  final RxString equippedPatternId = 'solid'.obs; // 무늬 (현재는 기본만)
  final RxString equippedCharacterId = ''.obs;
  final RxString equippedPortraitId = 'slime_face'.obs;
  final RxList<String> ownedCharacterIds = <String>[].obs;
  final RxList<String> ownedPortraitIds = <String>['slime_face'].obs;
  final RxList<String> ownedIconIds = <String>[].obs;
  final RxList<String> ownedBlockSkinIds = <String>[].obs;
  final RxBool isStoreBillingAvailable = false.obs;
  final RxBool isStoreBillingLoading = true.obs;
  final RxBool isStorePurchasePending = false.obs;
  final RxnString storeBillingMessage = RxnString();
  final RxList<ProductDetails> storeProducts = <ProductDetails>[].obs;

  late SharedPreferences _prefs;
  final SupabaseClient _supabase = Supabase.instance.client;
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  static const String _gameKey = 'crush_block';
  static const String _tableName = 'user_shop_data';
  static const String _getStateRpc = 'shop_get_state';
  static const String _purchaseIconRpc = 'shop_purchase_icon';
  static const String _purchaseCharacterRpc = 'shop_purchase_character';
  static const String _purchasePortraitRpc = 'shop_purchase_portrait';
  static const String _purchaseBlockSkinRpc = 'shop_purchase_block_skin';
  static const String _equipIconRpc = 'shop_equip_icon';
  static const String _equipCharacterRpc = 'shop_equip_character';
  static const String _equipPortraitRpc = 'shop_equip_portrait';
  static const String _equipBlockSkinRpc = 'shop_equip_block_skin';
  static const String _equipBlockSkinSlotRpc = 'shop_equip_block_skin_slot';

  static const int _starterCoins = 140;
  static const String _coinsKey = 'shop_coins';
  static const String _equippedIconKey = 'shop_equipped_icon';
  static const String _equippedBlockKey = 'shop_equipped_block';
  static const String _equippedSecondaryBlockKey =
      'shop_equipped_block_secondary';
  static const String _ownedIconsKey = 'shop_owned_icons';
  static const String _ownedBlocksKey = 'shop_owned_blocks';
  static const String _equippedCharacterKey = 'shop_equipped_character';
  static const String _ownedCharactersKey = 'shop_owned_characters';
  static const String _equippedPortraitKey = 'shop_equipped_portrait';
  static const String _ownedPortraitsKey = 'shop_owned_portraits';

  static const List<CharacterItem> characterCatalog = [
    CharacterItem(
      id: 'rocket_token',
      name: '로켓 토큰',
      rarity: CharacterRarity.common,
      price: 0,
      themeColor: Color(0xFFE85D75),
      portraitAsset: 'assets/tokens/rocket_token.png',
      tokenAsset: 'assets/tokens/rocket_token.png',
    ),
    CharacterItem(
      id: 'key_token',
      name: '열쇠 토큰',
      rarity: CharacterRarity.rare,
      price: 450,
      themeColor: Color(0xFF3D7FD1),
      portraitAsset: 'assets/tokens/key_token.png',
      tokenAsset: 'assets/tokens/key_token.png',
    ),
    CharacterItem(
      id: 'star_token',
      name: '별 토큰',
      rarity: CharacterRarity.epic,
      price: 550,
      themeColor: Color(0xFFF4C542),
      portraitAsset: 'assets/tokens/star_token.png',
      tokenAsset: 'assets/tokens/star_token.png',
    ),
  ];

  static const List<PortraitItem> portraitCatalog = [
    PortraitItem(
      id: 'slime_face',
      characterId: 'rocket_token',
      name: '슬라임',
      price: 0,
      assetPath: 'assets/portraits/slime.png',
    ),
    PortraitItem(
      id: 'knight_slime_face',
      characterId: 'key_token',
      name: '기사 슬라임',
      price: 500,
      assetPath: 'assets/portraits/Knight_Slime.png',
    ),
    PortraitItem(
      id: 'wizard_slime_face',
      characterId: 'star_token',
      name: '마법사 슬라임',
      price: 500,
      assetPath: 'assets/portraits/Wizard_Slime.png',
    ),
    PortraitItem(
      id: 'angel_slime_face',
      characterId: 'rocket_token',
      name: '천사 슬라임',
      price: 300,
      assetPath: 'assets/portraits/Angel_Slime.png',
    ),
    PortraitItem(
      id: 'demon_slime_face',
      characterId: 'key_token',
      name: '악마 슬라임',
      price: 500,
      assetPath: 'assets/portraits/Demon_Slime.png',
    ),
  ];

  static const List<ShopIconItem> iconCatalog = [
    ShopIconItem(
      id: 'default_face',
      name: '기본 미소',
      icon: Icons.sentiment_satisfied_rounded,
      price: 0,
    ),
    ShopIconItem(
      id: 'rocket',
      name: '로켓',
      icon: Icons.rocket_launch_rounded,
      price: 35,
    ),
    ShopIconItem(
      id: 'bolt',
      name: '번개',
      icon: Icons.flash_on_rounded,
      price: 45,
    ),
    ShopIconItem(
      id: 'diamond',
      name: '다이아',
      icon: Icons.diamond_rounded,
      price: 60,
    ),
    ShopIconItem(
      id: 'military',
      name: '장군',
      icon: Icons.military_tech_rounded,
      price: 80,
    ),
  ];

  /// 색상 카탈로그 — 기본 빨강/파랑 + 구매 가능한 확장 색상
  static const List<ShopBlockColorItem> blockColorCatalog = [
    ShopBlockColorItem(
      id: 'red',
      name: '바이올렛',
      description: '기본 제공',
      price: 0,
      color: Color(0xFF8B5CF6),
    ),
    ShopBlockColorItem(
      id: 'blue',
      name: '인디고',
      description: '기본 제공',
      price: 0,
      color: Color(0xFF6366F1),
    ),
    ShopBlockColorItem(
      id: 'green',
      name: '초록',
      description: '싱그러운 그린',
      price: 500,
      color: Color(0xFF2FB26E),
    ),
    ShopBlockColorItem(
      id: 'yellow',
      name: '노랑',
      description: '브라이트 골드',
      price: 500,
      color: Color(0xFFF4C542),
    ),
    ShopBlockColorItem(
      id: 'purple',
      name: '보라',
      description: '네온 바이올렛',
      price: 500,
      color: Color(0xFF8B5CF6),
    ),
    ShopBlockColorItem(
      id: 'orange',
      name: '주황',
      description: '선셋 오렌지',
      price: 500,
      color: Color(0xFFFF8A3D),
    ),
    ShopBlockColorItem(
      id: 'teal',
      name: '청록',
      description: '딥 민트',
      price: 500,
      color: Color(0xFF14B8A6),
    ),
    ShopBlockColorItem(
      id: 'pink',
      name: '핑크',
      description: '캔디 핑크',
      price: 500,
      color: Color(0xFFFF5FA2),
    ),
  ];

  /// 무늬 카탈로그 — 기본 1개, 나머지는 추후 출시
  static const List<ShopPatternItem> patternCatalog = [
    ShopPatternItem(
      id: 'solid',
      name: '기본',
      price: 0,
      icon: Icons.square_rounded,
    ),
    ShopPatternItem(
      id: 'dots',
      name: '도트',
      price: 65,
      icon: Icons.blur_on_rounded,
      comingSoon: true,
    ),
    ShopPatternItem(
      id: 'stripes',
      name: '스트라이프',
      price: 85,
      icon: Icons.view_week_rounded,
      comingSoon: true,
    ),
    ShopPatternItem(
      id: 'checker',
      name: '체커',
      price: 110,
      icon: Icons.grid_4x4_rounded,
      comingSoon: true,
    ),
  ];

  static const List<ShopCoinPackage> coinPackageCatalog = [
    ShopCoinPackage(
      id: '500_coin',
      name: '코인 500개',
      estimatedPriceKrw: 3000,
      coinAmount: 500,
      badge: '기본 팩',
    ),
    ShopCoinPackage(
      id: '1200_coin',
      name: '코인 1,200개',
      estimatedPriceKrw: 5000,
      coinAmount: 1200,
      badge: '베스트',
    ),
    ShopCoinPackage(
      id: '2500_coin',
      name: '코인 2,500개',
      estimatedPriceKrw: 9900,
      coinAmount: 2500,
      badge: '보너스',
    ),
  ];

  static const Map<String, String> _legacyBlockSkinIdMap = {
    'starter': 'red',
    'peach_soda': 'red',
    'warm': 'red',
    'red': 'red',
    'mint_navy': 'blue',
    'sunset_gold': 'blue',
    'cool': 'blue',
    'blue': 'blue',
    'green': 'green',
    'yellow': 'yellow',
    'purple': 'purple',
    'orange': 'orange',
    'teal': 'teal',
    'pink': 'pink',
  };

  Future<ShopService> init() async {
    _prefs = await SharedPreferences.getInstance();
    await loadForCurrentUser();
    await _initStoreBilling();
    return this;
  }

  @override
  void onClose() {
    _purchaseSubscription?.cancel();
    super.onClose();
  }

  String? get _userId => _supabase.auth.currentUser?.id;
  String get _suffix => _userId ?? 'guest';
  bool get _isLoggedIn => _userId != null;
  bool get canPurchase => _isLoggedIn;
  bool get supportsStoreBilling =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);
  String get storeBillingLabel => Platform.isIOS
      ? 'App Store'
      : (Platform.isAndroid ? 'Google Play' : '스토어');
  String get defaultCharacterId => '';
  String get defaultPortraitId => portraitCatalog.first.id;

  /// 현재 장착된 블록 색상 반환
  Color get equippedBlockColor => selectedBlockColor.color;
  Color get secondaryEquippedBlockColor => selectedSecondaryBlockColor.color;
  List<String> get equippedBlockSkinIds => [
        equippedBlockSkinId.value,
        equippedSecondaryBlockSkinId.value,
      ];
  List<String> get selectedCustomBlockColorIds => equippedBlockSkinIds
      .where((id) => (_findBlockColorById(id)?.price ?? 0) > 0)
      .toList(growable: false);

  ShopIconItem get selectedIcon => iconCatalog.firstWhere(
        (item) => item.id == equippedIconId.value,
        orElse: () => iconCatalog.first,
      );

  CharacterItem get selectedCharacter =>
      characterItemForId(equippedCharacterId.value) ?? characterCatalog.first;

  PortraitItem get selectedPortrait =>
      portraitItemForId(
        equippedPortraitId.value,
      ) ??
      portraitCatalog.first;

  ShopIconItem iconItemForId(String? id) => iconCatalog.firstWhere(
        (item) => item.id == id,
        orElse: () => iconCatalog.first,
      );

  CharacterItem? characterItemForId(String? id) =>
      characterCatalog.where((item) => item.id == id).firstOrNull;

  PortraitItem? portraitItemForId(String? id) =>
      portraitCatalog.where((item) => item.id == id).firstOrNull;

  String portraitAssetForId(String? id) =>
      portraitItemForId(id)?.assetPath ?? portraitCatalog.first.assetPath;

  /// 현재 장착된 블록 색상 아이템
  ShopBlockColorItem get selectedBlockColor => blockColorCatalog.firstWhere(
        (item) => item.id == equippedBlockSkinId.value,
        orElse: () => blockColorCatalog.first,
      );

  ShopBlockColorItem get selectedSecondaryBlockColor =>
      blockColorCatalog.firstWhere(
        (item) => item.id == equippedSecondaryBlockSkinId.value,
        orElse: () => blockColorCatalog[1],
      );

  /// 현재 장착된 무늬 아이템
  ShopPatternItem get selectedPattern => patternCatalog.firstWhere(
        (item) => item.id == equippedPatternId.value,
        orElse: () => patternCatalog.first,
      );

  ShopCoinPackage? coinPackageForId(String id) =>
      coinPackageCatalog.where((item) => item.id == id).firstOrNull;

  ProductDetails? storeProductForId(String id) =>
      storeProducts.where((product) => product.id == id).firstOrNull;

  // ─── 로드 ───────────────────────────────────────────────

  Future<void> loadForCurrentUser() async {
    final defaultIconId = iconCatalog.first.id;
    final defaultBlockId = blockColorCatalog.first.id;
    const defaultCharacterId = '';
    final defaultPortraitId = portraitCatalog.first.id;
    final defaultOwnedBlockIds = _normalizeOwnedBlockSkinIds(
      const <String>[],
    );

    if (_isLoggedIn) {
      final loaded = await _loadFromSupabase();
      if (loaded) {
        await _persistLocal();
        return;
      }
      debugPrint(
        '🟡 [ShopService] Falling back to local cache after Supabase load failure',
      );
    }

    coins.value = _prefs.getInt(_key(_coinsKey)) ?? _starterCoins;
    ownedIconIds.assignAll(
      _prefs.getStringList(_key(_ownedIconsKey)) ?? [defaultIconId],
    );
    ownedBlockSkinIds.assignAll(
      _normalizeOwnedBlockSkinIds(
        _prefs.getStringList(_key(_ownedBlocksKey)) ?? defaultOwnedBlockIds,
      ),
    );
    equippedIconId.value =
        _prefs.getString(_key(_equippedIconKey)) ?? defaultIconId;
    _applyEquippedBlockSkinIds(
      _normalizeEquippedBlockSkinIds(
        [
          _prefs.getString(_key(_equippedBlockKey)) ?? defaultBlockId,
          _prefs.getString(_key(_equippedSecondaryBlockKey)) ??
              blockColorCatalog[1].id,
        ],
        ownedIds: ownedBlockSkinIds.toList(),
      ),
    );

    // 유효성 검증 — 알 수 없는 ID면 기본값으로
    if (!ownsIcon(equippedIconId.value)) {
      equippedIconId.value = defaultIconId;
    }
    ownedCharacterIds.assignAll(
      _normalizeOwnedCharacterIds(
        _prefs.getStringList(_key(_ownedCharactersKey)) ?? const <String>[],
      ),
    );
    ownedPortraitIds.assignAll(
      _normalizeOwnedPortraitIds(
        _prefs.getStringList(_key(_ownedPortraitsKey)) ?? const ['slime_face'],
      ),
    );
    equippedCharacterId.value =
        _prefs.getString(_key(_equippedCharacterKey)) ?? defaultCharacterId;
    equippedPortraitId.value =
        _prefs.getString(_key(_equippedPortraitKey)) ?? defaultPortraitId;

    if (!ownsCharacter(equippedCharacterId.value)) {
      equippedCharacterId.value = '';
    }
    _applyEquippedBlockSkinIds(
      _normalizeEquippedBlockSkinIds(
        equippedBlockSkinIds,
        ownedIds: ownedBlockSkinIds.toList(),
      ),
    );

    await _persistLocal();
  }

  Future<bool> _loadFromSupabase() async {
    try {
      if (_userId == null) return false;
      final response = await _supabase.rpc(
        _getStateRpc,
        params: {'p_game_key': _gameKey},
      );
      _applyStateFromMap(response);
      debugPrint(
          '🟢 [ShopService] Loaded from Supabase — coins: ${coins.value}');
      return true;
    } catch (e) {
      debugPrint('🔴 [ShopService] Failed to load from Supabase: $e');
      return false;
    }
  }

  // ─── 소유 확인 ──────────────────────────────────────────

  bool ownsIcon(String id) => ownedIconIds.contains(id);

  /// 무료 아이템은 항상 소유 상태
  bool ownsBlockColor(String id) {
    final normalizedId = _resolveBlockSkinId(id);
    final item = _findBlockColorById(id);
    if (item != null && item.price == 0) return true;
    return ownedBlockSkinIds.contains(normalizedId ?? id);
  }

  bool ownsCharacter(String id) {
    if (id.isEmpty) return true;
    return ownedCharacterIds.contains(id);
  }

  bool ownsPortrait(String id) {
    final item = portraitItemForId(id);
    if (item == null) return false;
    // 아바타 소유권은 캐릭터 소유권과 독립적 (무료 아바타만 자동 소유)
    if (item.price == 0) return true;
    return ownedPortraitIds.contains(id);
  }

  bool ownsPattern(String id) {
    final item = _findPatternById(id);
    if (item != null && item.price == 0) return true;
    return false; // 추후 owned_patterns 목록으로 확장
  }

  // ─── 구매 ───────────────────────────────────────────────

  Future<String?> purchaseIcon(String id) async {
    final item = _findIconById(id);
    if (item == null) return '아이템을 찾지 못했습니다.';
    if (!_isLoggedIn) return '로그인 후 구매할 수 있습니다.';

    try {
      final response = await _supabase.rpc(
        _purchaseIconRpc,
        params: {'p_item_id': id, 'p_game_key': _gameKey},
      );
      _applyStateFromMap(response);
      await _persistLocal();
      return null;
    } on PostgrestException catch (e) {
      return _rpcErrorMessage(e);
    } catch (e) {
      debugPrint('🔴 [ShopService] purchaseIcon failed: $e');
      return '구매 중 오류가 발생했습니다.';
    }
  }

  Future<String?> purchaseBlockColor(String id) async {
    final normalizedId = _resolveBlockSkinId(id);
    final item = _findBlockColorById(id);
    if (item == null) return '아이템을 찾지 못했습니다.';
    if (normalizedId == null) return '아이템을 찾지 못했습니다.';
    if (!_isLoggedIn) return '로그인 후 구매할 수 있습니다.';

    try {
      final response = await _supabase.rpc(
        _purchaseBlockSkinRpc,
        params: {'p_item_id': normalizedId, 'p_game_key': _gameKey},
      );
      _applyStateFromMap(response);
      await _persistLocal();
      return null;
    } on PostgrestException catch (e) {
      return _blockSkinRpcErrorMessage(e, requestedItemId: id);
    } catch (e) {
      debugPrint('🔴 [ShopService] purchaseBlockColor failed: $e');
      return '구매 중 오류가 발생했습니다.';
    }
  }

  Future<String?> purchaseCharacter(String id) async {
    final item = characterItemForId(id);
    if (item == null) return '아이템을 찾지 못했습니다.';
    if (ownsCharacter(id)) return '이미 소유한 캐릭터입니다.';
    if (_isLoggedIn) {
      try {
        final response = await _supabase.rpc(
          _purchaseCharacterRpc,
          params: {'p_item_id': id, 'p_game_key': _gameKey},
        );
        _applyStateFromMap(response);
        await _persistLocal();
        return null;
      } on PostgrestException catch (e) {
        if (!_isUnsupportedShopRpc(e)) {
          return _rpcErrorMessage(e);
        }
      } catch (e) {
        debugPrint('🔴 [ShopService] purchaseCharacter failed: $e');
      }
    }

    if (coins.value < item.price) return '코인이 부족합니다.';
    coins.value -= item.price;
    ownedCharacterIds
        .assignAll(_normalizeOwnedCharacterIds([...ownedCharacterIds, id]));
    await _persistLocal();
    return null;
  }

  Future<String?> purchasePortrait(String id) async {
    final item = portraitItemForId(id);
    if (item == null) return '아이템을 찾지 못했습니다.';
    if (ownsPortrait(id)) return '이미 소유한 초상입니다.';

    if (_isLoggedIn) {
      try {
        final response = await _supabase.rpc(
          _purchasePortraitRpc,
          params: {'p_item_id': id, 'p_game_key': _gameKey},
        );
        _applyStateFromMap(response);
        await _persistLocal();
        return null;
      } on PostgrestException catch (e) {
        // 서버 RPC에 아직 캐릭터 소유 체크가 남아있을 수 있으므로,
        // 해당 에러는 무시하고 로컬 구매로 넘어감
        if (!_isUnsupportedShopRpc(e) && !_isLegacyCharacterOwnershipError(e)) {
          return _rpcErrorMessage(e);
        }
      } catch (e) {
        debugPrint('🔴 [ShopService] purchasePortrait failed: $e');
      }
    }

    if (coins.value < item.price) return '코인이 부족합니다.';
    coins.value -= item.price;
    ownedPortraitIds
        .assignAll(_normalizeOwnedPortraitIds([...ownedPortraitIds, id]));
    await _persistLocal();
    return null;
  }

  // ─── 장착 ───────────────────────────────────────────────

  Future<String?> equipIcon(String id) async {
    if (_isLoggedIn) {
      try {
        final response = await _supabase.rpc(
          _equipIconRpc,
          params: {'p_item_id': id, 'p_game_key': _gameKey},
        );
        _applyStateFromMap(response);
        await _persistLocal();
        return null;
      } on PostgrestException catch (e) {
        return _rpcErrorMessage(e);
      } catch (e) {
        return '장착 중 오류가 발생했습니다.';
      }
    }
    if (!ownsIcon(id)) return '구매한 아이템만 장착할 수 있습니다.';
    equippedIconId.value = id;
    await _persistLocal();
    return null;
  }

  Future<String?> equipCharacter(String id) async {
    if (!ownsCharacter(id)) return '구매한 캐릭터만 장착할 수 있습니다.';
    if (_isLoggedIn) {
      try {
        final response = await _supabase.rpc(
          _equipCharacterRpc,
          params: {'p_item_id': id, 'p_game_key': _gameKey},
        );
        _applyStateFromMap(response);
        await _persistLocal();
        return null;
      } on PostgrestException catch (e) {
        if (id.isEmpty) {
          debugPrint(
            '🟡 [ShopService] equipCharacter empty fallback after RPC error: ${e.message}',
          );
        } else if (!_isUnsupportedShopRpc(e)) {
          return _rpcErrorMessage(e);
        }
      } catch (e) {
        if (id.isNotEmpty) {
          debugPrint('🔴 [ShopService] equipCharacter failed: $e');
        }
      }
    }
    equippedCharacterId.value = id;
    await _persistLocal();
    return null;
  }

  Future<String?> equipPortrait(String id) async {
    final item = portraitItemForId(id);
    if (item == null) return '초상을 찾지 못했습니다.';
    if (!ownsPortrait(id)) return '구매한 초상만 장착할 수 있습니다.';

    if (_isLoggedIn) {
      try {
        final response = await _supabase.rpc(
          _equipPortraitRpc,
          params: {'p_item_id': id, 'p_game_key': _gameKey},
        );
        _applyStateFromMap(response);
        await _persistLocal();
        return null;
      } on PostgrestException catch (e) {
        if (!_isUnsupportedShopRpc(e) && !_isLegacyCharacterOwnershipError(e)) {
          return _rpcErrorMessage(e);
        }
      } catch (e) {
        debugPrint('🔴 [ShopService] equipPortrait failed: $e');
      }
    }
    equippedPortraitId.value = id;
    await _persistLocal();
    return null;
  }

  Future<String?> equipBlockColor(String id, {int slotIndex = 0}) async {
    final normalizedId = _resolveBlockSkinId(id);
    if (normalizedId == null) return '아이템을 찾지 못했습니다.';
    if (slotIndex < 0 || slotIndex > 1) return '잘못된 컬러 슬롯입니다.';
    if (!ownsBlockColor(normalizedId)) return '구매한 아이템만 장착할 수 있습니다.';
    final nextEquippedIds = _nextEquippedBlockSkinIds(
      itemId: normalizedId,
      slotIndex: slotIndex,
    );

    if (_isLoggedIn) {
      try {
        final response = await _supabase.rpc(_equipBlockSkinSlotRpc, params: {
          'p_item_id': normalizedId,
          'p_slot_index': slotIndex + 1,
          'p_game_key': _gameKey,
        });
        _applyStateFromMap(response);
        await _persistLocal();
        return null;
      } on PostgrestException catch (e) {
        if (_canFallbackToLegacyBlockEquip(e)) {
          if (slotIndex == 0) {
            try {
              final response = await _supabase.rpc(
                _equipBlockSkinRpc,
                params: {'p_item_id': normalizedId, 'p_game_key': _gameKey},
              );
              _applyStateFromMap(response);
            } on PostgrestException catch (legacyError) {
              return _rpcErrorMessage(legacyError);
            } catch (_) {
              return '장착 중 오류가 발생했습니다.';
            }
          }

          _applyEquippedBlockSkinIds(nextEquippedIds);
          await _persistLocal();
          return null;
        }
        return _blockSkinRpcErrorMessage(e, requestedItemId: id);
      } catch (e) {
        return '장착 중 오류가 발생했습니다.';
      }
    }
    _applyEquippedBlockSkinIds(nextEquippedIds);
    await _persistLocal();
    return null;
  }

  /// 무늬 장착 (현재는 기본만 존재, 추후 확장)
  Future<String?> equipPattern(String id) async {
    if (!ownsPattern(id)) return '구매한 아이템만 장착할 수 있습니다.';
    equippedPatternId.value = id;
    return null;
  }

  // ─── 코인 보상 ──────────────────────────────────────────

  Future<int> awardMatchCoins({
    required MultiplayerMode mode,
    required bool? won,
  }) async {
    // Match-result coin rewards are disabled.
    return 0;
  }

  Future<String?> refreshState() async {
    if (!_isLoggedIn) {
      await _persistLocal();
      return null;
    }

    try {
      final response = await _supabase.rpc(
        _getStateRpc,
        params: {'p_game_key': _gameKey},
      );
      _applyStateFromMap(response);
      await _persistLocal();
      return null;
    } on PostgrestException catch (e) {
      return _rpcErrorMessage(e);
    } catch (e) {
      debugPrint('🔴 [ShopService] refreshState failed: $e');
      return '상점 정보를 새로고침하지 못했습니다.';
    }
  }

  Future<String?> refreshStoreProducts() async {
    if (!supportsStoreBilling) {
      isStoreBillingAvailable.value = false;
      isStoreBillingLoading.value = false;
      storeProducts.clear();
      storeBillingMessage.value = '모바일 앱에서만 스토어 결제를 지원합니다.';
      return null;
    }

    isStoreBillingLoading.value = true;
    storeBillingMessage.value = null;

    try {
      final isAvailable = await _inAppPurchase.isAvailable();
      isStoreBillingAvailable.value = isAvailable;

      if (!isAvailable) {
        storeProducts.clear();
        storeBillingMessage.value = '$storeBillingLabel 결제 서버에 연결할 수 없습니다.';
        return null;
      }

      final response = await _inAppPurchase.queryProductDetails(
        coinPackageCatalog.map((item) => item.id).toSet(),
      );

      if (response.error != null) {
        storeProducts.clear();
        storeBillingMessage.value = response.error!.message;
        return response.error!.message;
      }

      final products = response.productDetails.toList()
        ..sort((a, b) => _packageOrder(a.id).compareTo(_packageOrder(b.id)));
      storeProducts.assignAll(products);

      if (response.notFoundIDs.isNotEmpty) {
        storeBillingMessage.value =
            '스토어 상품 일부가 아직 등록되지 않았습니다: ${response.notFoundIDs.join(', ')}';
      }

      return null;
    } catch (e) {
      debugPrint('🔴 [ShopService] refreshStoreProducts failed: $e');
      storeProducts.clear();
      storeBillingMessage.value = '스토어 상품을 불러오지 못했습니다.';
      return '스토어 상품을 불러오지 못했습니다.';
    } finally {
      isStoreBillingLoading.value = false;
    }
  }

  Future<String?> buyCoinPackage(String packageId) async {
    final package = coinPackageForId(packageId);
    if (package == null) return '충전 상품을 찾지 못했습니다.';
    if (!_isLoggedIn) return '로그인 후 충전할 수 있습니다.';
    if (!supportsStoreBilling) {
      return '코인 충전은 iOS App Store 또는 Android Google Play에서만 지원합니다.';
    }
    if (isStoreBillingLoading.value) return '스토어 상품을 불러오는 중입니다.';
    if (!isStoreBillingAvailable.value) {
      return '$storeBillingLabel 결제를 사용할 수 없습니다.';
    }

    final product = storeProductForId(package.id);
    if (product == null) {
      return '$storeBillingLabel 상품 설정을 확인해주세요.';
    }

    try {
      final started = await _inAppPurchase.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
        autoConsume: true,
      );
      if (!started) {
        return '$storeBillingLabel 결제 창을 열지 못했습니다.';
      }
      storeBillingMessage.value = null;
      return null;
    } catch (e) {
      debugPrint('🔴 [ShopService] buyCoinPackage failed: $e');
      return '코인 결제를 시작하지 못했습니다.';
    }
  }

  // ─── 회원 탈퇴 시 Supabase 데이터 삭제 ───────────────────

  Future<void> deleteShopData() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      await _supabase
          .from(_tableName)
          .delete()
          .eq('user_id', userId)
          .eq('game_key', _gameKey);
    } catch (e) {
      debugPrint('🔴 [ShopService] Failed to delete Supabase shop data: $e');
    }
  }

  // ─── 내부 헬퍼 ──────────────────────────────────────────

  String _key(String base) => '${base}_$_suffix';

  ShopIconItem? _findIconById(String id) =>
      iconCatalog.where((i) => i.id == id).firstOrNull;

  ShopBlockColorItem? _findBlockColorById(String id) => blockColorCatalog
      .where((i) => i.id == _resolveBlockSkinId(id))
      .firstOrNull;

  ShopPatternItem? _findPatternById(String id) =>
      patternCatalog.where((i) => i.id == id).firstOrNull;

  List<String> _normalizeOwnedCharacterIds(List<String> ids) {
    final normalized =
        ids.where((id) => characterItemForId(id) != null).toSet();

    return characterCatalog
        .map((item) => item.id)
        .where(normalized.contains)
        .toList(growable: false);
  }

  List<String> _normalizeOwnedPortraitIds(List<String> ids) {
    final normalized = <String>{
      'slime_face',
      ...ids.where((id) => portraitItemForId(id) != null),
    };

    return portraitCatalog
        .map((item) => item.id)
        .where(normalized.contains)
        .toList(growable: false);
  }

  Future<void> _initStoreBilling() async {
    if (!supportsStoreBilling) {
      isStoreBillingAvailable.value = false;
      isStoreBillingLoading.value = false;
      storeBillingMessage.value = '모바일 앱에서만 스토어 결제를 지원합니다.';
      return;
    }

    _purchaseSubscription ??= _inAppPurchase.purchaseStream.listen(
      (purchaseDetailsList) async {
        await _handlePurchaseUpdates(purchaseDetailsList);
      },
      onDone: () => _purchaseSubscription?.cancel(),
      onError: (Object error) {
        debugPrint('🔴 [ShopService] purchaseStream error: $error');
        isStorePurchasePending.value = false;
        storeBillingMessage.value = '스토어 결제 상태를 받아오지 못했습니다.';
      },
    );

    await refreshStoreProducts();
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchase in purchaseDetailsList) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          isStorePurchasePending.value = true;
          storeBillingMessage.value = '$storeBillingLabel 결제를 진행 중입니다.';
          break;
        case PurchaseStatus.error:
          isStorePurchasePending.value = false;
          storeBillingMessage.value =
              purchase.error?.message ?? '스토어 결제 중 오류가 발생했습니다.';
          break;
        case PurchaseStatus.canceled:
          isStorePurchasePending.value = false;
          storeBillingMessage.value = '결제가 취소되었습니다.';
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          isStorePurchasePending.value = false;
          final error = await _claimStorePurchase(purchase);
          if (error == null && purchase.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchase);
          } else if (error != null) {
            storeBillingMessage.value = error;
          }
          break;
      }
    }
  }

  Future<String?> _claimStorePurchase(PurchaseDetails purchase) async {
    if (!_isLoggedIn) return '로그인 상태를 확인할 수 없습니다.';
    if (coinPackageForId(purchase.productID) == null) {
      return '앱에 등록되지 않은 코인 상품입니다.';
    }

    try {
      final response = await _supabase.functions.invoke(
        AppConfig.storePurchaseVerifyFunctionName,
        body: {
          'game_key': _gameKey,
          'product_id': purchase.productID,
          'purchase_id': purchase.purchaseID,
          'transaction_date': purchase.transactionDate,
          'verification_data': {
            'source': purchase.verificationData.source,
            'server_verification_data':
                purchase.verificationData.serverVerificationData,
            'local_verification_data':
                purchase.verificationData.localVerificationData,
          },
        },
      );

      final payload = _asMap(response.data);
      final state = payload['state'];
      if (state == null) {
        return '영수증 검증 응답이 올바르지 않습니다.';
      }

      _applyStateFromMap(state);
      await _persistLocal();
      storeBillingMessage.value = null;
      return null;
    } catch (e) {
      debugPrint('🔴 [ShopService] _claimStorePurchase failed: $e');
      return '스토어 영수증 검증에 실패했습니다.';
    }
  }

  int _packageOrder(String productId) {
    final index = coinPackageCatalog.indexWhere((item) => item.id == productId);
    return index == -1 ? coinPackageCatalog.length : index;
  }

  Future<void> _persistLocal() async {
    final normalizedOwnedBlockSkinIds =
        _normalizeOwnedBlockSkinIds(ownedBlockSkinIds.toList());
    final normalizedEquippedBlockSkinIds = _normalizeEquippedBlockSkinIds(
      equippedBlockSkinIds,
      ownedIds: normalizedOwnedBlockSkinIds,
    );
    final normalizedOwnedCharacterIds =
        _normalizeOwnedCharacterIds(ownedCharacterIds.toList());
    final normalizedOwnedPortraitIds = _normalizeOwnedPortraitIds(
      ownedPortraitIds.toList(),
    );

    ownedBlockSkinIds.assignAll(normalizedOwnedBlockSkinIds);
    ownedCharacterIds.assignAll(normalizedOwnedCharacterIds);
    ownedPortraitIds.assignAll(normalizedOwnedPortraitIds);
    _applyEquippedBlockSkinIds(normalizedEquippedBlockSkinIds);
    if (!ownsCharacter(equippedCharacterId.value)) {
      equippedCharacterId.value = '';
    }

    await _prefs.setInt(_key(_coinsKey), coins.value);
    await _prefs.setStringList(_key(_ownedIconsKey), ownedIconIds.toList());
    await _prefs.setStringList(
      _key(_ownedBlocksKey),
      normalizedOwnedBlockSkinIds,
    );
    await _prefs.setString(_key(_equippedIconKey), equippedIconId.value);
    await _prefs.setString(_key(_equippedBlockKey), equippedBlockSkinId.value);
    await _prefs.setString(
      _key(_equippedSecondaryBlockKey),
      equippedSecondaryBlockSkinId.value,
    );
    await _prefs.setStringList(
      _key(_ownedCharactersKey),
      normalizedOwnedCharacterIds,
    );
    await _prefs.setString(
      _key(_equippedCharacterKey),
      equippedCharacterId.value,
    );
    await _prefs.setStringList(
      _key(_ownedPortraitsKey),
      normalizedOwnedPortraitIds,
    );
    await _prefs.setString(
      _key(_equippedPortraitKey),
      equippedPortraitId.value,
    );
  }

  void _applyStateFromMap(dynamic payload) {
    final row = _asMap(payload);

    coins.value = (row['coins'] as int?) ?? _starterCoins;
    ownedIconIds.assignAll(
      _stringListFromPayload(row['owned_icons'],
          fallback: iconCatalog.first.id),
    );
    ownedBlockSkinIds.assignAll(
      _normalizeOwnedBlockSkinIds(
        _stringListFromPayload(
          row['owned_block_skins'],
          fallback: blockColorCatalog.first.id,
        ),
      ),
    );

    equippedIconId.value =
        (row['equipped_icon'] as String?) ?? iconCatalog.first.id;
    ownedCharacterIds.assignAll(
      _normalizeOwnedCharacterIds(_stringListFromPayloadOrEmpty(
        row['owned_characters'],
      )),
    );
    equippedCharacterId.value = (row['equipped_character'] as String?) ?? '';
    ownedPortraitIds.assignAll(
      _normalizeOwnedPortraitIds(
        _stringListFromPayload(
          row['owned_portraits'],
          fallback: defaultPortraitId,
        ),
      ),
    );
    equippedPortraitId.value =
        (row['equipped_portrait'] as String?) ?? equippedPortraitId.value;

    final rawBlockId =
        (row['equipped_block_skin'] as String?) ?? blockColorCatalog.first.id;
    final rawEquippedBlockSkinIds = row['equipped_block_skins'];
    final equippedIds = rawEquippedBlockSkinIds is List
        ? rawEquippedBlockSkinIds.map((item) => item.toString()).toList()
        : <String>[
            rawBlockId,
            equippedSecondaryBlockSkinId.value,
          ];
    _applyEquippedBlockSkinIds(
      _normalizeEquippedBlockSkinIds(
        equippedIds,
        ownedIds: ownedBlockSkinIds.toList(),
      ),
    );

    if (!ownsIcon(equippedIconId.value)) {
      equippedIconId.value = iconCatalog.first.id;
    }
    if (!ownsCharacter(equippedCharacterId.value)) {
      equippedCharacterId.value = '';
    }
    if (!ownsPortrait(equippedPortraitId.value)) {
      equippedPortraitId.value = ownedPortraitIds.first;
    }
  }

  Map<String, dynamic> _asMap(dynamic payload) {
    if (payload is Map<String, dynamic>) return payload;
    if (payload is Map) {
      return payload.map((key, value) => MapEntry(key.toString(), value));
    }
    throw StateError('Unexpected shop payload: $payload');
  }

  List<String> _stringListFromPayload(dynamic payload,
      {required String fallback}) {
    if (payload is List) {
      final values = payload.map((item) => item.toString()).toList();
      if (values.isNotEmpty) return values;
    }
    return [fallback];
  }

  List<String> _stringListFromPayloadOrEmpty(dynamic payload) {
    if (payload is List) {
      return payload.map((item) => item.toString()).toList();
    }
    return const <String>[];
  }

  String? _normalizeBlockSkinId(String? id) {
    if (id == null) return null;
    return _legacyBlockSkinIdMap[id];
  }

  String? _resolveBlockSkinId(String? id) {
    if (id == null) return null;
    final exactMatch = blockColorCatalog.any((item) => item.id == id);
    if (exactMatch) return id;
    return _normalizeBlockSkinId(id);
  }

  void _applyEquippedBlockSkinIds(List<String> ids) {
    equippedBlockSkinId.value = ids.first;
    equippedSecondaryBlockSkinId.value = ids.last;
  }

  List<String> _normalizeEquippedBlockSkinIds(
    List<String> ids, {
    List<String>? ownedIds,
  }) {
    final normalizedOwnedIds =
        _normalizeOwnedBlockSkinIds(ownedIds ?? ownedBlockSkinIds.toList());
    final equippedIds = <String>[];
    final seen = <String>{};

    for (final id in ids) {
      final normalizedId = _normalizeBlockSkinId(id);
      if (normalizedId == null) continue;
      if (seen.contains(normalizedId)) continue;
      if (!normalizedOwnedIds.contains(normalizedId)) continue;
      equippedIds.add(normalizedId);
      seen.add(normalizedId);
      if (equippedIds.length == 2) break;
    }

    if (equippedIds.isEmpty) {
      equippedIds.add(blockColorCatalog.first.id);
    }
    if (equippedIds.length == 1) {
      equippedIds.add(
        _fallbackSecondaryBlockSkinId(
          primaryId: equippedIds.first,
          ownedIds: normalizedOwnedIds,
        ),
      );
    }
    return equippedIds;
  }

  List<String> _nextEquippedBlockSkinIds({
    required String itemId,
    required int slotIndex,
  }) {
    final nextIds = _normalizeEquippedBlockSkinIds(equippedBlockSkinIds);
    final otherIndex = slotIndex == 0 ? 1 : 0;
    final previousSlotId = nextIds[slotIndex];
    nextIds[slotIndex] = itemId;

    if (nextIds[otherIndex] == itemId) {
      nextIds[otherIndex] = previousSlotId;
    }

    return _normalizeEquippedBlockSkinIds(nextIds);
  }

  String _fallbackSecondaryBlockSkinId({
    required String primaryId,
    required List<String> ownedIds,
  }) {
    final preferredId = primaryId == blockColorCatalog.first.id
        ? blockColorCatalog[1].id
        : blockColorCatalog.first.id;
    if (ownedIds.contains(preferredId) && preferredId != primaryId) {
      return preferredId;
    }

    for (final item in blockColorCatalog) {
      if (item.id != primaryId && ownedIds.contains(item.id)) {
        return item.id;
      }
    }

    return blockColorCatalog.firstWhere((item) => item.id != primaryId).id;
  }

  List<String> _normalizeOwnedBlockSkinIds(List<String> ids) {
    final normalizedIds = <String>{
      for (final item in blockColorCatalog.where((item) => item.price == 0))
        item.id,
      for (final id in ids)
        if (_normalizeBlockSkinId(id) case final normalizedId?) normalizedId,
    };

    return blockColorCatalog
        .map((item) => item.id)
        .where(normalizedIds.contains)
        .toList();
  }

  bool _canFallbackToLegacyBlockEquip(PostgrestException error) {
    final message = error.message.toLowerCase();
    return error.code == 'PGRST202' ||
        message.contains(_equipBlockSkinSlotRpc) ||
        message.contains('schema cache');
  }

  bool _isUnsupportedShopRpc(PostgrestException error) {
    final message = error.message.toLowerCase();
    return error.code == 'PGRST202' ||
        message.contains('schema cache') ||
        message.contains('function public.shop_');
  }

  /// 서버 RPC에 아직 캐릭터 소유 검사가 남아있을 때 반환되는 에러 감지
  bool _isLegacyCharacterOwnershipError(PostgrestException error) {
    final message = error.message;
    return message.contains('캐릭터') && message.contains('보유');
  }

  String _rpcErrorMessage(PostgrestException error) {
    if (error.code == 'PGRST202') {
      return 'Supabase 상점 함수가 아직 반영되지 않았습니다.';
    }
    final message = error.message.trim();
    return message.isEmpty ? '요청 처리 중 오류가 발생했습니다.' : message;
  }

  String _blockSkinRpcErrorMessage(
    PostgrestException error, {
    String? requestedItemId,
  }) {
    final requestedItem = requestedItemId == null
        ? null
        : blockColorCatalog
            .firstWhereOrNull((item) => item.id == requestedItemId);
    final normalizedId = _resolveBlockSkinId(requestedItemId);
    final message = error.message.trim();

    if ((message == '아이템을 찾지 못했습니다.' || message.contains('아이템을 찾지 못했습니다')) &&
        requestedItem != null &&
        normalizedId != null) {
      return '${requestedItem.name} 색상은 앱에 등록되어 있지만 Supabase 상점 함수가 아직 최신이 아닙니다.';
    }

    return _rpcErrorMessage(error);
  }
}
