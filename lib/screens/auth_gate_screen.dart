import 'package:link_your_area/screens/home_screen.dart';
import 'package:link_your_area/services/auth_service.dart';
import 'package:link_your_area/theme/app_components.dart';
import 'package:link_your_area/theme/app_design_system.dart';
import 'package:link_your_area/theme/app_typography.dart';
import 'package:link_your_area/widgets/home_screen/background_painter.dart';
import 'package:link_your_area/widgets/home_screen/home_components.dart';
import 'package:link_your_area/widgets/home_screen/login_sheet.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AuthGateScreen extends StatelessWidget {
  const AuthGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Get.find<AuthService>();

    return Obx(() {
      if (!authService.isAuthReady.value) {
        return const _AuthLoadingScreen();
      }

      if (authService.user.value == null) {
        return LoginScreen(
          onGoogleSignIn: authService.signInWithGoogle,
          onAppleSignIn: authService.signInWithApple,
        );
      }

      return const HomeScreen();
    });
  }
}

class LoginScreen extends StatelessWidget {
  final Future<String?> Function() onGoogleSignIn;
  final Future<String?> Function() onAppleSignIn;

  const LoginScreen({
    super.key,
    required this.onGoogleSignIn,
    required this.onAppleSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: GridPatternPainter()),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppSurface(
                              elevated: true,
                              padding: const EdgeInsets.all(AppSpacing.xl),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const HomeLogo(),
                                  const SizedBox(height: AppSpacing.xl),
                                  const Text(
                                    'Crush Block',
                                    textAlign: TextAlign.center,
                                    style: AppTypography.headline,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    '간결한 인터페이스로 기록을 저장하고,\n랭킹과 멀티플레이를 이어서 즐기세요.',
                                    textAlign: TextAlign.center,
                                    style: AppTypography.body.copyWith(
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xl),
                                  LoginSheet(
                                    isFullScreen: true,
                                    closeOnSuccess: false,
                                    onGoogleSignIn: onGoogleSignIn,
                                    onAppleSignIn: onAppleSignIn,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            color: AppColors.ink,
            strokeWidth: 2.6,
          ),
        ),
      ),
    );
  }
}
