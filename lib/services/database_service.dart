import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeaderboardEntry {
  final String userId;
  final String nickname;
  final int wins;
  final int losses;
  final List<String> recentResults;

  const LeaderboardEntry({
    required this.userId,
    required this.nickname,
    required this.wins,
    required this.losses,
    required this.recentResults,
  });

  int get games => wins + losses;
  double get winRate => games == 0 ? 0 : wins / games;
}

class _LeaderboardAccumulator {
  final String userId;
  String nickname;
  int wins = 0;
  int losses = 0;
  final List<String> recentResults = [];

  _LeaderboardAccumulator({
    required this.userId,
    required this.nickname,
  });

  LeaderboardEntry toEntry() {
    return LeaderboardEntry(
      userId: userId,
      nickname: nickname,
      wins: wins,
      losses: losses,
      recentResults: List.unmodifiable(recentResults),
    );
  }
}

class DatabaseService extends GetxService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<LeaderboardEntry>> getMatchLeaderboard(String gameId) async {
    try {
      final response = await _supabase
          .from('multiplayer_match_results')
          .select('winner_role, players, finished_at')
          .eq('game_key', gameId)
          .order('finished_at', ascending: false)
          .limit(500);

      final rows = List<Map<String, dynamic>>.from(response);
      final entries = <String, _LeaderboardAccumulator>{};

      for (final row in rows) {
        final winnerRole = row['winner_role']?.toString();
        final players = row['players'];
        if (players is! List) continue;

        for (final rawPlayer in players) {
          if (rawPlayer is! Map) continue;

          final player = Map<String, dynamic>.from(rawPlayer);
          final userId = player['user_id']?.toString();
          final role = player['role']?.toString();
          if (userId == null || userId.isEmpty || role == null) continue;

          final nickname = player['nickname']?.toString().trim();
          final entry = entries.putIfAbsent(
            userId,
            () => _LeaderboardAccumulator(
              userId: userId,
              nickname: nickname?.isNotEmpty == true ? nickname! : '플레이어',
            ),
          );
          if (nickname != null && nickname.isNotEmpty) {
            entry.nickname = nickname;
          }

          final result = winnerRole == null
              ? '무'
              : winnerRole == role
                  ? '승'
                  : '패';

          if (result == '승') entry.wins += 1;
          if (result == '패') entry.losses += 1;
          if (entry.recentResults.length < 5) {
            entry.recentResults.add(result);
          }
        }
      }

      final leaderboard =
          entries.values.map((entry) => entry.toEntry()).toList()
            ..sort((a, b) {
              final winCompare = b.wins.compareTo(a.wins);
              if (winCompare != 0) return winCompare;

              final rateCompare = b.winRate.compareTo(a.winRate);
              if (rateCompare != 0) return rateCompare;

              final lossCompare = a.losses.compareTo(b.losses);
              if (lossCompare != 0) return lossCompare;

              return a.nickname.compareTo(b.nickname);
            });

      return leaderboard.take(50).toList(growable: false);
    } catch (e) {
      debugPrint('Error fetching match leaderboard: $e');
      return [];
    }
  }

  Future<String?> updateNickname(String nickname) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return '로그인이 필요합니다.';

    try {
      await _supabase.from('profiles').upsert({
        'id': userId,
        'nickname': nickname,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return null;
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        return '이미 사용 중인 닉네임입니다. \n다른 닉네임을 선택해주세요.';
      }
      return '닉네임 업데이트 중 오류가 발생했습니다: ${e.message}';
    } catch (_) {
      return '알 수 없는 오류가 발생했습니다.';
    }
  }

  Future<bool> checkNicknameAvailable(String nickname) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id')
          .eq('nickname', nickname)
          .maybeSingle();

      return response == null;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getMyProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    return await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
  }

  Future<void> deleteMyData() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from('profiles').delete().eq('id', userId);
  }
}
