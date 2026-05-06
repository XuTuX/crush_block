import 'package:crush_block/models/portrait_item.dart';
import 'package:crush_block/services/shop_service.dart';
import 'package:crush_block/models/character_item.dart';
import 'package:crush_block/theme/app_design_system.dart';
import 'package:crush_block/theme/app_typography.dart';
import 'package:crush_block/utils/device_utils.dart';
import 'package:crush_block/widgets/brand_assets.dart';
import 'package:crush_block/widgets/dialogs/custom_dialog.dart';
import 'package:crush_block/widgets/home_screen/background_painter.dart';
import 'package:crush_block/widgets/store_billing_sheet.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.4,
              child: CustomPaint(painter: GridPatternPainter()),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: const ShopContent(showHeader: true),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ShopContent extends StatelessWidget {
  final bool showHeader;

  const ShopContent({
    super.key,
    this.showHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final shopService = Get.find<ShopService>();

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          _ShopHeader(
            showBackButton: showHeader,
            shopService: shopService,
          ),
          const SizedBox(height: 2),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            labelPadding: const EdgeInsets.symmetric(horizontal: 16),
            labelStyle: AppTypography.body.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
            unselectedLabelStyle: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
            indicatorColor: AppColors.ink,
            indicatorWeight: 3,
            indicatorPadding: const EdgeInsets.symmetric(vertical: 4),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: '아바타'),
              Tab(text: '블록 테마'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildGridView(
                  items: ShopService.portraitCatalog,
                  builder: (item) => _GridPortraitCard(item: item),
                ),
                _buildGridView(
                  items: [
                    null,
                    ...ShopService.characterCatalog,
                  ],
                  builder: (item) => item == null
                      ? const _GridDefaultCharacterCard()
                      : _GridCharacterCard(item: item),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView<T>({
    required List<T> items,
    required Widget Function(T item) builder,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = DeviceUtils.shopGridColumns(context);
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 64),
          physics: const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: columns > 3 ? 0.88 : 0.84,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => builder(items[index]),
        );
      },
    );
  }
}

class _GridDefaultCharacterCard extends StatelessWidget {
  const _GridDefaultCharacterCard();

  @override
  Widget build(BuildContext context) {
    final shopService = Get.find<ShopService>();
    return Obx(() {
      final equipped = shopService.equippedCharacterId.value.isEmpty;

      return GestureDetector(
        onTap: () async {
          final error = await shopService.equipCharacter('');
          if (error != null) {
            showCustomAlert('알림', error);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: equipped
                ? Border.all(
                    color: AppColors.ink,
                    width: 1.5,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _CardStatusBadge(
                label: equipped ? '적용됨' : '보유',
                icon: equipped ? null : Icons.check_circle_rounded,
                foregroundColor: equipped ? AppColors.ink : AppColors.success,
                backgroundColor:
                    equipped ? AppColors.accentLemon : AppColors.successSoft,
                outlined: equipped,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    });
  }
}

class _ShopHeader extends StatelessWidget {
  final bool showBackButton;
  final ShopService shopService;

  const _ShopHeader({
    required this.showBackButton,
    required this.shopService,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        showBackButton ? 16 : 18,
        24,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showBackButton) ...[
            _CircleIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: Get.back,
            ),
            const SizedBox(width: 16),
          ],
          const Spacer(),
          _CoinBadge(shopService: shopService),
        ],
      ),
    );
  }
}

class _GridCharacterCard extends StatelessWidget {
  final CharacterItem item;

