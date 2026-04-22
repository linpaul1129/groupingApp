import '../models/player.dart';

/// 拖拉互換時在 Draggable / DragTarget 之間傳遞的資料。
class PlayerDragHandle {
  const PlayerDragHandle({required this.player, required this.courtIndex});

  final Player player;

  /// null 代表玩家來自等待區；否則為場地索引（0 或 1）。
  final int? courtIndex;

  bool get fromWaiting => courtIndex == null;
}
