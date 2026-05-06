import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';

import '../constant.dart';

class RankedProfileSummary {
  final int points;
  final int gradeNumber;
  final String gradeLabel;
  final int gradeFloor;
  final int nextGradeAt;
  final int pointsIntoGrade;
  final int pointsToNextGrade;
  final double progressToNextGrade;
  final bool isMaxGrade;
  final String? nextGradeLabel;
  final int pointsInTier; // Added to support variable tier sizes
  final String gradeIconPath;

  const RankedProfileSummary({
    required this.points,
    required this.gradeNumber,
    required this.gradeLabel,
    required this.gradeFloor,
    required this.nextGradeAt,
    required this.pointsIntoGrade,
    required this.pointsToNextGrade,
    required this.progressToNextGrade,
    required this.isMaxGrade,
    required this.nextGradeLabel,
    required this.pointsInTier,
    required this.gradeIconPath,
  });
}

class RankedMatchResult {
  final int delta;
  final int beforePoints;
  final int afterPoints;
  final RankedProfileSummary beforeSummary;
  final RankedProfileSummary afterSummary;

  const RankedMatchResult({
    required this.delta,
    required this.beforePoints,
    required this.afterPoints,
    required this.beforeSummary,
    required this.afterSummary,
  });

  bool get promoted => afterSummary.gradeNumber < beforeSummary.gradeNumber;
  bool get demoted => afterSummary.gradeNumber > beforeSummary.gradeNumber;
}

class TierDefinition {
  final String label;
  final int minPoints;
  const TierDefinition(this.label, this.minPoints);
}

