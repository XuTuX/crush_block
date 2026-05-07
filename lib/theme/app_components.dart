import 'package:flutter/material.dart';
import 'package:crush_block/theme/app_design_system.dart';
import 'package:crush_block/theme/app_typography.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppButtonTone {
  primary,
  secondary,
  reward,
  destructive,
}

class AppSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final bool elevated;
  final bool outlined;
  final double radius;
  final Clip clipBehavior;

  const AppSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color = AppColors.surface,
    this.elevated = false,
    this.outlined = false,
    this.radius = AppRadius.lg,
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.card(
        color: color,
        radius: radius,
        lifted: elevated,
        outlined: outlined,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: clipBehavior,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class AppActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final AppButtonTone tone;
  final double height;
  final Color? backgroundColor;

  const AppActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.tone = AppButtonTone.primary,
    this.height = 56,
    this.backgroundColor,
  });

  bool get _enabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: _HardShadowButton(
        enabled: _enabled,
        onPressed: onPressed,
        backgroundColor: _backgroundColor.withValues(alpha: _enabled ? 1 : 0.5),
        radius: AppRadius.lg,
        shadowOffset: 3,
        child: _ButtonContent(
          label: label,
          icon: icon,
          isLoading: isLoading,
          color: _foregroundColor.withValues(alpha: _enabled ? 1 : 0.7),
        ),
      ),
    );
  }

  Color get _backgroundColor {
    if (backgroundColor != null) return backgroundColor!;
    return switch (tone) {
      AppButtonTone.primary => AppColors.tileAmber,
      AppButtonTone.secondary => AppColors.surface,
      AppButtonTone.reward => AppColors.reward,
      AppButtonTone.destructive => AppColors.dangerSoft,
    };
  }

  Color get _foregroundColor {
    return switch (tone) {
      AppButtonTone.primary => AppColors.ink,
      AppButtonTone.secondary => AppColors.ink,
      AppButtonTone.reward => AppColors.ink,
      AppButtonTone.destructive => AppColors.dangerStrong,
    };
  }
}

class _HardShadowButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool enabled;
  final Color backgroundColor;
  final double radius;
  final double shadowOffset;

  const _HardShadowButton({
    required this.child,
    required this.onPressed,
    required this.enabled,
    required this.backgroundColor,
    required this.radius,
    required this.shadowOffset,
  });

  @override
  State<_HardShadowButton> createState() => _HardShadowButtonState();
}

class _HardShadowButtonState extends State<_HardShadowButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final offset = _pressed ? 1.5 : widget.shadowOffset;

    return Semantics(
      button: true,
      enabled: widget.enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        onTap: widget.enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _pressed ? 0.985 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(widget.radius),
              border: Border.all(
                color: AppColors.ink,
                width: AppStroke.strong,
              ),
              boxShadow: AppShadows.hard(offset: offset),
            ),
            child: Center(child: widget.child),
          ),
        ),
      ),
    );
  }
}

class _ButtonContent extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isLoading;
  final Color color;

  const _ButtonContent({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          color: color,
          strokeWidth: 2.2,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.xs),
        ],
        Text(
          label,
          style: GoogleFonts.blackHanSans(
            color: color,
            fontSize: 18,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class AppIconCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color backgroundColor;
  final Color foregroundColor;
  final Widget? child;

  const AppIconCircleButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 44,
    this.backgroundColor = AppColors.surface,
    this.foregroundColor = AppColors.ink,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.round),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.ink,
              width: AppStroke.strong,
            ),
            boxShadow: AppShadows.hard(offset: 2),
          ),
          child: Center(
            child: child ?? Icon(icon, size: 20, color: foregroundColor),
          ),
        ),
      ),
    );
  }
}

class AppModalSurface extends StatelessWidget {
  final Widget child;
  final bool showHandle;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry? borderRadius;
  final bool elevated;

  const AppModalSurface({
    super.key,
    required this.child,
    this.showHandle = false,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.borderRadius,
    this.elevated = true,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ??
        const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: radius,
        border: Border.all(
          color: AppColors.ink,
          width: AppStroke.strong,
        ),
        boxShadow: elevated ? AppShadows.liftedCard : AppShadows.softCard,
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showHandle)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderSoft,
                      borderRadius: BorderRadius.circular(AppRadius.round),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: padding,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class AppTextInput extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final Widget? suffixIcon;
  final String? helperText;
  final String? errorText;
  final bool enabled;

  const AppTextInput({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.suffixIcon,
    this.helperText,
    this.errorText,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          enabled: enabled,
          style: AppTypography.body,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hintText,
            suffixIcon: suffixIcon,
            errorText: errorText,
          ),
        ),
        if (helperText != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              top: AppSpacing.xs,
            ),
            child: Text(
              helperText!,
              style: AppTypography.caption.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
      ],
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const AppSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.subtitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class AppListRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color titleColor;
  final Color iconTint;

  const AppListRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor = AppColors.ink,
    this.iconTint = AppColors.ink,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
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
                child: Icon(icon, size: 18, color: iconTint),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.body.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AppScreenHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final Widget? trailing;

  const AppScreenHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppIconCircleButton(
          icon: Icons.arrow_back_rounded,
          onTap: onBack,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.title),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
