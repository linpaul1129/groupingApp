import 'dart:io';

import 'package:flutter/material.dart';

import '../models/player.dart';
import '../models/player_type.dart';
import '../repositories/player_repository.dart';
import '../services/avatar_service.dart';
import '../widgets/player_chip.dart';

class PlayerManagementScreen extends StatefulWidget {
  const PlayerManagementScreen({super.key, required this.repository});

  final PlayerRepository repository;

  @override
  State<PlayerManagementScreen> createState() => _PlayerManagementScreenState();
}

class _PlayerManagementScreenState extends State<PlayerManagementScreen> {
  final AvatarService _avatarService = AvatarService();

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onRepoChanged);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepoChanged);
    super.dispose();
  }

  void _onRepoChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final players = widget.repository.allPlayers;
    return Scaffold(
      appBar: AppBar(title: const Text('玩家管理')),
      body: players.isEmpty
          ? const Center(child: Text('尚未建立玩家，點右下角 + 新增'))
          : ListView.separated(
              itemCount: players.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final p = players[index];
                return ListTile(
                  leading: PlayerAvatar(player: p, radius: 22),
                  title: Text(p.name),
                  subtitle: Text(
                    '${p.type.label} · 累計 ${p.gamesPlayed} 場 · 勝 ${p.wins}',
                  ),
                  onTap: () => _showEditor(existing: p),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: '編輯',
                        onPressed: () => _showEditor(existing: p),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: '刪除',
                        onPressed: () => _confirmDelete(p),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _confirmDelete(Player p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除玩家'),
        content: Text('確定要刪除「${p.name}」？累計紀錄也會一併清除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _avatarService.deleteIfExists(p.avatarPath);
      await widget.repository.delete(p.id);
    }
  }

  /// 合併新增 / 編輯的 dialog。傳入 [existing] 即進入編輯模式。
  Future<void> _showEditor({Player? existing}) async {
    final result = await showDialog<_PlayerDraft>(
      context: context,
      builder: (ctx) =>
          _PlayerEditorDialog(initial: existing, avatarService: _avatarService),
    );
    if (result == null) return;

    if (existing == null) {
      final player = Player(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: result.name,
        type: result.type,
        avatarPath: result.avatarPath,
      );
      await widget.repository.upsert(player);
    } else {
      // 換了頭像就把舊檔刪掉。
      if (existing.avatarPath != null &&
          existing.avatarPath != result.avatarPath) {
        await _avatarService.deleteIfExists(existing.avatarPath);
      }
      final updated = existing.copyWith(
        name: result.name,
        type: result.type,
        avatarPath: result.avatarPath,
      );
      await widget.repository.upsert(updated);
    }
  }
}

class _PlayerDraft {
  _PlayerDraft({
    required this.name,
    required this.type,
    required this.avatarPath,
  });

  final String name;
  final PlayerType type;
  final String? avatarPath;
}

class _PlayerEditorDialog extends StatefulWidget {
  const _PlayerEditorDialog({this.initial, required this.avatarService});

  final Player? initial;
  final AvatarService avatarService;

  @override
  State<_PlayerEditorDialog> createState() => _PlayerEditorDialogState();
}

class _PlayerEditorDialogState extends State<_PlayerEditorDialog> {
  late final TextEditingController _nameCtrl;
  late PlayerType _type;
  String? _avatarPath;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _nameCtrl = TextEditingController(text: init?.name ?? '');
    _type = init?.type ?? PlayerType.regular;
    _avatarPath = init?.avatarPath;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    return AlertDialog(
      title: Text(isEdit ? '編輯玩家' : '新增玩家'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: _buildAvatarPicker()),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: '名稱'),
              autofocus: !isEdit,
            ),
            const SizedBox(height: 12),
            SegmentedButton<PlayerType>(
              segments: const [
                ButtonSegment(
                  value: PlayerType.regular,
                  label: Text('固定'),
                  icon: Icon(Icons.person),
                ),
                ButtonSegment(
                  value: PlayerType.guest,
                  label: Text('零打'),
                  icon: Icon(Icons.person_outline),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: Text(isEdit ? '儲存' : '新增')),
      ],
    );
  }

  Widget _buildAvatarPicker() {
    final hasAvatar =
        _avatarPath != null &&
        _avatarPath!.isNotEmpty &&
        File(_avatarPath!).existsSync();

    return Column(
      children: [
        GestureDetector(
          onTap: _picking ? null : _pickAvatar,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                backgroundImage: hasAvatar
                    ? FileImage(File(_avatarPath!))
                    : null,
                child: hasAvatar
                    ? null
                    : const Icon(Icons.add_a_photo_outlined, size: 28),
              ),
              if (_picking)
                const Positioned.fill(
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: _picking ? null : _pickAvatar,
              icon: const Icon(Icons.image_outlined, size: 18),
              label: Text(hasAvatar ? '更換照片' : '上傳照片'),
            ),
            if (hasAvatar)
              TextButton.icon(
                onPressed: _picking
                    ? null
                    : () => setState(() => _avatarPath = null),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('移除'),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickAvatar() async {
    setState(() => _picking = true);
    try {
      final path = await widget.avatarService.pickAndSave();
      if (path != null) {
        setState(() => _avatarPath = path);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('選取圖片失敗：$e')));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      _PlayerDraft(name: name, type: _type, avatarPath: _avatarPath),
    );
  }
}
