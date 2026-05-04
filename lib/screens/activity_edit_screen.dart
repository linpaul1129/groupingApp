import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../models/player.dart';
import '../models/player_type.dart';
import '../repositories/player_repository.dart';
import '../services/match_maker.dart';
import '../widgets/centered_toast.dart';
import '../widgets/player_chip.dart';

class ActivityEditScreen extends StatefulWidget {
  const ActivityEditScreen({
    super.key,
    required this.repository,
    this.existing,
  });

  final PlayerRepository repository;

  /// 傳入既有活動表示編輯模式；null 表示新增模式。
  final Activity? existing;

  @override
  State<ActivityEditScreen> createState() => _ActivityEditScreenState();
}

class _ActivityEditScreenState extends State<ActivityEditScreen> {
  late TextEditingController _nameCtrl;
  late Set<String> _selected;
  late int _preferredCourts;
  late bool _balanceByWinRate;

  static const Map<int, int> _maxByCourts = {1: 8, 2: 14};

  int get _maxPlayers => _maxByCourts[_preferredCourts] ?? 14;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _selected = (e?.rosterIds ?? []).toSet();
    _preferredCourts = e?.preferredCourts ?? 1;
    _balanceByWinRate = e?.balanceByWinRate ?? false;
    widget.repository.addListener(_onChanged);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    widget.repository.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final players = widget.repository.allPlayers;
    final selectedCount = _selected.length;
    final resolvedCourts = MatchMaker().resolvedCourts(
      selectedCount,
      _preferredCourts,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '編輯活動' : '新增活動'),
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildBasicSection(),
                  const SizedBox(height: 14),
                  _buildSettingsSection(),
                  const SizedBox(height: 14),
                  _buildStatusBanner(selectedCount, resolvedCourts),
                  const SizedBox(height: 16),
                  _buildRosterHeader(selectedCount),
                  const SizedBox(height: 8),
                  _buildRosterGrid(players),
                ],
              ),
            ),
          ),
          _buildSaveBar(selectedCount),
        ],
      ),
    );
  }

  // ---- Sections ---------------------------------------------------------

  Widget _buildBasicSection() {
    return _SectionCard(
      icon: Icons.edit_note,
      title: '基本資訊',
      child: TextField(
        controller: _nameCtrl,
        decoration: InputDecoration(
          labelText: '活動名稱',
          hintText: '例如：週三早場、週六午場',
          prefixIcon: const Icon(Icons.label_outline),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    final scheme = Theme.of(context).colorScheme;
    final selectedCount = _selected.length;
    final canPickOne = selectedCount <= (_maxByCourts[1] ?? 8);
    return _SectionCard(
      icon: Icons.tune,
      title: '比賽設定',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '場地數',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 14),
          _buildBalanceTile(),
        ],
      ),
    );
  }

  Widget _buildBalanceTile() {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _balanceByWinRate = !_balanceByWinRate),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _balanceByWinRate
              ? scheme.primaryContainer.withValues(alpha: 0.4)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _balanceByWinRate
                ? scheme.primary.withValues(alpha: 0.5)
                : scheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.balance,
              color: _balanceByWinRate
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '勝率平衡分組',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '依個人勝率自動調整隊伍搭配',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _balanceByWinRate,
              onChanged: (v) => setState(() => _balanceByWinRate = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRosterHeader(int selectedCount) {
    return Row(
      children: [
        Icon(
          Icons.groups,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '本次活動名單',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$selectedCount / $_maxPlayers',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selectedCount > _maxPlayers
                  ? Colors.red.shade600
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        TextButton.icon(
          icon: const Icon(Icons.clear_all, size: 16),
          label: const Text('清空'),
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
    );
  }

  Widget _buildRosterGrid(List<Player> players) {
    const double cardHeight = 100 / 0.72;
    const double minGridHeight = cardHeight * 2.5;

    if (players.isEmpty) {
      return Container(
        height: minGridHeight,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 40,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              '請先到「玩家管理」新增玩家',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: minGridHeight),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 100,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.72,
        ),
        itemCount: players.length,
        itemBuilder: (context, index) => _buildPlayerCard(players[index]),
      ),
    );
  }

  Widget _buildSaveBar(int selectedCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          child: FilledButton.icon(
            icon: const Icon(Icons.save),
            onPressed: selectedCount > 0 ? _save : null,
            label: const Text(
              '儲存活動',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner(int count, int resolvedCourts) {
    final Color bg;
    final Color fg;
    final IconData icon;
    final String msg;
    if (count < 4) {
      bg = Colors.red.shade50;
      fg = Colors.red.shade700;
      icon = Icons.error_outline;
      msg = '人數不足（$count 人），至少需 4 人才能開始';
    } else if (count > _maxPlayers) {
      bg = Colors.red.shade50;
      fg = Colors.red.shade700;
      icon = Icons.error_outline;
      msg = '超過目前場地上限（$_preferredCourts 場地最多 $_maxPlayers 人）';
    } else if (count < 8) {
      bg = Colors.amber.shade50;
      fg = Colors.amber.shade800;
      icon = Icons.info_outline;
      msg = '$count 人 → 使用 1 個場地（4 人同時上場）';
    } else {
      bg = Colors.green.shade50;
      fg = Colors.green.shade700;
      icon = Icons.check_circle_outline;
      msg = '$count 人 → 使用 $resolvedCourts 個場地（${resolvedCourts * 4} 人同時上場）';
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(color: fg, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(Player p) {
    final selected = _selected.contains(p.id);
    final reachedCap = _selected.length >= _maxPlayers && !selected;
    final isGuest = p.type == PlayerType.guest;
    final primaryColor = isGuest
        ? Colors.orange
        : Theme.of(context).colorScheme.primary;

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
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
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
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
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
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showCenteredToast(context, '請輸入活動名稱', kind: ToastKind.warning);
      return;
    }

    final activity = Activity(
      id:
          widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      rosterIds: _selected.toList(),
      preferredCourts: _preferredCourts,
      balanceByWinRate: _balanceByWinRate,
    );

    final list = widget.repository.activities;
    final idx = list.indexWhere((a) => a.id == activity.id);
    final updated = [...list];
    if (idx >= 0) {
      updated[idx] = activity;
    } else {
      updated.add(activity);
    }
    await widget.repository.saveActivities(updated);

    // 若正在編輯的是當前啟用的活動，同步更新比賽頁設定。
    if (widget.repository.activeActivityId == activity.id) {
      await widget.repository.activateActivity(activity);
    }

    if (!mounted) return;
    Navigator.pop(context, name);
  }
}

/// 帶 icon + 標題的卡片區塊容器。
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
