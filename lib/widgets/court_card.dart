import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/court_score.dart';
import '../models/court_state.dart';
import '../models/player.dart';
import 'badminton_court_painter.dart';
import 'player_chip.dart';
import 'player_drag_handle.dart';

/// 場地卡片：羽球場背景上上下分隊；依 [state] 顯示「開始比賽」或「結束本場」。
///
/// pending 狀態時玩家是 `LongPressDraggable` 與 `DragTarget`，可直接和
/// 等待區的玩家互換（由 [onSwap] 回呼給上層執行）。
class CourtCard extends StatelessWidget {
  const CourtCard({
    super.key,
    required this.title,
    required this.courtIndex,
    required this.players,
    required this.state,
    this.lastScore,
    this.onStart,
    this.onFinish,
    this.onSwap,
    this.preview = false,
  }) : assert(players.length == 4, 'CourtCard 需要 4 位玩家');

  final String title;
  final int courtIndex;
  final List<Player> players;
  final CourtState state;

  /// 最近一場比分（僅顯示用）。
  final CourtScore? lastScore;

  final VoidCallback? onStart;
  final VoidCallback? onFinish;

  /// 玩家拖拉互換：`from` 為被拖動的來源、`toPlayerOnThisCourt` 為本場被放上的玩家。
  final void Function(PlayerDragHandle from, Player toPlayerOnThisCourt)?
  onSwap;

  /// 顯示為淡色預覽（目前流程沒用到；保留參數以便未來擴充）。
  final bool preview;

  @override
  Widget build(BuildContext context) {
    final teamA = players.sublist(0, 2);
    final teamB = players.sublist(2, 4);

    return Card(
      elevation: preview ? 0 : 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sports_tennis,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                _buildStatusBadge(context),
              ],
            ),
            const SizedBox(height: 10),
            AspectRatio(
              aspectRatio: 16 / 11,
              child: Opacity(
                opacity: preview ? 0.55 : 1.0,
                child: CustomPaint(
                  painter: BadmintonCourtPainter(),
                  child: _buildPlayersLayer(teamA, teamB),
                ),
              ),
            ),
            if (!preview) ...[
              const SizedBox(height: 10),
              _buildBottomControl(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    final (label, color) = switch (state) {
      CourtState.pending => ('待開始', Colors.orange.shade700),
      CourtState.playing => ('進行中', Theme.of(context).colorScheme.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildPlayersLayer(List<Player> teamA, List<Player> teamB) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Expanded(child: _teamRow(teamA)),
          const SizedBox(height: 2),
          Expanded(child: _teamRow(teamB)),
        ],
      ),
    );
  }

  Widget _teamRow(List<Player> team) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [for (final p in team) _wrapPlayer(p)],
    );
  }

  /// 依 [state] 決定玩家是否可拖拉 / 接收拖放。
  Widget _wrapPlayer(Player player) {
    final slot = _CourtPlayer(player: player);
    if (state != CourtState.pending) return slot;

    final dragHandle = PlayerDragHandle(player: player, courtIndex: courtIndex);
    final feedback = Material(
      color: Colors.transparent,
      child: Transform.scale(scale: 1.1, child: _CourtPlayer(player: player)),
    );
    final childWhenDragging = Opacity(opacity: 0.3, child: slot);
    // Web 上滑鼠操作沒有「長按」概念，LongPressDraggable 會與 ListView 滾動搶
    // 手勢導致拖不起來；native 則保留長按避免行動裝置誤觸。
    final Widget draggable = kIsWeb
        ? Draggable<PlayerDragHandle>(
            data: dragHandle,
            feedback: feedback,
            childWhenDragging: childWhenDragging,
            child: slot,
          )
        : LongPressDraggable<PlayerDragHandle>(
            data: dragHandle,
            delay: const Duration(milliseconds: 200),
            feedback: feedback,
            childWhenDragging: childWhenDragging,
            child: slot,
          );

    return DragTarget<PlayerDragHandle>(
      onWillAcceptWithDetails: (details) => details.data.player.id != player.id,
      onAcceptWithDetails: (details) => onSwap?.call(details.data, player),
      builder: (context, candidates, _) {
        final highlighted = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: highlighted
                ? Border.all(color: Colors.yellow.shade600, width: 2)
                : null,
          ),
          padding: const EdgeInsets.all(2),
          child: draggable,
        );
      },
    );
  }

  Widget _buildBottomControl(BuildContext context) {
    if (state == CourtState.pending) {
      return FilledButton.icon(
        icon: const Icon(Icons.play_arrow),
        label: const Text('開始比賽（可先與等待區互換）'),
        onPressed: onStart,
      );
    }
    // playing
    return Column(
      children: [
        FilledButton.tonalIcon(
          icon: const Icon(Icons.flag_outlined),
          label: const Text('結束本場並輸入比分'),
          onPressed: onFinish,
        ),
        if (lastScore != null) ...[
          const SizedBox(height: 6),
          _buildLastScoreLine(context, lastScore!),
        ],
      ],
    );
  }

  Widget _buildLastScoreLine(BuildContext context, CourtScore s) {
    final winner = switch (s.winningTeam) {
      0 => '隊 A 勝',
      1 => '隊 B 勝',
      _ => '和局',
    };
    return Text(
      '上一場：${s.teamAScore} : ${s.teamBScore}（$winner）',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

/// 顯示在球場上的單一玩家（頭像 + 名字）。
class _CourtPlayer extends StatelessWidget {
  const _CourtPlayer({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PlayerAvatar(player: player, radius: 18),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            player.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
