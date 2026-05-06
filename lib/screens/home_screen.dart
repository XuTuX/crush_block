import 'dart:async';

import 'package:crush_block/utils/device_utils.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crush_block/screens/multiplayer_game_screen.dart';
import 'package:crush_block/screens/multiplayer_lobby_screen.dart';
import 'package:crush_block/screens/ranking_screen.dart';
import 'package:crush_block/screens/settings_screen.dart';
import 'package:crush_block/screens/shop_screen.dart';
import 'package:crush_block/services/auth_service.dart';
import 'package:crush_block/services/database_service.dart';
import 'package:crush_block/services/multiplayer_service.dart';
import 'package:crush_block/services/shop_service.dart';
import 'package:crush_block/theme/app_components.dart';
import 'package:crush_block/widgets/home_screen/background_painter.dart';
import 'package:crush_block/widgets/home_screen/home_components.dart';
import 'package:crush_block/widgets/home_screen/login_sheet.dart';
import 'package:crush_block/widgets/tutorial_overlay.dart';
import 'package:crush_block/services/settings_service.dart';
import 'package:crush_block/theme/app_design_system.dart';
import 'package:crush_block/theme/app_typography.dart';
import 'package:crush_block/widgets/dialogs/edit_nickname_dialog.dart';
import 'package:crush_block/widgets/match_found_overlay.dart';

class HomeScreen extends StatefulWidget {
  final int initialPage;

