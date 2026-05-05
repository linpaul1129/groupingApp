import 'package:flutter/material.dart';

import '../models/court_score.dart';
import '../models/court_state.dart';
import '../models/player.dart';
import 'badminton_court_painter.dart';
import 'player_chip.dart';

/// 場地卡片：羽球場背景上上下分隊；依 [state] 顯示「開始比賽」或「結束本場」。
///
/// pending 狀態時玩家可被點擊；上層藉由 [onPlayerTap] 與 [selectedPlayerId]
/// 實作「點 A → 點 B 互換」的兩段式選擇。
/// playing 狀態時點擊隊伍半場 = 該隊得 1 分。
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
    this.liveScore,
    this.onTeamScore,
    this.onDecrementScore,
    this.onPlayerTap,
    this.selectedPlayerId,
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

  /// 實時比分（null 代表非實時模式）。
  final (int, int)? liveScore;

  /// 點擊隊伍半場：該隊得 1 分。team 0=隊A、1=隊B。
  final void Function(int team)? onTeamScore;

  /// 整隊扣 1 分（修正用）：team 0=隊A、1=隊B。
  final void Function(int team)? onDecrementScore;

  /// pending 場地玩家被點擊（兩段選擇互換用）。
  final void Function(Player player)? onPlayerTap;

  /// 目前被選中的玩家 id（用於高亮）；null 代表無選擇。
  final String? selectedPlayerId;

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
            _buildHeader(context),
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

  Widget _buildHeader(BuildContext context) {
    final showLive = state == CourtState.playing && liveScore != null;
    return Row(
      children: [
        Icon(Icons.sports_tennis, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        Expanded(
          child: showLive
              ? Center(child: _buildLiveScoreInline(context, liveScore!))
              : const SizedBox.shrink(),
        ),
        _buildStatusBadge(context),
      ],
    );
  }

  Widget _buildLiveScoreInline(BuildContext context, (int, int) score) {
    final (a, b) = score;
    final style = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: 1,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$a : $b', style: style),
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
          Expanded(child: _halfCourt(teamA, 0)),
          const SizedBox(height: 2),
          Expanded(child: _halfCourt(teamB, 1)),
        ],
      ),
    );
  }

  /// 半場：playing 時整片半場為 InkWell（點擊 +1 給該隊）。
  Widget _halfCourt(List<Player> team, int teamIdx) {
    final row = _teamRow(team);
    if (state == CourtState.playing && onTeamScore != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTeamScore!(teamIdx),
          borderRadius: BorderRadius.circular(8),
          child: row,
        ),
      );
    }
    return row;
  }

  Widget _teamRow(List<Player> team) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [for (final p in team) Expanded(child: _wrapPlayer(p))],
    );
  }

  /// 依 [state] 決定玩家是純顯示（playing）還是可點擊互換（pending）。
  Widget _wrapPlayer(Player player) {
    if (state == CourtState.playing) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: _CourtPlayer(player: player, avatarRadius: 24),
      );
    }
    return _buildSelectable(player);
  }

  Widget _buildSelectable(Player player) {
    final slot = _CourtPlayer(player: player);
    final isSelected = selectedPlayerId == player.id;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPlayerTap == null ? null : () => onPlayerTap!(player),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: Colors.yellow.shade600, width: 2)
                : null,
          ),
          padding: const EdgeInsets.all(2),
          child: slot,
        ),
      ),
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
    final (a, b) = liveScore ?? (0, 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (liveScore != null) ...[
          _buildDecrementBar(context, a, b),
          const SizedBox(height: 8),
        ],
        FilledButton.tonalIcon(
          icon: const Icon(Icons.flag_outlined),
          label: const Text('結束本場'),
          onPressed: onFinish,
        ),
        if (lastScore != null) ...[
          const SizedBox(height: 6),
          _buildLastScoreLine(context, lastScore!),
        ],
      ],
    );
  }

  /// 兩隊各一個「-1」按鈕，用於修正點錯的計分。
  Widget _buildDecrementBar(BuildContext context, int a, int b) {
    return Row(
      children: [
        Expanded(child: _buildDecrementBtn(context, '隊 A −1', 0, a)),
        const SizedBox(width: 8),
        Expanded(child: _buildDecrementBtn(context, '隊 B −1', 1, b)),
      ],
    );
  }

  Widget _buildDecrementBtn(
    BuildContext context,
    String label,
    int team,
    int score,
  ) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.remove_circle_outline, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 6),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: score > 0 && onDecrementScore != null
          ? () => onDecrementScore!(team)
          : null,
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
      textAlign: TextAlign.center,
    );
  }
}

/// 顯示在球場上的單一玩家（頭像 + 名字）。
class _CourtPlayer extends StatelessWidget {
  const _CourtPlayer({required this.player, this.avatarRadius = 18});

  final Player player;
  final double avatarRadius;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PlayerAvatar(player: player, radius: avatarRadius),
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
