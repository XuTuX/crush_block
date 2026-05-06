import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:link_your_area/services/shop_service.dart';
import 'package:link_your_area/theme/app_design_system.dart';
import 'package:link_your_area/theme/app_typography.dart';
import 'package:link_your_area/widgets/brand_assets.dart';
import 'package:link_your_area/widgets/dialogs/custom_dialog.dart';

void showStoreBillingSheet(BuildContext context, ShopService shopService) {
  Get.bottomSheet(
    Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSoft,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _StoreBillingSheet(shopService: shopService),
              ),
            ],
          ),
        ),
      ),
    ),
    isScrollControlled: true,
  );
}

class _StoreBillingSheet extends StatelessWidget {
  final ShopService shopService;

  const _StoreBillingSheet({required this.shopService});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 64),
      physics: const BouncingScrollPhysics(),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '코인 충전',
                  style: AppTypography.title.copyWith(
                    color: AppColors.ink,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '앱스토어 결제로 충전됩니다',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Obx(() {
          final message = shopService.storeBillingMessage.value;
          if (message == null || message.isEmpty) {
            return const SizedBox.shrink();
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }),
        ...ShopService.coinPackageCatalog.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _VerticalCoinPackageCard(item: item),
          ),
        ),
      ],
    );
  }
}

class _VerticalCoinPackageCard extends StatelessWidget {
  final ShopCoinPackage item;

  const _VerticalCoinPackageCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final shopService = Get.find<ShopService>();

    return Obx(() {
      final product = shopService.storeProductForId(item.id);
      final priceLabel =
          product?.price ?? '${_formatNumber(item.estimatedPriceKrw)}원';
      final isPending = shopService.isStorePurchasePending.value;
      final isLoading = shopService.isStoreBillingLoading.value;
      final isSupported = shopService.supportsStoreBilling;
      final isAvailable = shopService.isStoreBillingAvailable.value;
      final isEnabled = !isPending &&
          !isLoading &&
          isSupported &&
          isAvailable &&
          product != null;

      final actionLabel = isPending
          ? '처리 중'
          : isLoading
              ? '로딩 중'
              : !isSupported
                  ? '모바일'
                  : !isAvailable
                      ? '연결 필요'
                      : product == null
                          ? '준비 중'
                          : priceLabel;

      return _ListCardShell(
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.accentLemon.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: AppCoinIcon(size: 32),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CoinAmountLabel(
                    amount: item.coinAmount,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                    iconSize: 22,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.badge,
                    style: AppTypography.tiny.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            _ListActionButton(
              label: actionLabel,
              isSelected: false,
              accentColor: AppColors.accentGold,
              onTap: isEnabled
                  ? () async {
                      final error = await shopService.buyCoinPackage(item.id);
                      if (error != null) {
                        showCustomAlert('알림', error);
                      }
                    }
                  : null,
            ),
          ],
        ),
      );
    });
  }
}

class _CoinAmountLabel extends StatelessWidget {
  final int amount;
  final TextStyle style;
  final double iconSize;

  const _CoinAmountLabel({
    required this.amount,
    required this.style,
    this.iconSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppCoinIcon(size: iconSize),
        const SizedBox(width: 4),
        Text(
          '$amount',
          style: style,
        ),
      ],
    );
  }
}

class _ListCardShell extends StatelessWidget {
  final Widget child;

  const _ListCardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ListActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isSelected;
  final Color accentColor;

  const _ListActionButton({
    required this.label,
    required this.onTap,
    this.isSelected = false,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;

    if (isSelected) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.check_rounded, size: 16, color: AppColors.textMuted),
        ],
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDisabled ? Colors.transparent : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: isDisabled ? AppColors.textSubtle : AppColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

String _formatNumber(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final reverseIndex = raw.length - i;
    buffer.write(raw[i]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}
