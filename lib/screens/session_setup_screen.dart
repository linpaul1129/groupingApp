import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../repositories/player_repository.dart';
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
      appBar: AppBar(title: const Text('活動設定')),
      body: activities.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.event_note_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '尚未建立活動\n點擊右下角 + 新增',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: activities.length,
              itemBuilder: (context, i) => _buildTile(activities[i], activeId),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        tooltip: '新增活動',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTile(Activity activity, String? activeId) {
    final isActive = activity.id == activeId;
    final count = activity.rosterIds.length;
    final tags = [
      '${activity.preferredCourts} 場地',
      if (activity.balanceByWinRate) '勝率平衡',
      if (activity.liveScoring) '實時計分',
    ].join('・');

    return Dismissible(
      key: ValueKey(activity.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(activity),
      onDismissed: (_) => _deleteActivity(activity),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: ListTile(
        leading: isActive
            ? Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              )
            : Icon(Icons.radio_button_unchecked, color: Colors.grey.shade400),
        title: Text(
          activity.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('$count 人・$tags'),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: '編輯',
          onPressed: () => _openEdit(activity),
        ),
        onTap: () => _activate(activity),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已切換至「${activity.name}」，可到比賽頁開始排場')));
  }

  Future<void> _openCreate() async {
    final saved = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (ctx) => ActivityEditScreen(repository: widget.repository),
      ),
    );
    if (saved != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('「$saved」已儲存')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('「$saved」已更新')));
    }
  }
}
