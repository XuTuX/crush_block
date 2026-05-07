import 'package:crush_block/constant.dart';
import 'package:crush_block/services/database_service.dart';
import 'package:crush_block/theme/app_components.dart';
import 'package:crush_block/theme/app_design_system.dart';
import 'package:crush_block/theme/app_typography.dart';
import 'package:crush_block/utils/device_utils.dart';
import 'package:crush_block/widgets/home_screen/background_painter.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  late Future<List<LeaderboardEntry>> _rankingFuture;

  @override
  void initState() {
    super.initState();
    _rankingFuture = _loadRankingData();
  }

  Future<List<LeaderboardEntry>> _loadRankingData() {
    return Get.find<DatabaseService>().getMatchLeaderboard(gameId);
  }

  void _reloadRanking() {
    setState(() {
      _rankingFuture = _loadRankingData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: '뒤로가기',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: Get.back,
        ),
        title: const Text('랭킹', style: AppTypography.subtitle),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: GridPatternPainter()),
          ),
          SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: DeviceUtils.contentMaxWidth(context),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: FutureBuilder<List<LeaderboardEntry>>(
                    future: _rankingFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: AppColors.ink,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return RankingErrorState(onRetry: _reloadRanking);
                      }

                      final entries =
                          snapshot.data ?? const <LeaderboardEntry>[];
                      if (entries.isEmpty) {
                        return const EmptyRankingState();
                      }

                      return AppSurface(
                        radius: 16,
                        padding: EdgeInsets.zero,
                        elevated: true,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SingleChildScrollView(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: 680,
                                child: Column(
                                  children: [
                                    const _RankingHeader(),
                                    const Divider(
                                      height: 1,
                                      color: AppColors.ink,
                                    ),
                                    for (var i = 0;
                                        i < entries.length;
                                        i += 1) ...[
                                      _RankingRow(
                                        rank: i + 1,
                                        entry: entries[i],
                                      ),
                                      if (i != entries.length - 1)
                                        const Divider(
                                          height: 1,
                                          color: AppColors.borderSoft,
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingHeader extends StatelessWidget {
  const _RankingHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.areaPalette[2],
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: const Row(
        children: [
          _HeaderCell('순위', width: 58),
          _HeaderCell('닉네임', flex: 1),
          _HeaderCell('승리 수', width: 76),
          _HeaderCell('패배 수', width: 76),
          _HeaderCell('승률', width: 74),
          _HeaderCell('최근 경기 결과', width: 150),
        ],
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;

  const _RankingRow({
    required this.rank,
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    final winRate = '${(entry.winRate * 100).round()}%';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          _ValueCell('$rank', width: 58, strong: rank <= 3),
          _ValueCell(entry.nickname, flex: 1, strong: rank <= 3),
          _ValueCell('${entry.wins}', width: 76),
          _ValueCell('${entry.losses}', width: 76),
          _ValueCell(winRate, width: 74),
          SizedBox(
            width: 150,
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: entry.recentResults.isEmpty
                  ? [
                      Text(
                        '-',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ]
                  : entry.recentResults
                      .map((result) => _ResultPill(result: result))
                      .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final double? width;
  final int? flex;

  const _HeaderCell(
    this.label, {
    this.width,
    this.flex,
  });

  @override
  Widget build(BuildContext context) {
    final child = Text(
      label,
      style: AppTypography.label.copyWith(color: AppColors.textMuted),
    );

    if (flex != null) return Expanded(flex: flex!, child: child);
    return SizedBox(width: width, child: child);
  }
}

class _ValueCell extends StatelessWidget {
  final String value;
  final double? width;
  final int? flex;
  final bool strong;

  const _ValueCell(
    this.value, {
    this.width,
    this.flex,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.bodySmall.copyWith(
        color: AppColors.ink,
        fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
      ),
    );

    if (flex != null) return Expanded(flex: flex!, child: child);
    return SizedBox(width: width, child: child);
  }
}

class _ResultPill extends StatelessWidget {
  final String result;

  const _ResultPill({required this.result});

  @override
  Widget build(BuildContext context) {
    final color = switch (result) {
      '승' => AppColors.primary,
      '패' => AppColors.danger,
      _ => AppColors.textMuted,
    };

    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Text(
        result,
        style: AppTypography.tiny.copyWith(color: color),
      ),
    );
  }
}

class EmptyRankingState extends StatelessWidget {
  const EmptyRankingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '아직 랭킹 데이터가 없습니다',
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class RankingErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const RankingErrorState({
    super.key,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '랭킹 정보를 불러오지 못했습니다',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppActionButton(
            label: '다시 시도',
            icon: Icons.refresh_rounded,
            tone: AppButtonTone.secondary,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
