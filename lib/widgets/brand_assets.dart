import 'package:flutter/material.dart';
import 'package:crush_block/theme/app_design_system.dart';

const String kAppBrandIconAsset =
    'assets/icons/crush_block_logo_transparent.png';
const String kAreaCoinIconAsset = 'assets/icons/Area_coin.png';

class AppBrandLogo extends StatelessWidget {
  final double size;

  const AppBrandLogo({
    super.key,
    this.size = 144,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        kAppBrandIconAsset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class AppCoinIcon extends StatelessWidget {
  final double size;

  const AppCoinIcon({
    super.key,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.accentGold.withValues(alpha: 0.18),
            blurRadius: size * 0.35,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: Image.asset(
        kAreaCoinIconAsset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
