import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../models/player.dart';
import '../repositories/player_repository.dart';
import '../widgets/centered_toast.dart';
import '../widgets/player_chip.dart';
import 'activity_edit_screen.dart';

class SessionSetupScreen extends StatefulWidget {
  const SessionSetupScreen({super.key, required this.repository});

  final PlayerRepository repository;

  @override
  State<SessionSetupScreen> createState() => _SessionSetupScreenState();
}

class _SessionSetupScreenState extends State<SessionSetupScreen> {
  @override
  void initState() {
    super.initState();
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
    final activities = widget.repository.activities;
    final activeId = widget.repository.activeActivityId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('活動設定'),
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: activities.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              itemCount: activities.length,
              itemBuilder: (context, i) => _buildCard(activities[i], activeId),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('新增活動'),
      ),
    );
  }

  Widget _buildEmptyState() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_note_outlined,
                size: 52,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '尚未建立活動',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '點擊右下角「新增活動」開始',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Activity activity, String? activeId) {
    final isActive = activity.id == activeId;
    final count = activity.rosterIds.length;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final rosterPlayers = _resolveRoster(activity);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Dismissible(
        key: ValueKey(activity.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => _confirmDelete(activity),
        onDismissed: (_) => _deleteActivity(activity),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline, color: Colors.white),
              SizedBox(width: 6),
              Text(
                '刪除',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        child: Material(
          color: isActive ? scheme.primaryContainer : scheme.surface,
          borderRadius: BorderRadius.circular(16),
          elevation: isActive ? 1 : 0,
          shadowColor: scheme.primary.withValues(alpha: 0.3),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _activate(activity),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive ? scheme.primary : scheme.outlineVariant,
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLeading(isActive),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                activity.name,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isActive ? scheme.primary : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isActive) ...[
                              const SizedBox(width: 8),
                              _buildActiveBadge(scheme),
                            ],
                          ],
                        ),
                        if (rosterPlayers.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildAvatarPreview(rosterPlayers, scheme),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _buildChip(
                              icon: Icons.groups,
                              label: '$count 人',
                              scheme: scheme,
                            ),
                            _buildChip(
                              icon: activity.preferredCourts == 1
                                  ? Icons.looks_one_outlined
                                  : Icons.looks_two_outlined,
                              label: '${activity.preferredCourts} 場地',
                              scheme: scheme,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildMenu(activity, isActive),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 由 rosterIds 對映到實際 Player（可能有 id 已被刪除，過濾掉 null）。
  List<Player> _resolveRoster(Activity activity) {
    final byId = {for (final p in widget.repository.allPlayers) p.id: p};
    return [
      for (final id in activity.rosterIds)
        if (byId[id] != null) byId[id]!,
    ];
  }

  /// 玩家頭像橫排預覽：最多 5 顆，超過顯示 +N 圓點。
  Widget _buildAvatarPreview(List<Player> roster, ColorScheme scheme) {
    const maxShown = 5;
    final shown = roster.take(maxShown).toList();
    final extra = roster.length - shown.length;
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          for (final p in shown) ...[
            PlayerAvatar(player: p, radius: 14),
            const SizedBox(width: 4),
          ],
          if (extra > 0)
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surfaceContainerHighest,
              ),
              child: Text(
                '+$extra',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 三點選單：啟用（已啟用時隱藏）/ 編輯 / 刪除（紅）。
  Widget _buildMenu(Activity activity, bool isActive) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: '更多',
      onSelected: (v) async {
        switch (v) {
          case 'activate':
            await _activate(activity);
          case 'edit':
            await _openEdit(activity);
          case 'delete':
            await _menuDelete(activity);
        }
      },
      itemBuilder: (ctx) => [
        if (!isActive)
          const PopupMenuItem(
            value: 'activate',
            child: Row(
              children: [
                Icon(Icons.check_circle_outline),
                SizedBox(width: 12),
                Text('啟用'),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined),
              SizedBox(width: 12),
              Text('編輯'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red.shade600),
              const SizedBox(width: 12),
              Text('刪除', style: TextStyle(color: Colors.red.shade600)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _menuDelete(Activity activity) async {
    final ok = await _confirmDelete(activity);
    if (ok == true) await _deleteActivity(activity);
  }

  Widget _buildLeading(bool isActive) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isActive ? scheme.primary : scheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Icon(
        isActive ? Icons.check : Icons.event_note_outlined,
        color: isActive ? Colors.white : scheme.onSurfaceVariant,
        size: 22,
      ),
    );
  }

  Widget _buildActiveBadge(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        '使用中',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    required ColorScheme scheme,
  }) {
    final fg = scheme.onSurfaceVariant;
    final bg = scheme.surfaceContainerHighest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(Activity activity) => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('刪除活動'),
      content: Text('確定刪除「${activity.name}」？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('刪除'),
        ),
      ],
    ),
  );

  Future<void> _deleteActivity(Activity activity) async {
    final updated = widget.repository.activities
        .where((a) => a.id != activity.id)
        .toList();
    await widget.repository.saveActivities(updated);
    if (widget.repository.activeActivityId == activity.id) {
      await widget.repository.clearActiveActivity();
    }
  }

  Future<void> _activate(Activity activity) async {
    await widget.repository.activateActivity(activity);
    if (!mounted) return;
    showCenteredToast(
      context,
      '已切換至「${activity.name}」',
      kind: ToastKind.success,
    );
  }

  Future<void> _openCreate() async {
    final saved = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (ctx) => ActivityEditScreen(repository: widget.repository),
      ),
    );
    if (saved != null && mounted) {
      showCenteredToast(context, '「$saved」已儲存', kind: ToastKind.success);
    }
  }

  Future<void> _openEdit(Activity activity) async {
    final saved = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (ctx) => ActivityEditScreen(
          repository: widget.repository,
          existing: activity,
        ),
      ),
    );
    if (saved != null && mounted) {
      showCenteredToast(context, '「$saved」已更新', kind: ToastKind.success);
    }
  }
}
