import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:link_your_area/services/multiplayer_service.dart';
import 'package:link_your_area/services/shop_service.dart';
import 'package:link_your_area/screens/multiplayer_game_screen.dart';
import 'package:link_your_area/screens/home_screen.dart';
import 'package:link_your_area/theme/app_design_system.dart';
import 'package:link_your_area/theme/app_typography.dart';
import 'package:link_your_area/utils/device_utils.dart';

import 'package:link_your_area/screens/multiplayer_lobby/in_room_ui.dart';
import 'package:link_your_area/screens/multiplayer_lobby/not_in_room_ui.dart';

import 'package:link_your_area/widgets/home_screen/background_painter.dart';
import 'package:link_your_area/widgets/match_found_overlay.dart';

class MultiplayerLobbyScreen extends StatefulWidget {
  const MultiplayerLobbyScreen({super.key});

  @override
  State<MultiplayerLobbyScreen> createState() => _MultiplayerLobbyScreenState();
}

class _MultiplayerLobbyScreenState extends State<MultiplayerLobbyScreen> {
  final MultiplayerService _service = Get.find<MultiplayerService>();
  final ShopService _shopService = Get.find<ShopService>();
  bool _navigatedToGame = false;
  bool _showMatchFoundOverlay = false;
  Worker? _roomStatusWorker;

  @override
  void initState() {
    super.initState();
    _service.configureMode(MultiplayerMode.friendly);

    _roomStatusWorker = ever(_service.roomStatus, (status) {
      if ((status == 'playing' || status == 'selecting') && !_navigatedToGame) {
        _navigateToGame();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if ((_service.roomStatus.value == 'playing' ||
              _service.roomStatus.value == 'selecting') &&
          !_navigatedToGame) {
        _navigateToGame();
      }
    });
  }

  @override
  void dispose() {
    _roomStatusWorker?.dispose();
    super.dispose();
  }

  Future<void> _navigateToGame() async {
    if (!mounted) return;
    if (_navigatedToGame) return;
    _navigatedToGame = true;

    setState(() {
      _showMatchFoundOverlay = true;
    });

    try {
      final roomId = _service.currentRoomId.value;
      final myUserId = Supabase.instance.client.auth.currentUser?.id;

      if (roomId == null || myUserId == null) {
        _navigatedToGame = false;
        return;
      }

      // Add a slight delay so the user can see the "Game Found" message
      await Future.delayed(const Duration(milliseconds: 1800));

      if (!mounted) {
        _navigatedToGame = false;
        _showMatchFoundOverlay = false;
        return;
      }

      // Extract opponents from players list
      String opponentUserId = '';
      String opponentNickname = '상대방';
      String myNickname = '나';

      for (var p in _service.players) {
        if (p['user_id'] == myUserId) {
          myNickname = p['profiles']?['nickname'] ?? '나';
        } else {
          opponentUserId = p['user_id'] ?? '';
          opponentNickname = p['profiles']?['nickname'] ?? '상대방';
        }
      }

      Get.to(
        () => MultiplayerGameScreen(
          roomId: roomId,
          myUserId: myUserId,
          opponentUserId: opponentUserId,
          opponentNickname: opponentNickname,
          myNickname: myNickname,
          myPortraitId: _shopService.equippedPortraitId.value,
          opponentPortraitId: _shopService.defaultPortraitId,
        ),
        transition: Transition.fadeIn,
        duration: const Duration(milliseconds: 400),
      )?.then((_) {
        setState(() {
          _navigatedToGame = false;
          _showMatchFoundOverlay = false;
        });
      });
    } catch (e) {
      debugPrint('_navigateToGame error: $e');
      setState(() {
        _navigatedToGame = false;
        _showMatchFoundOverlay = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          bottomNavigationBar: Obx(() {
            if (_service.currentRoomId.value != null) {
              return _buildInRoomBottomBar();
            }
            return _buildBottomBar();
          }),
          body: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: GridPatternPainter()),
              ),
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth: DeviceUtils.contentMaxWidth(context)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        Obx(() {
                          final inRoom = _service.currentRoomId.value != null;
                          final isBusy = _service.isBusy.value;

                          return Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_service.errorMessage.value != null)
                                    _buildErrorCard(
                                        _service.errorMessage.value!),
                                  if (!inRoom)
                                    Expanded(
                                      child: NotInRoomUi(
                                        isBusy: isBusy,
                                      ),
                                    )
                                  else ...[
                                    const SizedBox(height: 8),
                                    Expanded(child: InRoomUi()),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_showMatchFoundOverlay) const MatchFoundOverlay(),
      ],
    );
  }

  Widget _buildBottomBar() {
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
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: AppShadows.liftedCard,
              ),
              child: Row(
                children: [
                  _buildNavItem(
                    index: 0,
                    activeIndex: 2,
                    icon: Icons.storefront_outlined,
                    activeIcon: Icons.storefront_rounded,
                    label: '상점',
                    onTap: () => _handleBottomNavTap(0),
                  ),
                  _buildNavItem(
                    index: 1,
                    activeIndex: 2,
                    icon: Icons.emoji_events_outlined,
                    activeIcon: Icons.emoji_events_rounded,
                    label: '랭킹전',
                    onTap: () => _handleBottomNavTap(1),
                  ),
                  _buildNavItem(
                    index: 2,
                    activeIndex: 2,
                    icon: Icons.groups_outlined,
                    activeIcon: Icons.groups_rounded,
                    label: '친선전',
                    onTap: () => _handleBottomNavTap(2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInRoomBottomBar() {
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
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _service.leaveRoom(),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Center(
                    child: Text(
                      '방 나가기',
                      style: AppTypography.button.copyWith(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required int activeIndex,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isActive = activeIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: isActive ? null : onTap,
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
              color: isActive ? AppColors.primarySoft : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isActive ? activeIcon : icon,
                  size: 20,
                  color: isActive ? AppColors.primary : AppColors.textMuted,
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  child: isActive
                      ? const SizedBox(width: 6)
                      : const SizedBox.shrink(),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  child: isActive
                      ? Text(
                          label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            letterSpacing: -0.2,
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

  Future<void> _handleBottomNavTap(int index) async {
    if (_service.currentRoomId.value != null || _service.isBusy.value) {
      await _service.cancelMatchmaking();
    }

    if (!mounted) return;

    if (index == 2) {
      return;
    }

    Get.off(
      () => HomeScreen(initialPage: index),
      transition: Transition.noTransition,
      duration: const Duration(milliseconds: 180),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.danger,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
