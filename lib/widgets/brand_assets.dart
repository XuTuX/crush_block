import 'package:flutter/material.dart';
import 'package:crush_block/theme/app_design_system.dart';

const String kAppBrandIconAsset =
    'assets/icons/crush_block_logo_transparent.png';

class AppBrandLogo extends StatelessWidget {
  final double size;

  const AppBrandLogo({
    super.key,
    this.size = 144,
  });

  @override
  Widget build(BuildContext context) {
    final blockSize = size * 0.6;
    final borderWidth = size < 96 ? 2.5 : 3.2;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: size * 0.22,
            top: size * 0.22,
            child: _LogoBlock(
              color: AppColors.areaPalette[4],
              size: blockSize,
              borderWidth: borderWidth,
            ),
          ),
          Positioned(
            left: size * 0.11,
            top: size * 0.11,
            child: _LogoBlock(
              color: AppColors.areaPalette[1],
              size: blockSize,
              borderWidth: borderWidth,
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: _LogoBlock(
              color: AppColors.areaPalette[0],
              size: blockSize,
              borderWidth: borderWidth,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoBlock extends StatelessWidget {
  final Color color;
  final double size;
  final double borderWidth;

  const _LogoBlock({
    required this.color,
    required this.size,
    required this.borderWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(
          color: AppColors.ink,
          width: borderWidth,
        ),
      ),
    );
  }
}
