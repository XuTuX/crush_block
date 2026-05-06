import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:link_your_area/config/app_config.dart';
import 'package:link_your_area/theme/app_components.dart';
import 'package:link_your_area/theme/app_design_system.dart';
import 'package:link_your_area/theme/app_typography.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginSheet extends StatefulWidget {
  final bool isRankingAction;
  final bool isFullScreen;
  final bool closeOnSuccess;
  final String? initialError;
  final Future<String?> Function() onGoogleSignIn;
  final Future<String?> Function() onAppleSignIn;
  final VoidCallback? onLoginSuccess;

  const LoginSheet({
    super.key,
    this.isRankingAction = false,
    this.isFullScreen = false,
    this.closeOnSuccess = true,
    this.initialError,
    required this.onGoogleSignIn,
    required this.onAppleSignIn,
    this.onLoginSuccess,
  });

  @override
  State<LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends State<LoginSheet> {
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _errorMessage = widget.initialError;
  }

  Future<void> _handleSignIn(Future<String?> Function() signInMethod) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final error = await signInMethod();
      if (!mounted) return;

      if (error == null) {
        if (widget.closeOnSuccess) {
          Get.back();
        }
        widget.onLoginSuccess?.call();
        return;
      }

      if (error == 'cancelled') {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '로그인에 실패했어요. 다시 시도해 주세요.';
      });
    }
  }

  Future<void> _openUrl(String url) async {
    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.isFullScreen
        ? BorderRadius.circular(28)
        : const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          );
    final contentItems = [
      if (!widget.isFullScreen) ...[
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: const Icon(
            Icons.person_outline_rounded,
            color: AppColors.ink,
            size: 30,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          widget.isRankingAction ? '로그인하고 랭킹에 참여하세요' : '계정을 연결하고 계속하세요',
          style: AppTypography.title,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          widget.isRankingAction
              ? '기록 저장과 순위 확인을 위해 로그인이 필요합니다.'
              : '기록 저장, 랭킹, 멀티플레이를 같은 계정으로 이어서 사용할 수 있어요.',
          style: AppTypography.body.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.backgroundSoft,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: const Row(
            children: [
              _FeaturePill(
                icon: Icons.bar_chart_rounded,
                label: '랭킹 저장',
              ),
              SizedBox(width: AppSpacing.xs),
              _FeaturePill(
                icon: Icons.history_rounded,
                label: '기록 보관',
              ),
              SizedBox(width: AppSpacing.xs),
              _FeaturePill(
                icon: Icons.groups_rounded,
                label: '멀티플레이',
              ),
            ],
          ),
        ),
      ],
      AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: _errorMessage == null || _errorMessage!.isEmpty
            ? (widget.isFullScreen ? const SizedBox.shrink() : const SizedBox(height: AppSpacing.xl))
            : Padding(
                padding: EdgeInsets.only(
                    top: widget.isFullScreen ? 0 : AppSpacing.md,
                    bottom: widget.isFullScreen ? AppSpacing.xl : 0),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.danger,
                        size: 18,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      if (!widget.isFullScreen) const SizedBox(height: AppSpacing.xl),
      _ProviderButton(
        label: 'Google로 계속하기',
        icon: SizedBox(
          width: 18,
          height: 18,
          child: Image.asset(
            'assets/icons/google_logo.png',
            fit: BoxFit.contain,
          ),
        ),
        onPressed: _isLoading
            ? null
            : () => _handleSignIn(widget.onGoogleSignIn),
        isLoading: _isLoading,
      ),
      if (GetPlatform.isIOS) ...[
        const SizedBox(height: AppSpacing.sm),
        _ProviderButton(
          label: 'Apple로 계속하기',
          icon: const Icon(
            Icons.apple_rounded,
            size: 18,
            color: AppColors.ink,
          ),
          onPressed: _isLoading
              ? null
              : () => _handleSignIn(widget.onAppleSignIn),
        ),
      ],
      const SizedBox(height: AppSpacing.lg),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          _LinkText(
            label: '이용약관',
            onTap: () => _openUrl(AppConfig.termsOfServiceUrl),
          ),
          Text(
            '·',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSubtle,
            ),
          ),
          _LinkText(
            label: '개인정보 처리방침',
            onTap: () => _openUrl(AppConfig.privacyPolicyUrl),
          ),
        ],
      ),
    ];

    final contentWidget = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: contentItems,
      ),
    );

    if (widget.isFullScreen) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 460),
        child: contentWidget,
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: Get.height * 0.88,
          maxWidth: 480,
        ),
        child: AppModalSurface(
          showHandle: true,
          borderRadius: radius,
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: contentWidget,
        ),
      ),
    );
  }
}

class _ProviderButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _ProviderButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: AppColors.ink,
                  strokeWidth: 2.2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: AppSpacing.sm),
                  Text(label, style: AppTypography.button),
                ],
              ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeaturePill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: AppColors.ink),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkText extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _LinkText({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: AppColors.textMuted,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.textMuted,
        ),
      ),
    );
  }
}