  const HomeScreen({
    super.key,
    this.initialPage = 1,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MultiplayerService _multiplayerService = Get.find<MultiplayerService>();
  final ShopService _shopService = Get.find<ShopService>();
  late final Worker _profileLoadedWorker;
  late final Worker _userWorker;
  late final Worker _rankedRoomStatusWorker;
  late final PageController _pageController;
  bool _isNicknameDialogActive = false;
  bool _navigatedToRankedGame = false;
  bool _showRankedMatchFoundOverlay = false;
  late int _currentPageIndex;

  Timer? _rankedPlayingRetryTimer;

  @override
  void initState() {
    super.initState();

    final authService = Get.find<AuthService>();
    _currentPageIndex = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);

    _profileLoadedWorker =
        ever(authService.isProfileLoaded, (_) => _checkNicknameRequirement());
    _userWorker = ever(authService.user, (_) => _checkNicknameRequirement());
    _rankedRoomStatusWorker = ever(_multiplayerService.roomStatus, (status) {
      if (status == 'playing' && _shouldAutoNavigateToRankedGame) {
        unawaited(_navigateToRankedGame());
      }
    });
    _rankedPlayingRetryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _rankedPlayingRetryTimer?.cancel();
        return;
      }
      if (_shouldAutoNavigateToRankedGame) {
        unawaited(_navigateToRankedGame());
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNicknameRequirement();
      _checkTutorialRequirement();
      if (_shouldAutoNavigateToRankedGame) {
        unawaited(_navigateToRankedGame());
      }
    });
  }

  void _checkTutorialRequirement() {
    final settingsService = Get.find<SettingsService>();
    if (settingsService.isTutorialCompleted.value) return;
    if (settingsService.isTutorialDismissedForSession.value) return;

    showTutorial(
      context,
      onComplete: () {
        settingsService.completeTutorial();
      },
      onDismissed: settingsService.dismissTutorialForSession,
    );
  }

  @override
  void dispose() {
    _profileLoadedWorker.dispose();
    _userWorker.dispose();
    _rankedRoomStatusWorker.dispose();
    _rankedPlayingRetryTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  bool get _isRankedMatching {
    if (!_multiplayerService.currentMode.value.isRanked) return false;
    if (_multiplayerService.roomStatus.value == 'playing') return false;
    return _multiplayerService.isMatchmakingActive.value ||
        _multiplayerService.isBusy.value ||
        _multiplayerService.currentRoomId.value != null;
  }

  bool get _shouldAutoNavigateToRankedGame {
    return mounted &&
        _multiplayerService.currentMode.value.isRanked &&
        _multiplayerService.currentRoomId.value != null &&
        _multiplayerService.roomStatus.value == 'playing' &&
        !_navigatedToRankedGame;
  }

  Future<void> _checkNicknameRequirement() async {
    final authService = Get.find<AuthService>();

    if (authService.user.value != null &&
        authService.isProfileLoaded.value &&
        !authService.hasProfileLoadError.value &&
        authService.userNickname.value == null) {
      if (_isNicknameDialogActive) return;
      if (Get.isDialogOpen == true) return;

      debugPrint('Force showing nickname dialog due to missing nickname');
      _isNicknameDialogActive = true;
      try {
        await _showEditNicknameDialog(authService);
      } finally {
        _isNicknameDialogActive = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthService authService = Get.find<AuthService>();
    final DatabaseService dbService = Get.find<DatabaseService>();

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          bottomNavigationBar: _buildBottomBar(authService),
          body: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: GridPatternPainter()),
              ),
              Positioned.fill(
                child: SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: DeviceUtils.contentMaxWidth(context)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Top bar
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ProfileButton(
                                  authService: authService,
                                  onProfileTap: () =>
                                      _showSettingsSheet(authService),
                                  onLoginTap: () =>
                                      _showLoginSheet(authService),
                                ),
                              ],
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                            child: NicknameCard(
                              authService: authService,
                              dbService: dbService,
                            ),
                          ),

                          // Page content
                          Expanded(
                            child: PageView(
                              controller: _pageController,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentPageIndex = index;
                                });
                              },
                              children: [
                                _buildShopPage(),
                                _buildRankedPage(authService),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_showRankedMatchFoundOverlay) const MatchFoundOverlay(),
      ],
    );
  }

  // ═══════════════════════════════════════
  //  Ranked Page — clean hero
  // ═══════════════════════════════════════

  Widget _buildRankedPage(AuthService authService) {
    final DatabaseService dbService = Get.find<DatabaseService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppSurface(
                          elevated: true,
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            children: [
                              const HomeLogo(),
                              const SizedBox(height: AppSpacing.lg),
                              RankProgressPanel(
                                authService: authService,
                                dbService: dbService,
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              Obx(() {
                                final isMatching = _isRankedMatching;
                                final errorMessage = _multiplayerService
                                        .currentMode.value.isRanked
                                    ? _multiplayerService.errorMessage.value
                                    : null;

                                return Column(
                                  children: [
                                    PrimaryButton(
                                      label: isMatching ? '상대 찾는 중' : '랭킹전 시작',
                                      onPressed: () {
                                        if (isMatching) {
                                          unawaited(
                                            _multiplayerService
                                                .cancelMatchmaking(),
                                          );
                                          return;
                                        }
                                        unawaited(
                                          _startRankedMatchmaking(authService),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 220),
                                      child: isMatching
                                          ? Container(
                                              key: const ValueKey(
                                                'matching-status',
                                              ),
                                              padding: const EdgeInsets.all(
                                                AppSpacing.md,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.backgroundSoft,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                  AppRadius.lg,
                                                ),
                                              ),
                                              child: Column(
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      const SizedBox(
                                                        width: 14,
                                                        height: 14,
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: AppColors.ink,
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        width: AppSpacing.xs,
                                                      ),
                                                      Text(
                                                        '비슷한 티어의 상대를 찾고 있어요',
                                                        style: AppTypography
                                                            .bodySmall
                                                            .copyWith(
                                                          color: AppColors.ink,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    '버튼을 한 번 더 누르면 매칭을 취소할 수 있어요.',
                                                    textAlign: TextAlign.center,
                                                    style: AppTypography.caption
                                                        .copyWith(
                                                      color:
                                                          AppColors.textMuted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : GestureDetector(
                                              key: const ValueKey(
                                                'rank-view-link',
                                              ),
                                              onTap: () => _handleRankingPress(
                                                  authService),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: AppSpacing.xs,
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.bar_chart_rounded,
                                                      color: AppColors.ink,
                                                      size: 18,
                                                    ),
                                                    const SizedBox(
                                                      width: AppSpacing.xs,
                                                    ),
                                                    Text(
                                                      '현재 랭크 보기',
                                                      style: AppTypography
                                                          .bodySmall
                                                          .copyWith(
                                                        color: AppColors.ink,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                    ),
                                    if (!isMatching &&
                                        errorMessage != null &&
                                        errorMessage.trim().isNotEmpty) ...[
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        errorMessage,
                                        textAlign: TextAlign.center,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.danger,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════
  //  Shop Page
  // ═══════════════════════════════════════

  Widget _buildShopPage() {
    return const ShopContent();
  }

  // ═══════════════════════════════════════
  //  Bottom Bar — floating pill navigation
  // ═══════════════════════════════════════

  Widget _buildBottomBar(AuthService authService) {
    return SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.borderSoft),
                boxShadow: AppShadows.liftedCard,
              ),
              child: Row(
                children: [
                  _buildNavItem(
                    0,
                    Icons.storefront_outlined,
                    Icons.storefront_rounded,
                    '상점',
                    onTap: () => _goToPage(0),
                  ),
                  _buildNavItem(
                    1,
                    Icons.emoji_events_outlined,
                    Icons.emoji_events_rounded,
                    '랭킹전',
                    onTap: () => _goToPage(1),
                  ),
                  _buildNavItem(
                    2,
                    Icons.groups_outlined,
                    Icons.groups_rounded,
                    '친선전',
                    onTap: () => _openLobby(
                      authService,
                      MultiplayerMode.friendly,
                      replaceCurrent: true,
                      transition: Transition.noTransition,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label, {
    required VoidCallback onTap,
  }) {
    final isActive = _currentPageIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: isActive ? 16 : 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: isActive ? AppColors.ink : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isActive ? activeIcon : icon,
                  size: 20,
                  color:
                      isActive ? AppColors.backgroundWash : AppColors.textMuted,
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  child: isActive
                      ? Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            label,
                            style: AppTypography.caption.copyWith(
                              color: isActive
                                  ? AppColors.backgroundWash
                                  : AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _goToPage(int index) async {
    if (index != 1 && _isRankedMatching) {
      await _multiplayerService.cancelMatchmaking();
    }
    if (!mounted) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  // ═══════════════════════════════════════
  //  Logic & Sheets (unchanged)
  // ═══════════════════════════════════════

  Future<void> _openLobby(
    AuthService authService,
    MultiplayerMode mode, {
    bool replaceCurrent = false,
    Transition transition = Transition.rightToLeft,
  }) async {
    if (mode.isRanked) {
      await _startRankedMatchmaking(authService);
      return;
    }

    if (authService.user.value != null) {
      if (_isRankedMatching) {
        await _multiplayerService.cancelMatchmaking();
      }
      _multiplayerService.configureMode(mode);
      if (replaceCurrent) {
        await Get.off(
          () => const MultiplayerLobbyScreen(),
          transition: transition,
          duration: const Duration(milliseconds: 220),
        );
      } else {
        await Get.to(
          () => const MultiplayerLobbyScreen(),
          transition: transition,
          duration: const Duration(milliseconds: 300),
        );
      }
    } else {
      _showLoginSheet(
        authService,
        onLoginSuccess: () => _openLobby(
          authService,
          mode,
          replaceCurrent: replaceCurrent,
          transition: transition,
        ),
      );
    }
  }

  Future<void> _startRankedMatchmaking(AuthService authService) async {
    if (authService.user.value == null) {
      _showLoginSheet(
        authService,
        onLoginSuccess: () => unawaited(_startRankedMatchmaking(authService)),
      );
      return;
    }

    if (_isRankedMatching) return;

    _multiplayerService.configureMode(MultiplayerMode.ranked);
    await _multiplayerService.quickMatch();

    if (_shouldAutoNavigateToRankedGame) {
      await _navigateToRankedGame();
    }
  }

  void _handleRankingPress(AuthService authService) {
    if (authService.user.value != null) {
      _showRankingSheet();
    } else {
      _showLoginSheet(authService, isRankingAction: true);
    }
  }

  void _showLoginSheet(AuthService authService,
      {bool isRankingAction = false,
      String? initialError,
      VoidCallback? onLoginSuccess}) {
    Get.bottomSheet(
      LoginSheet(
        isRankingAction: isRankingAction,
        initialError: initialError,
        onGoogleSignIn: () async {
          return await authService.signInWithGoogle();
        },
        onAppleSignIn: () async {
          return await authService.signInWithApple();
        },
        onLoginSuccess: () async {
          await Future.delayed(const Duration(milliseconds: 100));

          if (isRankingAction) {
            _showRankingSheet();
          }

          onLoginSuccess?.call();
        },
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  void _showSettingsSheet(AuthService authService) {
    final DatabaseService dbService = Get.find<DatabaseService>();
    Get.to(
      () => SettingsScreen(
        authService: authService,
        dbService: dbService,
      ),
      transition: Transition.rightToLeft,
      duration: const Duration(milliseconds: 300),
    );
  }

  void _showRankingSheet() {
    Get.bottomSheet(
      const RankingScreen(),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enterBottomSheetDuration: const Duration(milliseconds: 300),
    );
  }

  Future<void> _showEditNicknameDialog(AuthService authService) async {
    await Get.dialog(
      EditNicknameDialog(
        currentNickname: '',
        isInitialSetup: true,
        onSave: (newNickname) async {
          return await authService.updateNickname(newNickname);
        },
      ),
      barrierDismissible: false,
      barrierColor: AppColors.overlay,
    );
  }

  Future<void> _navigateToRankedGame() async {
    if (!mounted || _navigatedToRankedGame) return;
    _navigatedToRankedGame = true;

    setState(() {
      _showRankedMatchFoundOverlay = true;
    });

    try {
      final roomId = _multiplayerService.currentRoomId.value;
      final myUserId = Get.find<AuthService>().user.value?.id;

      if (roomId == null || myUserId == null) {
        _navigatedToRankedGame = false;
        return;
      }

      final seed = _multiplayerService.gameSeed.value;

      final playerInfo = await _resolvePlayerInfo(myUserId);
      if (playerInfo == null || !mounted) {
        setState(() {
          _navigatedToRankedGame = false;
          _showRankedMatchFoundOverlay = false;
        });
        return;
      }

      await Future.delayed(const Duration(milliseconds: 250));

      if (!mounted) {
        _navigatedToRankedGame = false;
        _showRankedMatchFoundOverlay = false;
        return;
      }

      Get.to(
        () => MultiplayerGameScreen(
          roomId: roomId,
          seed: seed,
          mode: MultiplayerMode.ranked,
          myUserId: myUserId,
          opponentUserId: playerInfo['opponentUserId'] as String,
          opponentNickname: playerInfo['opponentNickname'] as String,
          myNickname: playerInfo['myNickname'] as String,
          myPortraitId: playerInfo['myPortraitId'] as String,
          opponentPortraitId: playerInfo['opponentPortraitId'] as String,
        ),
        transition: Transition.fadeIn,
        duration: const Duration(milliseconds: 400),
      )?.then((_) {
        setState(() {
          _navigatedToRankedGame = false;
          _showRankedMatchFoundOverlay = false;
        });
      });
    } catch (e) {
      debugPrint('_navigateToRankedGame error: $e');
      setState(() {
        _navigatedToRankedGame = false;
        _showRankedMatchFoundOverlay = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _resolvePlayerInfo(String myUserId) async {
    for (int attempt = 0; attempt < 10; attempt++) {
      await _multiplayerService.refreshRoomPlayers();

      String opponentUserId = '';
      String opponentNickname = '플레이어 2';
      String myNickname = '플레이어 1';
      String opponentPortraitId = _shopService.defaultPortraitId;

      for (final player in _multiplayerService.players) {
        final uid = player['user_id'] as String;
        final profile = player['profiles'] as Map<String, dynamic>?;
        final nickname = profile?['nickname']?.toString() ?? '플레이어';
        final portraitId =
            player['portrait_id']?.toString() ?? _shopService.defaultPortraitId;

        if (uid == myUserId) {
          myNickname = nickname;
        } else {
          opponentUserId = uid;
          opponentNickname = nickname;
          opponentPortraitId = portraitId;
        }
      }

      if (opponentUserId.isNotEmpty) {
        return {
          'opponentUserId': opponentUserId,
          'opponentNickname': opponentNickname,
          'myNickname': myNickname,
          'myPortraitId': _shopService.equippedPortraitId.value,
          'opponentPortraitId': opponentPortraitId,
        };
      }

      debugPrint('_resolvePlayerInfo: retry ${attempt + 1}/10...');
      await Future.delayed(const Duration(milliseconds: 600));
    }
    debugPrint('_resolvePlayerInfo: opponent lookup failed.');
    return null;
  }
}
