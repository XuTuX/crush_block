import 'package:crush_block/services/multiplayer_service.dart';
import 'package:crush_block/services/auth_service.dart';
import 'package:crush_block/services/shop_service.dart';
import 'package:crush_block/theme/app_design_system.dart';
import 'package:crush_block/theme/app_typography.dart';
import 'package:crush_block/widgets/portrait_avatar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../widgets/mp_buttons.dart';

class InRoomUi extends StatelessWidget {
  InRoomUi({
    super.key,
  });

  final MultiplayerService _service = Get.find<MultiplayerService>();
  final ShopService _shopService = Get.find<ShopService>();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildRoomHeaderCard(),
        const SizedBox(height: 20),
        Text(
          '참가자',
          style: AppTypography.label.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildPlayersList(showReadyBadge: true)),
        _buildReadyButtons(),
        const SizedBox(height: 8),
        Obx(() {
          if (_service.roomStatus.value == 'playing') {
            return _buildStartingIndicator();
          }
          return const SizedBox.shrink();
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildRoomHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.04),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Obx(() => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _service.roomStatus.value == 'playing'
                      ? AppColors.primarySoft
                      : AppColors.secondarySoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(_service.roomStatus.value),
                  style: AppTypography.label.copyWith(
                    fontSize: 12,
                    color: _service.roomStatus.value == 'playing'
                        ? AppColors.primary
                        : AppColors.ink,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              )),
          const SizedBox(height: 20),
          Obx(() {
            final roomTitle = _service.currentRoomTitle.value;
            return Text(
              roomTitle != null && roomTitle.isNotEmpty ? roomTitle : '친선전 대기실',
              textAlign: TextAlign.center,
              style: AppTypography.headline.copyWith(
                color: AppColors.ink,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPlayersList({required bool showReadyBadge}) {
    return Obx(() {
      return ListView.builder(
        itemCount: _service.players.length,
        itemBuilder: (context, index) {
          final p = _service.players[index];
          final profile = p['profiles'] as Map<String, dynamic>?;
          final nickname =
              profile?['nickname']?.toString() ?? '플레이어 ${index + 1}';
          final ready = p['is_ready'] == true;
          final portrait = _shopService.portraitItemForId(
                p['portrait_id']?.toString(),
              ) ??
              ShopService.portraitCatalog.first;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                PortraitAvatar(
                  assetPath: portrait.assetPath,
                  size: 44,
                  accentColor: ready ? AppColors.success : AppColors.primary,
                  borderWidth: 0,
                  glowOpacity: 0.05,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        nickname,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (p['grade_icon_path'] != null)
                        Image.asset(
                          p['grade_icon_path'] as String,
                          width: 24,
                          height: 24,
                        ),
                    ],
                  ),
                ),
                if (showReadyBadge)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: ready
                          ? AppColors.successSoft
                          : AppColors.backgroundSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      ready ? '준비 완료' : '대기 중',
                      style: AppTypography.label.copyWith(
                        fontSize: 11,
                        color: ready ? AppColors.success : AppColors.textMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    });
  }

  Widget _buildReadyButtons() {
    return Obx(() {
      final isReady = _service.players.any((p) =>
          p['user_id'] == Get.find<AuthService>().user.value?.id &&
          p['is_ready'] == true);

      return Row(
        children: [
          if (isReady)
            Expanded(
              child: MpSecondaryButton(
                label: '준비 해제',
                icon: Icons.close_rounded,
                onPressed: () => _service.toggleReady(false),
              ),
            )
          else
            Expanded(
              child: MpPrimaryButton(
                label: '준비 완료',
                icon: Icons.check_rounded,
                color: AppColors.primary,
                onPressed: () => _service.toggleReady(true),
              ),
            ),
        ],
      );
    });
  }

  Widget _buildStartingIndicator() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '게임을 시작하는 중입니다',
            style: AppTypography.label.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'playing':
        return '게임 중';
      case 'finished':
        return '종료';
      case 'waiting':
      default:
        return '대기 중';
    }
  }
}
