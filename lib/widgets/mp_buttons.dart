import 'package:flutter/material.dart';
import 'package:link_your_area/theme/app_components.dart';
import 'package:link_your_area/theme/app_design_system.dart';

class MpPrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool isLoading;

  const MpPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppActionButton(
      label: label,
      icon: icon,
      isLoading: isLoading,
      onPressed: onPressed,
    );
  }
}

class MpSecondaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  const MpSecondaryButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppActionButton(
      label: label,
      icon: icon,
      tone: AppButtonTone.secondary,
      isLoading: isLoading,
      onPressed: onPressed,
    );
  }
}

class MpAppBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const MpAppBarButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppIconCircleButton(
      icon: icon,
      foregroundColor: AppColors.primary,
      onTap: onPressed,
    );
  }
}
