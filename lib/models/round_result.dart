import 'player.dart';

/// match_maker 產出的一輪結果。
class RoundResult {
  RoundResult({
    required this.roundNumber,
    required this.courts,
    required this.nextRoundPreview,
    required this.waitingList,
  });

  /// 目前是第幾輪（從 1 開始）。
  final int roundNumber;

  /// 每個場地的 4 位玩家；courts.length = 1 或 2。
  final List<List<Player>> courts;

  /// 下一輪預覽（若目前人數不足 8 人且只有 1 場地，仍會嘗試推算）。
  final List<List<Player>> nextRoundPreview;

  /// 本輪未上場（等待中）的玩家清單。
  final List<Player> waitingList;

  /// 方便 UI 扁平化展示。
  List<Player> get currentPlaying =>
      courts.expand((court) => court).toList(growable: false);
}
