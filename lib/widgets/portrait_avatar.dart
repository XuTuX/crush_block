import 'package:flutter/material.dart';
import 'package:link_your_area/theme/app_design_system.dart';

class PortraitAvatar extends StatelessWidget {
  final String? assetPath;
  final double size;
  final Color accentColor;
  final double borderWidth;
  final double glowOpacity;
  final BoxFit fit;

  const PortraitAvatar({
    super.key,
    required this.assetPath,
    required this.size,
    required this.accentColor,
    this.borderWidth = 2,
    this.glowOpacity = 0.16,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.backgroundSoft,
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: assetPath == null
            ? Icon(
                Icons.person_rounded,
                size: size * 0.46,
                color: AppColors.ink,
              )
            : Image.asset(
                assetPath!,
                width: size,
                height: size,
                fit: fit,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.person_rounded,
                  size: size * 0.46,
                  color: AppColors.ink,
                ),
              ),
      ),
    );
  }
}