class DatabaseService extends GetxService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final rankedSummaryRefreshToken = 0.obs;
  final myRankedSummary = Rxn<RankedProfileSummary>();

  static const List<TierDefinition> _tierConfigs = [
    TierDefinition('챌린저', 1001),
    TierDefinition('다이아 I', 834),
    TierDefinition('다이아 II', 668),
    TierDefinition('다이아 III', 501),
    TierDefinition('골드 I', 401),
    TierDefinition('골드 II', 301),
    TierDefinition('골드 III', 201),
    TierDefinition('실버 I', 168),
    TierDefinition('실버 II', 134),
    TierDefinition('실버 III', 101),
    TierDefinition('브론즈 I', 68),
    TierDefinition('브론즈 II', 34),
    TierDefinition('브론즈 III', 0),
  ];

  static const int rankedWinPoints = 10;
  static const int rankedLossPoints = -7;
  static const int rankedDrawPoints = 0;

  static int normalizedRankPoints(int points) => points < 0 ? 0 : points;

  static TierDefinition _getTierForPoints(int points) {
    final normalized = normalizedRankPoints(points);
    for (var tier in _tierConfigs) {
      if (normalized >= tier.minPoints) {
        return tier;
      }
    }
    return _tierConfigs.last;
  }

  static String gradeLabelForPoints(int points) {
    return _getTierForPoints(points).label;
  }

  static int gradeNumberForPoints(int points) {
    final label = gradeLabelForPoints(points);
    for (int i = 0; i < _tierConfigs.length; i++) {
      if (_tierConfigs[i].label == label) {
        return i + 1; // 1: Challenger, 5: Bronze
      }
    }
    return _tierConfigs.length;
  }

  static String gradeIconPathForLabel(String label) {
    if (label.contains('챌린저')) return 'assets/icons/ranks/challenger.png';
    if (label.contains('다이아')) return 'assets/icons/ranks/diamond.png';
    if (label.contains('골드')) return 'assets/icons/ranks/gold.png';
    if (label.contains('실버')) return 'assets/icons/ranks/silver.png';
    if (label.contains('브론즈')) return 'assets/icons/ranks/bronze.png';
    return 'assets/icons/ranks/bronze.png';
  }

  static RankedProfileSummary buildRankedSummary(int points) {
    final normalized = normalizedRankPoints(points);
    final currentTier = _getTierForPoints(normalized);
    final currentTierIndex = _tierConfigs.indexOf(currentTier);
    final isMaxGrade = currentTierIndex == 0; // Challenger is index 0

    final gradeLabel = currentTier.label;
    final gradeNumber = currentTierIndex + 1;
    final gradeFloor = currentTier.minPoints;

    int nextGradeAt = gradeFloor;
    String? nextGradeLabel;
    int pointsInTier = 0;

    if (!isMaxGrade) {
      final nextTier = _tierConfigs[currentTierIndex - 1];
      nextGradeAt = nextTier.minPoints;
      nextGradeLabel = nextTier.label;
      pointsInTier = nextGradeAt - gradeFloor;
    }

    final pointsIntoGrade = normalized - gradeFloor;
    final pointsToNextGrade = isMaxGrade ? 0 : nextGradeAt - normalized;
    final progressToNextGrade = isMaxGrade
        ? 1.0
        : (pointsIntoGrade / pointsInTier).clamp(0.0, 1.0).toDouble();

    return RankedProfileSummary(
      points: normalized,
      gradeNumber: gradeNumber,
      gradeLabel: gradeLabel,
      gradeFloor: gradeFloor,
      nextGradeAt: nextGradeAt,
      pointsIntoGrade: pointsIntoGrade,
      pointsToNextGrade: pointsToNextGrade,
      progressToNextGrade: progressToNextGrade,
      isMaxGrade: isMaxGrade,
      nextGradeLabel: nextGradeLabel,
      pointsInTier: pointsInTier,
      gradeIconPath: gradeIconPathForLabel(gradeLabel),
    );
  }

  void _notifyRankedSummaryChanged(String gameId) {
    if (gameId == rankedRatingGameId) {
      rankedSummaryRefreshToken.value++;
      getMyRankedSummary(); // Update cache when notified
    }
  }

  Future<void> _saveSingleScoreRow({
    required String userId,
    required String gameId,
    required int score,
  }) async {
    final existingRows = List<Map<String, dynamic>>.from(
      await _supabase
          .from('scores')
          .select('id')
          .eq('user_id', userId)
          .eq('game_id', gameId)
          .order('updated_at', ascending: false)
          .order('id', ascending: false),
    );

    final payload = {
      'user_id': userId,
      'game_id': gameId,
      'score': score,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (existingRows.isEmpty) {
      await _supabase.from('scores').insert(payload);
      return;
    }

    final primaryId = existingRows.first['id'];
    await _supabase.from('scores').update(payload).eq('id', primaryId);

    if (existingRows.length > 1) {
      final duplicateIds = existingRows
          .skip(1)
          .map((row) => row['id'])
          .whereType<int>()
          .toList();
      if (duplicateIds.isNotEmpty) {
        await _supabase.from('scores').delete().inFilter('id', duplicateIds);
      }
    }
  }

  Map<String, dynamic>? _extractProfileMap(dynamic profileData) {
    if (profileData is Map<String, dynamic>) return profileData;
    if (profileData is Map) {
      return Map<String, dynamic>.from(profileData);
    }
    if (profileData is List && profileData.isNotEmpty) {
      final first = profileData.first;
      if (first is Map<String, dynamic>) return first;
      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
    }
    return null;
  }

  // 특정 게임의 내 최고 점수 가져오기
  Future<int?> getMyBestScore(String gameId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _supabase
          .from('scores')
          .select('score')
          .eq('user_id', userId)
          .eq('game_id', gameId)
          .order('score', ascending: false)
          .limit(1)
          .maybeSingle();

      final score = response?['score'];
      if (score is int) return score;
      if (score is num) return score.toInt();
      return null;
    } catch (e) {
      debugPrint('🔴 Error fetching best score: $e');
      return null;
    }
  }

  // 점수 저장 (최고 점수 갱신 로직)
  Future<void> saveScore(String gameId, int newScore) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _saveSingleScoreRow(
        userId: userId,
        gameId: gameId,
        score: newScore,
      );
      _notifyRankedSummaryChanged(gameId);

      debugPrint('🟢 Score saved: $newScore');
    } catch (e) {
      debugPrint('🔴 Error saving score: $e');
    }
  }

  Future<int> getCurrentScore(String gameId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final response = await _supabase
          .from('scores')
          .select('score, updated_at')
          .eq('user_id', userId)
          .eq('game_id', gameId)
          .order('updated_at', ascending: false)
          .order('score', ascending: false)
          .limit(1)
          .maybeSingle();

      final score = response?['score'];
      if (score is int) return score;
      if (score is num) return score.toInt();
      return 0;
    } catch (e) {
      debugPrint('🔴 Error fetching current score: $e');
      return 0;
    }
  }

  Future<void> setCurrentScore(String gameId, int score) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _saveSingleScoreRow(
        userId: userId,
        gameId: gameId,
        score: score,
      );
      _notifyRankedSummaryChanged(gameId);
    } catch (e) {
      debugPrint('🔴 Error setting score: $e');
    }
  }

  Future<RankedMatchResult> applyRankedMatchResult(bool? won) async {
    final int delta = switch (won) {
      true => rankedWinPoints,
      false => rankedLossPoints,
      null => rankedDrawPoints,
    };
    final current = await getCurrentScore(rankedRatingGameId);
    final next = (current + delta).clamp(0, 999999).toInt();
    await setCurrentScore(rankedRatingGameId, next);

    return RankedMatchResult(
      delta: next - current,
      beforePoints: current,
      afterPoints: next,
      beforeSummary: buildRankedSummary(current),
      afterSummary: buildRankedSummary(next),
    );
  }

  Future<RankedProfileSummary> getMyRankedSummary() async {
    final points = await getCurrentScore(rankedRatingGameId);
    final summary = buildRankedSummary(points);
    myRankedSummary.value = summary;
    return summary;
  }

  // 나의 순위 가져오기
  Future<int?> getMyRank(String gameId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    // 1. 내 최고 점수 가져오기
    final myBest = await getMyBestScore(gameId);
    if (myBest == null) return null;

    // 2. 나보다 높은 점수 개수 세기 (count)
    final count = await _supabase
        .from('scores')
        .count(CountOption.exact)
        .gt('score', myBest)
        .eq('game_id', gameId);

    // 3. 순위 = (나보다 높은 사람 수) + 1
    return count + 1;
  }

  // 리더보드 가져오기 (클라이언트 사이드 중복 제거 포함)
  Future<List<Map<String, dynamic>>> getLeaderboard(String gameId) async {
    try {
      // 1. 중복을 감안하여 넉넉하게 데이터 가져오기 (상위 100개)
      final response = await _supabase
          .from('scores')
          .select('user_id, score, profiles(nickname, avatar_url)')
          .eq('game_id', gameId)
          .order('score', ascending: false)
          .limit(100);

      final List<Map<String, dynamic>> rawList =
          List<Map<String, dynamic>>.from(response);

      // 2. user_id 기준으로 중복 제거 (이미 정렬되어 있으므로 첫 번째가 최고점) and FILTER null nicknames
      final Map<String, Map<String, dynamic>> uniqueScores = {};
      for (var item in rawList) {
        final userId = item['user_id'] as String?;
        final profile = _extractProfileMap(item['profiles']);
        final nickname = profile?['nickname'];
        final score = item['score'];

        // Skip if user has no nickname
        if (nickname == null || score is! num) continue;

        if (userId != null && !uniqueScores.containsKey(userId)) {
          uniqueScores[userId] = item;
        }
      }

      // 3. 상위 50개만 반환
      return uniqueScores.values.take(50).toList();
    } catch (e) {
      debugPrint('🔴 Error fetching leaderboard: $e');
      return [];
    }
  }

  // 닉네임 설정/업데이트
  Future<String?> updateNickname(String nickname) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return '로그인이 필요합니다.';

    try {
      await _supabase.from('profiles').upsert({
        'id': userId,
        'nickname': nickname,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return null; // Success
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        return '이미 사용 중인 닉네임입니다. \n다른 닉네임을 선택해주세요.';
      }
      return '닉네임 업데이트 중 오류가 발생했습니다: ${e.message}';
    } catch (e) {
      return '알 수 없는 오류가 발생했습니다.';
    }
  }

  /// Check if a nickname is available (not taken by another user)
  Future<bool> checkNicknameAvailable(String nickname) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id')
          .eq('nickname', nickname)
          .maybeSingle();

      // If response is null, no user with this nickname exists -> Available
      return response == null;
    } catch (e) {
      // On error, assume unavailable to be safe, or available?
      // Let's assume unavailable to prevent potential conflicts if DB acts up.
      // actually, let's just return false to act safe.
      return false;
    }
  }

  // 내 프로필 가져오기
  Future<Map<String, dynamic>?> getMyProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    return await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
  }

  // 회원 탈퇴 시 내 데이터 모두 삭제
  Future<void> deleteMyData() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // 순서 중요: scores 먼저 삭제 (profiles에 FK 참조할 수 있으므로)
    await _supabase.from('scores').delete().eq('user_id', userId);
    await _supabase.from('profiles').delete().eq('id', userId);
    rankedSummaryRefreshToken.value++;
  }
}
