/// 單一場地的比分結果。
///
/// - team A = CourtCard 顯示在場地上半的兩位玩家（roster 中第 0, 1 位）
/// - team B = 下半兩位玩家（roster 中第 2, 3 位）
class CourtScore {
  const CourtScore({required this.teamAScore, required this.teamBScore});

  final int teamAScore;
  final int teamBScore;

  /// 回傳勝隊索引：0=隊A、1=隊B、-1=和局。
  int get winningTeam {
    if (teamAScore > teamBScore) return 0;
    if (teamBScore > teamAScore) return 1;
    return -1;
  }

  bool get hasWinner => winningTeam >= 0;
}