  const _GridCharacterCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final shopService = Get.find<ShopService>();
    return Obx(() {
      final owned = shopService.ownsCharacter(item.id);
      final equipped = shopService.equippedCharacterId.value == item.id;

      return GestureDetector(
        onTap: () async {
          if (!owned) {
            if (item.price == 0) {
              final purchaseError =
                  await shopService.purchaseCharacter(item.id);
              if (purchaseError != null) {
                showCustomAlert('알림', purchaseError);
                return;
              }
              final equipError = await shopService.equipCharacter(item.id);
              if (equipError != null) {
                showCustomAlert('알림', equipError);
              }
            } else {
              showCustomConfirm(
                '토큰 구매',
                '${item.name}을(를) 구매하시겠습니까?',
                () async {
                  final error = await shopService.purchaseCharacter(item.id);
                  if (error != null) {
                    showCustomAlert('알림', error);
                    return;
                  }
                  final equipError = await shopService.equipCharacter(item.id);
                  if (equipError != null) {
                    showCustomAlert('알림', equipError);
                  }
                },
                confirmText: '구매',
              );
            }
          } else {
            final error = await shopService.equipCharacter(item.id);
            if (error != null) {
              showCustomAlert('알림', error);
            }
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: equipped
                ? Border.all(
                    color: AppColors.ink,
                    width: 1.5,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: Image.asset(
                    item.tokenAsset,
                    width: 44,
                    height: 44,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              if (equipped)
                const _CardStatusBadge(
                  label: '적용됨',
                  backgroundColor: AppColors.accentLemon,
                  foregroundColor: AppColors.ink,
                  outlined: true,
                )
              else if (!owned)
                item.price == 0
                    ? const _CardStatusBadge(
                        label: '무료',
                        backgroundColor: AppColors.surfaceMuted,
                        foregroundColor: AppColors.ink,
                        outlined: true,
                      )
                    : _CoinAmountLabel(
                        amount: item.price,
                        style: AppTypography.label.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      )
              else
                const _CardStatusBadge(
                  label: '보유',
                  icon: Icons.check_circle_rounded,
                  backgroundColor: AppColors.successSoft,
                  foregroundColor: AppColors.success,
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    });
  }
}

class _GridPortraitCard extends StatelessWidget {
  final PortraitItem item;

  const _GridPortraitCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final shopService = Get.find<ShopService>();
    return Obx(() {
      final owned = shopService.ownsPortrait(item.id);
      final equipped = shopService.equippedPortraitId.value == item.id;
      final needsLogin = !owned && item.price > 0 && !shopService.canPurchase;

      return GestureDetector(
        onTap: needsLogin
            ? null
            : () async {
                if (!owned) {
                  if (item.price == 0) {
                    final purchaseError =
                        await shopService.purchasePortrait(item.id);
                    if (purchaseError != null) {
                      showCustomAlert('알림', purchaseError);
                      return;
                    }
                    final equipError = await shopService.equipPortrait(item.id);
                    if (equipError != null) {
                      showCustomAlert('알림', equipError);
                    }
                  } else {
                    showCustomConfirm(
                      '아바타 획득',
                      '${item.name}을(를) 구매하시겠습니까?\n${item.price} 코인이 소모됩니다.',
                      () async {
                        final error =
                            await shopService.purchasePortrait(item.id);
                        if (error != null) {
                          showCustomAlert('알림', error);
                          return;
                        }
                        final equipError =
                            await shopService.equipPortrait(item.id);
                        if (equipError != null) {
                          showCustomAlert('알림', equipError);
                        }
                      },
                      confirmText: '구매',
                    );
                  }
                } else {
                  final error = await shopService.equipPortrait(item.id);
                  if (error != null) {
                    showCustomAlert('알림', error);
                  }
                }
              },
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: equipped
                ? Border.all(
                    color: AppColors.ink,
                    width: 1.5,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.ink.withValues(alpha: 0.05),
                          blurRadius: 10,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      item.assetPath,
                      width: 72,
                      height: 72,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.person_rounded,
                        size: 40,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              if (equipped)
                const _CardStatusBadge(
                  label: '적용됨',
                  backgroundColor: AppColors.accentLemon,
                  foregroundColor: AppColors.ink,
                  outlined: true,
                )
              else if (!owned)
                needsLogin
                    ? const _CardStatusBadge(
                        label: '로그인',
                        backgroundColor: AppColors.surfaceMuted,
                        foregroundColor: AppColors.ink,
                        outlined: true,
                      )
                    : item.price == 0
                        ? const _CardStatusBadge(
                            label: '무료',
                            backgroundColor: AppColors.surfaceMuted,
                            foregroundColor: AppColors.ink,
                            outlined: true,
                          )
                        : _CoinAmountLabel(
                            amount: item.price,
                            style: AppTypography.label.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          )
              else
                const _CardStatusBadge(
                  label: '보유',
                  icon: Icons.check_circle_rounded,
                  backgroundColor: AppColors.successSoft,
                  foregroundColor: AppColors.success,
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    });
  }
}

class _CardStatusBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool outlined;

  const _CardStatusBadge({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.icon,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: outlined
            ? Border.all(
                color: AppColors.ink.withValues(alpha: 0.12),
              )
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foregroundColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.label.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinAmountLabel extends StatelessWidget {
  final int amount;
  final TextStyle style;

  const _CoinAmountLabel({
    required this.amount,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accentLemon.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.accentGold.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const AppCoinIcon(size: 18),
          const SizedBox(width: 5),
          Text(
            '$amount',
            style: style.copyWith(height: 1),
          ),
        ],
      ),
    );
  }
}

class _CoinBadge extends StatelessWidget {
  final ShopService shopService;

  const _CoinBadge({required this.shopService});

  void _openBillingSheet(BuildContext context) {
    showStoreBillingSheet(context, shopService);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isPending = shopService.isStorePurchasePending.value;
      final isLoading = shopService.isStoreBillingLoading.value;
      final canCharge = shopService.supportsStoreBilling &&
          shopService.isStoreBillingAvailable.value;
      final chargeLabel = isPending
          ? '처리 중'
          : isLoading
              ? '확인 중'
              : canCharge
                  ? '충전'
                  : '추가';

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => _openBillingSheet(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppCoinIcon(size: 22),
                  const SizedBox(width: 8),
                  Text(
                    '${shopService.coins.value}',
                    style: AppTypography.body.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _openBillingSheet(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.accentLemon.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.accentGold.withValues(alpha: 0.24),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.add_rounded,
                    size: 15,
                    color: AppColors.ink,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    chargeLabel,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: Icon(
          icon,
          size: 22,
          color: AppColors.ink,
        ),
      ),
    );
  }
}
