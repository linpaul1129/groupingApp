import 'package:flutter/material.dart';

import '../models/player.dart';
import '../models/player_type.dart';
import '../repositories/player_repository.dart';
import '../services/avatar_service.dart';
import '../utils/breakpoints.dart';
import '../widgets/centered_toast.dart';
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
    final isPhone = AppBreakpoints.isPhone(context);

    return Scaffold(
      appBar: AppBar(title: const Text('玩家管理')),
      body: players.isEmpty
          ? const Center(child: Text('尚未建立玩家，點右下角 + 新增'))
          : isPhone
          ? _buildList(players)
          : _buildGrid(players),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildList(List<Player> players) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      itemCount: players.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final p = players[index];
        return _PlayerCard(
          player: p,
          mode: _PlayerCardMode.list,
          onTap: () => _showEditor(existing: p),
          onEdit: () => _showEditor(existing: p),
          onDelete: () => _confirmDelete(p),
        );
      },
    );
  }

  Widget _buildGrid(List<Player> players) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 200,
      ),
      itemCount: players.length,
      itemBuilder: (context, index) {
        final p = players[index];
        return _PlayerCard(
          player: p,
          mode: _PlayerCardMode.grid,
          onTap: () => _showEditor(existing: p),
          onEdit: () => _showEditor(existing: p),
          onDelete: () => _confirmDelete(p),
        );
      },
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

enum _PlayerCardMode { list, grid }

/// 玩家卡片：outline border + Web hover 反白；右上角 ⋮ 編輯/刪除選單。
class _PlayerCard extends StatefulWidget {
  const _PlayerCard({
    required this.player,
    required this.mode,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Player player;
  final _PlayerCardMode mode;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_PlayerCard> createState() => _PlayerCardState();
}

class _PlayerCardState extends State<_PlayerCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _hover ? cs.surfaceContainerHigh : cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: widget.mode == _PlayerCardMode.list
                ? _buildListBody(context)
                : _buildGridBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildListBody(BuildContext context) {
    final p = widget.player;
    final stats = p.gamesPlayed == 0
        ? '0 場'
        : '${p.gamesPlayed} 場 · 勝 ${(p.winRate * 100).toStringAsFixed(0)}%';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(
        children: [
          PlayerAvatar(player: p, radius: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        p.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _typeBadge(context, p.type),
                  ],
                ),
                const SizedBox(height: 2),
                Text(stats, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          _menuButton(context),
        ],
      ),
    );
  }

  Widget _buildGridBody(BuildContext context) {
    final p = widget.player;
    final stats = p.gamesPlayed == 0
        ? '0 場'
        : '勝 ${(p.winRate * 100).toStringAsFixed(0)}% · ${p.gamesPlayed} 場';
    return Stack(
      children: [
        Positioned(top: 4, right: 4, child: _menuButton(context)),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PlayerAvatar(player: p, radius: 32),
              const SizedBox(height: 10),
              Text(
                p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              _typeBadge(context, p.type),
              const SizedBox(height: 6),
              Text(stats, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _typeBadge(BuildContext context, PlayerType type) {
    final isGuest = type == PlayerType.guest;
    final color = isGuest
        ? Colors.orange.shade700
        : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _menuButton(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: '更多',
      onSelected: (v) {
        switch (v) {
          case 'edit':
            widget.onEdit();
          case 'delete':
            widget.onDelete();
        }
      },
      itemBuilder: (ctx) => [
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
    final image = avatarImageProvider(_avatarPath);
    final hasAvatar = image != null;

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
                child: hasAvatar
                    ? ClipOval(
                        child: Image(
                          image: image,
                          width: 84,
                          height: 84,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.broken_image_outlined, size: 28),
                        ),
                      )
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
      showCenteredToast(context, '選取圖片失敗：$e', kind: ToastKind.warning);
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
