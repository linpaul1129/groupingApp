import 'package:flutter/material.dart';

import '../models/player.dart';
import '../models/player_type.dart';
import '../repositories/player_repository.dart';
import '../services/match_maker.dart';
import '../widgets/player_chip.dart';

class SessionSetupScreen extends StatefulWidget {
  const SessionSetupScreen({super.key, required this.repository});

  final PlayerRepository repository;

  @override
  State<SessionSetupScreen> createState() => _SessionSetupScreenState();
}

class _SessionSetupScreenState extends State<SessionSetupScreen> {
  late Set<String> _selected;
  late int _preferredCourts;

  /// 依場地數換算人數上限：1 場地 8 人、2 場地 14 人。
  static const Map<int, int> _maxByCourts = {1: 8, 2: 14};

  int get _maxPlayers => _maxByCourts[_preferredCourts] ?? 14;

  @override
  void initState() {
    super.initState();
    _selected = widget.repository.activeRosterIds.toSet();
    _preferredCourts = widget.repository.preferredCourts;
    widget.repository.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final players = widget.repository.allPlayers;
    final selectedCount = _selected.length;
    final matchMaker = MatchMaker();
    final resolvedCourts = matchMaker.resolvedCourts(
      selectedCount,
      _preferredCourts,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('活動設定')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCourtSelector(selectedCount),
            const SizedBox(height: 8),
            _buildBalanceToggle(),
            const SizedBox(height: 4),
            _buildLiveScoringToggle(),
            const SizedBox(height: 12),
            _buildStatusBanner(selectedCount, resolvedCourts),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '選擇本次活動名單（已選 $selectedCount / $_maxPlayers）',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('清空名單'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade400,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _selected.isEmpty
                      ? null
                      : () => setState(() => _selected.clear()),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: players.isEmpty
                  ? const Center(child: Text('請先到「玩家管理」新增玩家'))
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 100,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: players.length,
                      itemBuilder: (context, index) =>
                          _buildPlayerCard(players[index]),
                    ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: const Icon(Icons.save),
              onPressed: selectedCount > 0 ? _save : null,
              label: const Text('儲存名單'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourtSelector(int selectedCount) {
    // 選 1 場地若當前已超過 8 人會先被阻擋；選 2 場地永遠可用。
    final canPickOne = selectedCount <= (_maxByCourts[1] ?? 8);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('場地數', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            segments: [
              ButtonSegment(
                value: 1,
                label: const Text('1 場地'),
                icon: const Icon(Icons.looks_one_outlined),
                enabled: canPickOne,
              ),
              const ButtonSegment(
                value: 2,
                label: Text('2 場地'),
                icon: Icon(Icons.looks_two_outlined),
              ),
            ],
            selected: {_preferredCourts},
            onSelectionChanged: (s) =>
                setState(() => _preferredCourts = s.first),
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceToggle() {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('勝率平衡分組'),
      subtitle: const Text('依個人勝率自動調整隊伍搭配'),
      value: widget.repository.balanceByWinRate,
      onChanged: (v) async {
        await widget.repository.setBalanceByWinRate(v);
        if (mounted) setState(() {});
      },
    );
  }

  Widget _buildLiveScoringToggle() {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('實時計分'),
      subtitle: const Text('比賽中即時加減分，結束時直接採用'),
      value: widget.repository.liveScoring,
      onChanged: (v) async {
        await widget.repository.setLiveScoring(v);
        if (mounted) setState(() {});
      },
    );
  }

  Widget _buildStatusBanner(int count, int resolvedCourts) {
    Color bg;
    IconData icon;
    String msg;
    if (count < 4) {
      bg = Colors.red.shade50;
      icon = Icons.error_outline;
      msg = '人數不足（$count 人），至少需 4 人才能開始';
    } else if (count > _maxPlayers) {
      bg = Colors.red.shade50;
      icon = Icons.error_outline;
      msg = '超過目前場地上限（$_preferredCourts 場地最多 $_maxPlayers 人）';
    } else if (count < 8) {
      bg = Colors.amber.shade50;
      icon = Icons.info_outline;
      msg = '$count 人 → 使用 1 個場地（4 人同時上場）';
    } else {
      bg = Colors.green.shade50;
      icon = Icons.check_circle_outline;
      msg = '$count 人 → 使用 $resolvedCourts 個場地（${resolvedCourts * 4} 人同時上場）';
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(Player p) {
    final selected = _selected.contains(p.id);
    final reachedCap = _selected.length >= _maxPlayers && !selected;
    final isGuest = p.type == PlayerType.guest;

    final primaryColor =
        isGuest ? Colors.orange : Theme.of(context).colorScheme.primary;

    final Color borderColor;
    final Color bgColor;

    if (reachedCap) {
      borderColor = Colors.grey.shade300;
      bgColor = Colors.grey.shade100;
    } else if (selected) {
      borderColor = primaryColor;
      bgColor = primaryColor.withValues(alpha: 0.12);
    } else {
      borderColor = Colors.grey.shade300;
      bgColor = Theme.of(context).colorScheme.surface;
    }

    return Opacity(
      opacity: reachedCap ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: reachedCap
            ? null
            : () => setState(() {
                  if (selected) {
                    _selected.remove(p.id);
                  } else {
                    _selected.add(p.id);
                  }
                }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PlayerAvatar(player: p, radius: 20),
                  const SizedBox(height: 5),
                  Text(
                    p.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: selected
                          ? primaryColor
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${p.gamesPlayed} 場',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  Text(
                    p.gamesPlayed == 0
                        ? '—'
                        : '勝 ${(p.winRate * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 10,
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (selected)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    await widget.repository.saveActiveRoster(_selected.toList());
    await widget.repository.setPreferredCourts(_preferredCourts);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('名單已儲存，可到「比賽」頁開始排場')));
  }
}
