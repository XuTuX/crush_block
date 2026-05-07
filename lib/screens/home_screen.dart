import 'dart:async';

import 'package:crush_block/screens/multiplayer_game_screen.dart';
import 'package:crush_block/screens/ranking_screen.dart';
import 'package:crush_block/services/auth_service.dart';
import 'package:crush_block/services/multiplayer_service.dart';
import 'package:crush_block/theme/app_components.dart';
import 'package:crush_block/theme/app_design_system.dart';
import 'package:crush_block/theme/app_typography.dart';
import 'package:crush_block/utils/device_utils.dart';
import 'package:crush_block/widgets/brand_assets.dart';
import 'package:crush_block/widgets/dialogs/custom_dialog.dart';
import 'package:crush_block/widgets/dialogs/edit_nickname_dialog.dart';
import 'package:crush_block/widgets/home_screen/background_painter.dart';
import 'package:crush_block/widgets/match_found_overlay.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MultiplayerService _multiplayerService = Get.find<MultiplayerService>();
  late final Worker _roomStatusWorker;
  Timer? _rankedPlayingRetryTimer;
  bool _navigatedToRankedGame = false;
  bool _showRankedMatchFoundOverlay = false;

  @override
  void initState() {
    super.initState();
    _multiplayerService.configureMode(MultiplayerMode.ranked);
    _roomStatusWorker = ever(_multiplayerService.roomStatus, (_) {
      if (_shouldAutoNavigateToRankedGame) {
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
      if (_shouldAutoNavigateToRankedGame) {
        unawaited(_navigateToRankedGame());
      }
    });
  }

  @override
  void dispose() {
    _roomStatusWorker.dispose();
    _rankedPlayingRetryTimer?.cancel();
    super.dispose();
  }

  bool get _isMatching {
    return _multiplayerService.isMatchmakingActive.value ||
        _multiplayerService.isBusy.value ||
        (_multiplayerService.currentRoomId.value != null &&
            _multiplayerService.roomStatus.value != 'selecting' &&
            _multiplayerService.roomStatus.value != 'playing');
  }

  bool get _shouldAutoNavigateToRankedGame {
    return mounted &&
        _multiplayerService.currentRoomId.value != null &&
        (_multiplayerService.roomStatus.value == 'selecting' ||
            _multiplayerService.roomStatus.value == 'playing') &&
        !_navigatedToRankedGame;
  }

  @override
  Widget build(BuildContext context) {
    final authService = Get.find<AuthService>();

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: GridPatternPainter()),
              ),
              Positioned(
                top: AppSpacing.md,
                right: AppSpacing.md,
                child: _SettingsButton(
                  onPressed: () => _showSettingsSheet(authService),
                ),
              ),
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: DeviceUtils.contentMaxWidth(context),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: AppBrandLogo(size: 104)),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            'CRUSH',
                            textAlign: TextAlign.center,
                            style: AppTypography.headline.copyWith(
                              color: AppColors.ink.withValues(alpha: 0.87),
                            ),
                          ),
                          Text(
                            'BLOCK',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.blackHanSans(
                              fontSize: 52,
                              height: 0.96,
                              letterSpacing: 0,
                              color: AppColors.ink,
                              shadows: [
                                Shadow(
                                  color: AppColors.areaPalette[1]
                                      .withValues(alpha: 0.36),
                                  offset: const Offset(4, 4),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Obx(() {
                            final nickname =
                                authService.userNickname.value ?? '플레이어';
                            return Align(
                              alignment: Alignment.center,
                              child: Transform.rotate(
                                angle: -0.035,
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width * 0.7,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.areaPalette[2],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.ink,
                                      width: AppStroke.strong,
                                    ),
                                    boxShadow: AppShadows.hard(offset: 3),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.person_rounded,
                                        size: 18,
                                        color: AppColors.ink,
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      Flexible(
                                        child: Text(
                                          nickname,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.blackHanSans(
                                            fontSize: 16,
                                            letterSpacing: 0,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: AppSpacing.xxl),
                          Obx(() {
                            final matching = _isMatching;
                            return AppActionButton(
                              label: matching ? '매칭 취소' : '게임 시작',
                              icon: matching
                                  ? Icons.close_rounded
                                  : Icons.play_arrow_rounded,
                              isLoading:
                                  _multiplayerService.isBusy.value && !matching,
                              onPressed: () {
                                if (matching) {
                                  unawaited(
                                    _multiplayerService.cancelMatchmaking(),
                                  );
                                  return;
                                }
                                unawaited(_startRankedMatchmaking());
                              },
                            );
                          }),
                          const SizedBox(height: AppSpacing.md),
                          AppActionButton(
                            label: '랭킹 보기',
                            icon: Icons.leaderboard_rounded,
                            tone: AppButtonTone.secondary,
                            onPressed: () {
                              Get.to(
                                () => const RankingScreen(),
                                transition: Transition.rightToLeft,
                                duration: const Duration(milliseconds: 240),
                              );
                            },
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Obx(() {
                            final message =
                                _multiplayerService.errorMessage.value;
                            if (message != null && message.trim().isNotEmpty) {
                              return Text(
                                message,
                                textAlign: TextAlign.center,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                            }

                            if (_isMatching) {
                              return Text(
                                '상대를 찾는 중입니다.',
                                textAlign: TextAlign.center,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textMuted,
                                ),
                              );
                            }

                            return const SizedBox.shrink();
                          }),
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

  Future<void> _startRankedMatchmaking() async {
    final authService = Get.find<AuthService>();
    if (authService.user.value == null || _isMatching) return;

    _multiplayerService.configureMode(MultiplayerMode.ranked);
    await _multiplayerService.quickMatch();

    if (_shouldAutoNavigateToRankedGame) {
      await _navigateToRankedGame();
    }
  }

  void _showSettingsSheet(AuthService authService) {
    Get.bottomSheet(
      _SettingsSheet(authService: authService),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.ink.withValues(alpha: 0.36),
    );
  }

  Future<void> _showEditNicknameDialog(AuthService authService) async {
    await Get.dialog(
      EditNicknameDialog(
        currentNickname: authService.userNickname.value ?? '',
        onSave: authService.updateNickname,
      ),
      barrierDismissible: false,
      barrierColor: AppColors.ink.withValues(alpha: 0.5),
    );
  }

  void _confirmSignOut(AuthService authService) {
    showCustomConfirm(
      '로그아웃',
      '현재 계정에서 로그아웃할까요?',
      () async {
        final error = await authService.signOut();
        if (error != null) {
          showCustomAlert('로그아웃 실패', error);
        }
      },
      confirmText: '로그아웃',
      cancelText: '취소',
    );
  }

  void _confirmDeleteAccount(AuthService authService) {
    showCustomConfirm(
      '계정 삭제',
      '계정과 게임 기록이 삭제됩니다. 이 작업은 되돌릴 수 없어요.',
      () async {
        final error = await authService.deleteAccount();
        if (error != null) {
          showCustomAlert('계정 삭제 실패', error);
        }
      },
      confirmText: '삭제',
      cancelText: '취소',
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

      final playerInfo = _resolvePlayerInfo(myUserId);

      await Future.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;

      Get.to(
        () => MultiplayerGameScreen(
          roomId: roomId,
          seed: _multiplayerService.gameSeed.value,
          mode: MultiplayerMode.ranked,
          myUserId: myUserId,
          opponentUserId: playerInfo.opponentUserId,
          opponentNickname: playerInfo.opponentNickname,
          myNickname: playerInfo.myNickname,
        ),
        transition: Transition.fadeIn,
        duration: const Duration(milliseconds: 260),
      )?.then((_) {
        if (!mounted) return;
        setState(() {
          _navigatedToRankedGame = false;
          _showRankedMatchFoundOverlay = false;
        });
      });
    } catch (e) {
      debugPrint('_navigateToRankedGame error: $e');
      if (!mounted) return;
      setState(() {
        _navigatedToRankedGame = false;
        _showRankedMatchFoundOverlay = false;
      });
    }
  }

  _ResolvedPlayerInfo _resolvePlayerInfo(String myUserId) {
    var opponentUserId = 'opponent';
    var opponentNickname = '상대';
    var myNickname = Get.find<AuthService>().userNickname.value ?? '나';

    for (final player in _multiplayerService.players) {
      final uid = player['user_id']?.toString() ?? '';
      final profile = player['profiles'];
      final nickname = _nicknameFromProfile(profile);

      if (player['is_me'] == true || uid == myUserId) {
        myNickname = nickname;
      } else {
        opponentUserId = uid.isEmpty ? opponentUserId : uid;
        opponentNickname = nickname;
      }
    }

    return _ResolvedPlayerInfo(
      myNickname: myNickname,
      opponentUserId: opponentUserId,
      opponentNickname: opponentNickname,
    );
  }

  String _nicknameFromProfile(dynamic profile) {
    if (profile is Map<String, dynamic>) {
      return profile['nickname']?.toString() ?? '플레이어';
    }
    if (profile is Map) {
      return profile['nickname']?.toString() ?? '플레이어';
    }
    return '플레이어';
  }
}

class _SettingsButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _SettingsButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.borderSoft),
        ),
        child: IconButton(
          tooltip: '설정',
          icon: const Icon(Icons.settings_rounded),
          color: AppColors.ink,
          splashRadius: 22,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  final AuthService authService;

  const _SettingsSheet({required this.authService});

  @override
  Widget build(BuildContext context) {
    final homeState = context.findAncestorStateOfType<_HomeScreenState>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '설정',
                      style: AppTypography.subtitle.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: Get.back,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Obx(() {
                final nickname = authService.userNickname.value ?? '플레이어';
                return _SettingsTile(
                  icon: Icons.person_rounded,
                  title: nickname,
                  subtitle: '닉네임',
                  onTap: () {
                    Get.back();
                    homeState?._showEditNicknameDialog(authService);
                  },
                );
              }),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.logout_rounded,
                title: '로그아웃',
                subtitle: '현재 계정에서 나가기',
                onTap: () {
                  Get.back();
                  homeState?._confirmSignOut(authService);
                },
              ),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.delete_outline_rounded,
                title: '계정 삭제',
                subtitle: '계정과 기록 삭제',
                destructive: true,
                onTap: () {
                  Get.back();
                  homeState?._confirmDeleteAccount(authService);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.dangerStrong : AppColors.ink;

    return Material(
      color: destructive ? AppColors.dangerSoft : AppColors.backgroundSoft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.caption.copyWith(
                        color: destructive
                            ? AppColors.dangerStrong.withValues(alpha: 0.72)
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: destructive ? color : AppColors.textSubtle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResolvedPlayerInfo {
  final String myNickname;
  final String opponentUserId;
  final String opponentNickname;

  const _ResolvedPlayerInfo({
    required this.myNickname,
    required this.opponentUserId,
    required this.opponentNickname,
  });
}
