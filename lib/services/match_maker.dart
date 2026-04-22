import 'dart:math';

import '../models/court_score.dart';
import '../models/player.dart';
import '../models/round_result.dart';

/// 分組與輪替核心邏輯。
///
/// 設計原則：
///   1. **純粹**：不直接寫入資料庫，也不碰 UI；只負責從 roster + 參數
///      產生 [RoundResult]，以及把一輪結束後的狀態變更套用到名單上。
///   2. **可測**：透過注入 [Random] 讓測試能固定隨機性。
///   3. **公平**：排序優先級 waitingRounds DESC，相同則隨機；並因此
///      自動達成「不連續上場（除非人數不足）」——剛上場的人
///      waitingRounds 會被歸零，自然排到候選順位最後面。
class MatchMaker {
  MatchMaker({Random? random}) : _random = random ?? Random();

  final Random _random;

  static const int playersPerCourt = 4;

  /// 根據人數與使用者偏好，決定本輪實際要開幾個場地。
  ///
  /// - <4 人：0（無法開始）
  /// - 4~7 人：固定 1 場地
  /// - ≥8 人：尊重使用者選擇的 1 或 2 場地
  int resolvedCourts(int rosterSize, int preferredCourts) {
    if (rosterSize < playersPerCourt) return 0;
    if (rosterSize < playersPerCourt * 2) return 1;
    return preferredCourts.clamp(1, 2);
  }

  /// 判斷目前 roster 是否足以開始。
  bool canStart(int rosterSize) => rosterSize >= playersPerCourt;

  /// 從 [candidates] 挑出 [needed] 位：先 shuffle 當作同優先級下的隨機；
  /// 再以 waitingRounds 由大到小做穩定排序；取前 needed 位。
  ///
  /// 公開版本：供 [MatchScreen] 在「每場結束即補人」的流程中直接呼叫。
  List<Player> pickPlayers(List<Player> candidates, int needed) =>
      _pickPlayers(candidates, needed);

  /// 初始化活動：從 [roster] 挑出第一批上場者並切分到場地。
  ///
  /// 回傳 record：
  /// - `courts`：每場地 4 位玩家
  /// - `waiting`：未上場的等待者
  ({List<List<Player>> courts, List<Player> waiting}) startSession({
    required List<Player> roster,
    required int preferredCourts,
  }) {
    final courtsCount = resolvedCourts(roster.length, preferredCourts);
    if (courtsCount == 0) {
      throw StateError('人數不足，至少需要 4 人');
    }
    final needed = courtsCount * playersPerCourt;
    final picked = _pickPlayers(roster, needed);
    final courts = _splitIntoCourts(picked, courtsCount);
    final pickedIds = picked.map((p) => p.id).toSet();
    final waiting = roster
        .where((p) => !pickedIds.contains(p.id))
        .toList(growable: false);
    return (courts: courts, waiting: waiting);
  }

  /// 產生第 [roundNumber] 輪的結果，但**不會**修改 [roster]。
  ///
  /// - [roundNumber] 從 1 開始。
  /// - 若人數不足會丟出 [StateError]。
  RoundResult buildRound({
    required List<Player> roster,
    required int preferredCourts,
    required int roundNumber,
  }) {
    final courtsCount = resolvedCourts(roster.length, preferredCourts);
    if (courtsCount == 0) {
      throw StateError('人數不足，至少需要 4 人');
    }
    final needed = courtsCount * playersPerCourt;

    final picked = _pickPlayers(roster, needed);
    final courts = _splitIntoCourts(picked, courtsCount);

    // 模擬下一輪狀態，用於產出 preview。
    final pickedIds = picked.map((p) => p.id).toSet();
    final simulated = roster.map((p) {
      if (pickedIds.contains(p.id)) {
        return p.copyWith(
          waitingRounds: 0,
          lastPlayedRound: roundNumber,
          gamesPlayed: p.gamesPlayed + 1,
        );
      }
      return p.copyWith(waitingRounds: p.waitingRounds + 1);
    }).toList();

    final nextCourtsCount = resolvedCourts(simulated.length, preferredCourts);
    final nextRoundPreview = nextCourtsCount == 0
        ? <List<Player>>[]
        : _splitIntoCourts(
            _pickPlayers(simulated, nextCourtsCount * playersPerCourt),
            nextCourtsCount,
          );

    final waitingList = roster
        .where((p) => !pickedIds.contains(p.id))
        .toList(growable: false);

    return RoundResult(
      roundNumber: roundNumber,
      courts: courts,
      nextRoundPreview: nextRoundPreview,
      waitingList: waitingList,
    );
  }

