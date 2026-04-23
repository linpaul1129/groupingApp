import 'package:flutter/material.dart';

import '../models/player.dart';
import '../models/player_type.dart';
import '../services/avatar_service.dart';

/// 玩家小徽章（含頭像），統一在各畫面展示玩家姓名與類型。
class PlayerChip extends StatelessWidget {
  const PlayerChip({super.key, required this.player, this.showStats = false});

  final Player player;
  final bool showStats;

  @override
  Widget build(BuildContext context) {
    final isGuest = player.type == PlayerType.guest;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
      decoration: BoxDecoration(
        color: isGuest
            ? Colors.orange.shade50
            : Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isGuest
              ? Colors.orange
              : Theme.of(context).colorScheme.primary,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlayerAvatar(player: player, radius: 12),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              player.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (showStats) ...[
            const SizedBox(width: 6),
            Text(
              player.gamesPlayed == 0
                  ? '${player.gamesPlayed}場'
                  : '${player.gamesPlayed}場·勝${(player.winRate * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// 卡片式玩家顯示：頭像 + 姓名 + 場次 + 勝率，用於名單預覽與等待區。
class PlayerStatCard extends StatelessWidget {
  const PlayerStatCard({super.key, required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final isGuest = player.type == PlayerType.guest;
    final primary =
        isGuest ? Colors.orange : Theme.of(context).colorScheme.primary;
    final bg = isGuest
        ? Colors.orange.shade50
        : Theme.of(context).colorScheme.primaryContainer;

    final winText = player.gamesPlayed == 0
        ? '—'
        : '勝 ${(player.winRate * 100).toStringAsFixed(0)}%';

    return Container(
      width: 84,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withValues(alpha: 0.45)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlayerAvatar(player: player, radius: 20),
          const SizedBox(height: 6),
          Text(
            player.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '${player.gamesPlayed} 場',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          Text(
            winText,
            style: TextStyle(
              fontSize: 11,
              color: primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 圓形頭像：有 avatarPath 顯示圖檔，否則顯示姓名首字。
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({super.key, required this.player, this.radius = 20});

  final Player player;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fallbackBg = player.type == PlayerType.guest
        ? Colors.orange.shade200
        : Theme.of(context).colorScheme.primaryContainer;

    final image = avatarImageProvider(player.avatarPath);
    final initial = Text(
      player.name.isNotEmpty ? player.name.characters.first : '?',
      style: TextStyle(fontSize: radius * 0.9, fontWeight: FontWeight.w600),
    );
    if (image != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: fallbackBg,
        child: ClipOval(
          child: Image(
            image: image,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context2, e, st) => initial,
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: fallbackBg,
      child: initial,
    );
  }
}
