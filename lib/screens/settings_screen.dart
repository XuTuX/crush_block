import 'package:flutter/material.dart';
import 'package:crush_block/utils/device_utils.dart';
import 'package:get/get.dart';
import 'package:crush_block/services/auth_service.dart';
import 'package:crush_block/services/database_service.dart';
import 'package:crush_block/services/settings_service.dart';
import 'package:crush_block/services/shop_service.dart';
import 'package:crush_block/theme/app_components.dart';
import 'package:crush_block/theme/app_design_system.dart';
import 'package:crush_block/theme/app_typography.dart';
import 'package:crush_block/widgets/dialogs/edit_nickname_dialog.dart';
import 'package:crush_block/widgets/dialogs/custom_dialog.dart';
import 'package:crush_block/widgets/home_screen/login_sheet.dart';
import 'package:crush_block/widgets/portrait_avatar.dart';
import 'package:crush_block/widgets/tutorial_overlay.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatelessWidget {
  final AuthService authService;
  final DatabaseService dbService;

  const SettingsScreen({
    super.key,
    required this.authService,
    required this.dbService,
  });

  @override
  Widget build(BuildContext context) {
    final settingsService = Get.find<SettingsService>();
    final shopService = Get.find<ShopService>();

    void openLoginSheet() {
      Get.bottomSheet(
        LoginSheet(
          onGoogleSignIn: authService.signInWithGoogle,
          onAppleSignIn: authService.signInWithApple,
          onLoginSuccess: () => Get.back(),
        ),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: DeviceUtils.isTablet(context) ? 680 : 560),
                  child: Obx(() {
                    final user = authService.user.value;
                    final savedNickname = authService.userNickname.value;
                    final nickname = savedNickname ?? '닉네임 설정 필요';
                    final email = user?.email ?? '';

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.sm,
                        AppSpacing.xl,
                        AppSpacing.xxl,
                      ),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        // Account Section
                        _buildAccountCard(
                          user: user,
                          nickname: nickname,
                          email: email,
                          onLoginTap: openLoginSheet,
                          shopService: shopService,
                        ),

                        const SizedBox(height: AppSpacing.xl),
                        const _SectionTitle(title: '사용자 설정'),
                        AppSurface(
                          padding: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              Obx(
                                () => _ToggleRow(
                                  icon: Icons.vibration_rounded,
                                  title: '진동 피드백',
                                  value: settingsService.isHapticsOn.value,
                                  onChanged: (_) =>
                                      settingsService.toggleHaptics(),
                                ),
                              ),
                              const _RowDivider(),
                              AppListRow(
                                icon: Icons.badge_outlined,
                                title: '닉네임 수정',
                                subtitle: '매치와 랭킹에 표시될 이름',
                                trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.textSubtle),
                                onTap: user != null
                                    ? () => _showEditNicknameDialog(
                                          savedNickname ?? '',
                                          (newNickname) async {
                                            return authService.updateNickname(
                                              newNickname,
                                            );
                                          },
                                        )
                                    : openLoginSheet,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppSpacing.xl),
                        const _SectionTitle(title: '플레이 및 상담'),
                        AppSurface(
                          padding: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              AppListRow(
                                icon: Icons.help_outline_rounded,
                                title: '게임 튜토리얼',
                                subtitle: '다시 보며 규칙 익히기',
                                trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.textSubtle),
                                onTap: () => showTutorial(context,
                                    onComplete: () =>
                                        settingsService.completeTutorial()),
                              ),
                              const _RowDivider(),
                              AppListRow(
                                icon: Icons.chat_bubble_outline_rounded,
                                title: '문의하기',
                                subtitle: '인스타그램 공식 계정 DM',
                                trailing: const Icon(Icons.open_in_new_rounded,
                                    size: 16, color: AppColors.textSubtle),
                                onTap: _launchInstagram,
                              ),
                            ],
                          ),
                        ),

                        if (user != null) ...[
                          const SizedBox(height: AppSpacing.xl),
                          const _SectionTitle(title: '계정 관리'),
                          AppSurface(
                            padding: EdgeInsets.zero,
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                AppListRow(
                                  icon: Icons.logout_rounded,
                                  title: '로그아웃',
                                  subtitle: '현재 계정 접속 종료',
                                  onTap: () async {
                                    final error = await authService.signOut();
                                    if (error != null) {
                                      showCustomAlert('알림', error);
                                    }
                                  },
                                ),
                                const _RowDivider(),
                                AppListRow(
                                  icon: Icons.delete_outline_rounded,
                                  title: '회원 탈퇴',
                                  subtitle: '모든 데이터가 삭제되며 복구할 수 없습니다',
                                  titleColor: AppColors.danger,
                                  iconTint: AppColors.danger,
                                  onTap: () =>
                                      _showDeleteAccountDialog(authService),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: AppSpacing.xxl),
                        Center(
                          child: Text(
                            '버전 1.0.0',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSubtle,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: AppIconCircleButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Get.back(),
            ),
          ),
          Text(
            '설정',
            style: AppTypography.subtitle.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard({
    required dynamic user,
    required String nickname,
    required String email,
    required VoidCallback onLoginTap,
    required ShopService shopService,
  }) {
    final isLoggedIn = user != null;

    return AppSurface(
      elevated: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          if (isLoggedIn)
            PortraitAvatar(
              assetPath: shopService.selectedPortrait.assetPath,
              size: 56,
              accentColor: AppColors.primary,
              borderWidth: 0,
              glowOpacity: 0,
            )
          else
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.backgroundSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: AppColors.textSubtle,
                size: 28,
              ),
            ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoggedIn ? nickname : '게스트로 이용 중',
                  style: AppTypography.subtitle.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  isLoggedIn ? email : '로그인하면 기록을 저장할 수 있어요',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (!isLoggedIn)
            SizedBox(
              width: 86,
              child: AppActionButton(
                label: '로그인',
                tone: AppButtonTone.secondary,
                height: 40,
                onPressed: onLoginTap,
              ),
            ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(AuthService authService) {
    Get.dialog(
      Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          constraints: const BoxConstraints(maxWidth: 340),
          child: AppModalSurface(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.danger,
                  size: 32,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '정말 탈퇴하시겠습니까?',
                  style: AppTypography.subtitle.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '탈퇴하시면 계정과 프로필, 게임 기록, 랭킹, 상점 데이터가 삭제되며 이 작업은 취소할 수 없습니다.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: AppActionButton(
                        label: '취소',
                        tone: AppButtonTone.secondary,
                        height: 48,
                        onPressed: () => Get.back(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppActionButton(
                        label: '탈퇴',
                        tone: AppButtonTone.destructive,
                        height: 48,
                        onPressed: () async {
                          Get.back();
                          final error = await authService.deleteAccount();
                          if (error != null) {
                            showCustomAlert('알림', error);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      barrierColor: AppColors.overlay,
    );
  }

  void _showEditNicknameDialog(
    String currentNickname,
    Future<String?> Function(String) onSave,
  ) {
    Get.dialog(
      EditNicknameDialog(
        currentNickname: currentNickname,
        onSave: onSave,
      ),
      barrierColor: AppColors.overlay,
    );
  }

  Future<void> _launchInstagram() async {
    final url = Uri.parse(
      'https://www.instagram.com/neoreo_games?igsh=d3R6bnN3M3Y4ZzFu&utm_source=qr',
    );
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.xs),
      child: Text(
        title,
        style: AppTypography.label.copyWith(
          color: AppColors.textSubtle,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, size: 18, color: AppColors.ink),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                title,
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Transform.scale(
              scale: 0.9,
              child: Switch.adaptive(
                value: value,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 72, right: AppSpacing.md),
      height: 1,
      color: AppColors.borderSoft.withValues(alpha: 0.5),
    );
  }
}