  /// 將 [result] 的結果套用到 [roster]（in-place 修改）。
  ///
  /// - 上場：waitingRounds=0、gamesPlayed+=1、lastPlayedRound=roundNumber；
  ///   若對應的 [scores] 有勝隊，勝隊兩位玩家的 wins 也 +1。
  /// - 未上場：waitingRounds+=1
  ///
  /// [scores] 的長度需與 result.courts 一致；未提供時視為沒有勝負
  /// （只記錄上場、不動 wins）。
  void commitRound({
    required List<Player> roster,
    required RoundResult result,
    List<CourtScore?>? scores,
  }) {
    final playingIds = result.currentPlaying.map((p) => p.id).toSet();

    // 找出所有勝方玩家 id。
    final winnerIds = <String>{};
    if (scores != null) {
      assert(scores.length == result.courts.length, 'scores 長度需與場地數相同');
      for (var i = 0; i < result.courts.length; i++) {
        final s = scores[i];
        if (s == null || !s.hasWinner) continue;
        final court = result.courts[i];
        if (s.winningTeam == 0) {
          winnerIds.add(court[0].id);
          winnerIds.add(court[1].id);
        } else if (s.winningTeam == 1) {
          winnerIds.add(court[2].id);
          winnerIds.add(court[3].id);
        }
      }
    }

    for (var i = 0; i < roster.length; i++) {
      final p = roster[i];
      if (playingIds.contains(p.id)) {
        roster[i] = p.copyWith(
          waitingRounds: 0,
          gamesPlayed: p.gamesPlayed + 1,
          lastPlayedRound: result.roundNumber,
          wins: p.wins + (winnerIds.contains(p.id) ? 1 : 0),
        );
      } else {
        roster[i] = p.copyWith(waitingRounds: p.waitingRounds + 1);
      }
    }
  }

  // ---- internal helpers -------------------------------------------------

  /// 從 [roster] 挑出 [needed] 位：
  /// 1. 先 shuffle（作為同優先級下的隨機洗牌）
  /// 2. 以 waitingRounds 由大到小做 stable sort
  /// 3. 取前 needed 位
  List<Player> _pickPlayers(List<Player> roster, int needed) {
    final pool = List<Player>.of(roster)..shuffle(_random);
    // Dart 的 List.sort 對大型集合不保證 stable，但這裡多加一個次序
    // 讓相同 waitingRounds 者順序維持 shuffle 後結果。
    final indexed = <MapEntry<int, Player>>[
      for (var i = 0; i < pool.length; i++) MapEntry(i, pool[i]),
    ];
    indexed.sort((a, b) {
      final byWaiting = b.value.waitingRounds.compareTo(a.value.waitingRounds);
      if (byWaiting != 0) return byWaiting;
      return a.key.compareTo(b.key); // 維持 shuffle 後的順序
    });
    return indexed.take(needed).map((e) => e.value).toList(growable: false);
  }

  List<List<Player>> _splitIntoCourts(List<Player> picked, int courts) {
    final result = <List<Player>>[];
    for (var c = 0; c < courts; c++) {
      final start = c * playersPerCourt;
      result.add(picked.sublist(start, start + playersPerCourt));
    }
    return result;
  }
}
