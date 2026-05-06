import 'package:flutter/material.dart';
import 'package:crush_block/utils/device_utils.dart';
import 'package:get/get.dart';
import 'package:crush_block/constant.dart';
import 'package:crush_block/services/auth_service.dart';
import 'package:crush_block/services/database_service.dart';
import 'package:crush_block/theme/app_components.dart';
import 'package:crush_block/theme/app_design_system.dart';
import 'package:crush_block/theme/app_typography.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  late Future<List<dynamic>> _rankingFuture;

  @override
  void initState() {
    super.initState();
    _rankingFuture = _loadRankingData();
  }

  /// Fetches ranking data from the database.
  Future<List<dynamic>> _loadRankingData() async {
    final dbService = Get.find<DatabaseService>();
    return Future.wait([
      dbService.getMyRank(rankedRatingGameId),
      dbService.getMyRankedSummary(),
      dbService.getLeaderboard(rankedRatingGameId),
    ]);
  }

  void _reloadRanking() {
    setState(() {
      _rankingFuture = _loadRankingData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AuthService authService = Get.find<AuthService>();
    final String? myId = authService.user.value?.id;

    return Container(
      height: Get.height * 0.9,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        border: Border.all(
          color: AppColors.borderSoft,
          width: AppStroke.soft,
        ),
        boxShadow: AppShadows.liftedCard,
      ),
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(
                    top: AppSpacing.sm, bottom: AppSpacing.md),
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    SizedBox(width: AppSpacing.xs),
                    Text(
                      '랭킹전 순위표',
                      style: AppTypography.title,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Text(
                  '현재 티어와 상위 플레이어를 한 번에 확인하세요.',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: DeviceUtils.contentMaxWidth(context)),
                      child: FutureBuilder<List<dynamic>>(
                        future: _rankingFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }

                          if (snapshot.hasError) {
                            return RankingErrorState(onRetry: _reloadRanking);
                          }

                          final data = snapshot.data;
                          final int? myRank = data?[0] as int?;
                          final RankedProfileSummary? mySummary =
                              data?[1] as RankedProfileSummary?;
                          final List<Map<String, dynamic>> scores =
                              List<Map<String, dynamic>>.from(data?[2] ?? []);

                          if (scores.isEmpty) {
                            return const EmptyRankingState();
                          }

                          return Column(
                            children: [
                              const SizedBox(height: AppSpacing.xs),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs,
                                ),
                                child: MyRankCard(
                                  rank: myRank,
                                  summary: mySummary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      '상위 플레이어',
                                      style: AppTypography.label.copyWith(
                                        color: AppColors.textSubtle,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Container(
                                        height: 1,
                                        color: AppColors.borderSoft,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.xs,
                                    0,
                                    AppSpacing.xs,
                                    AppSpacing.sm,
                                  ),
                                  itemCount: scores.length,
                                  itemBuilder: (context, index) {
                                    return RankListItem(
                                      scoreData: scores[index],
                                      index: index,
                                      myId: myId,
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyRankCard extends StatelessWidget {
  final int? rank;
  final RankedProfileSummary? summary;

  const MyRankCard({super.key, this.rank, this.summary});

  @override
  Widget build(BuildContext context) {
    if (rank == null || summary == null) {
      return AppSurface(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(
          child: Text(
            '랭킹전을 플레이해 보세요',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ),
      );
    }

    return AppSurface(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Image.asset(
                summary!.gradeIconPath,
                width: 28,
                height: 28,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(summary!.gradeLabel, style: AppTypography.title),
              const SizedBox(width: AppSpacing.lg),
              Container(
                width: 1,
                height: 20,
                color: AppColors.borderSoft,
              ),
              const SizedBox(width: AppSpacing.lg),
              Text('$rank', style: AppTypography.scoreMedium),
              Text(
                '위',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Container(
                width: 1,
                height: 20,
                color: AppColors.borderSoft,
              ),
              const SizedBox(width: AppSpacing.lg),
              Text('${summary!.points}', style: AppTypography.scoreMedium),
              Text(
                '점수',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _RankProgressBar(summary: summary!),
        ],
      ),
    );
  }
}

class _RankProgressBar extends StatelessWidget {
  final RankedProfileSummary summary;

  const _RankProgressBar({required this.summary});

  @override
  Widget build(BuildContext context) {
    final helperText = summary.isMaxGrade
        ? '최고 티어에 도달했습니다'
        : '다음 ${summary.nextGradeLabel}까지 ${summary.pointsToNextGrade}점';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              helperText,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              summary.isMaxGrade
                  ? '${summary.points}점'
                  : '${summary.pointsIntoGrade}/${summary.pointsInTier}점',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: summary.progressToNextGrade,
            minHeight: 8,
            backgroundColor: AppColors.borderSoft,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }
}

class RankListItem extends StatelessWidget {
  final Map<String, dynamic> scoreData;
  final int index;
  final String? myId;

  const RankListItem({
    super.key,
    required this.scoreData,
    required this.index,
    required this.myId,
  });

  @override
  Widget build(BuildContext context) {
    final profileData = scoreData['profiles'];
    Map<String, dynamic> profiles = {};
    if (profileData is Map<String, dynamic>) {
      profiles = profileData;
    } else if (profileData is Map) {
      profiles = Map<String, dynamic>.from(profileData);
    } else if (profileData is List && profileData.isNotEmpty) {
      final first = profileData.first;
      if (first is Map<String, dynamic>) {
        profiles = first;
      } else if (first is Map) {
        profiles = Map<String, dynamic>.from(first);
      }
    }

    final nickname = profiles['nickname'] ?? '플레이어';
    final rawScore = scoreData['score'];
    final scoreVal = rawScore is num ? rawScore.toInt() : 0;
    final userId = scoreData['user_id'];
    final bool isMe = userId != null && userId == myId;
    final rank = index + 1;

    final bool isTopThree = rank <= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isMe ? AppColors.primarySoft : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isMe
              ? AppColors.primary.withValues(alpha: 0.16)
              : AppColors.borderSoft,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$rank',
                    style: AppTypography.body.copyWith(
                      fontSize: isTopThree ? 18 : 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  TextSpan(
                    text: '위',
                    style: AppTypography.body.copyWith(
                      fontSize: isTopThree ? 11 : 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    '$nickname · ${DatabaseService.gradeLabelForPoints(scoreVal)}',
                    style: AppTypography.body.copyWith(
                      fontSize: isTopThree ? 15 : 14,
                      fontWeight: isMe ? FontWeight.w600 : FontWeight.w500,
                      color: AppColors.ink,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Image.asset(
                  DatabaseService.gradeIconPathForLabel(
                    DatabaseService.gradeLabelForPoints(scoreVal),
                  ),
                  width: 18,
                  height: 18,
                ),
              ],
            ),
          ),
          Text(
            '$scoreVal',
            style: AppTypography.body.copyWith(
              fontSize: isTopThree ? 16 : 14,
              fontWeight: isMe ? FontWeight.w700 : FontWeight.w600,
              color: isTopThree ? AppColors.ink : AppColors.textMuted,
            ),
          ),
        ],
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
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
            TextButton(
              onPressed: onRetry,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}
