import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/court_score.dart';
import '../models/court_state.dart';
import '../models/player.dart';
import '../repositories/player_repository.dart';
import '../services/match_maker.dart';
import '../widgets/centered_toast.dart';
import '../widgets/court_card.dart';
import '../widgets/player_chip.dart';
import '../widgets/player_drag_handle.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key, required this.repository});

  final PlayerRepository repository;

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  final MatchMaker _matchMaker = MatchMaker();

  /// 目前每個場地上的 4 位玩家。
  List<List<Player>> _courts = [];

  /// 每個場地狀態。
  List<CourtState> _states = [];

  /// 每個場地「最近一場」的比分（結束補人後仍保留顯示，直到再次結束為止）。
  List<CourtScore?> _lastScores = [];

  /// 等待區。
  List<Player> _waiting = [];

  /// 內部事件序號，用於紀錄 Player.lastPlayedRound。
  int _eventCounter = 0;

  /// 每個場地的實時比分（teamA, teamB）；非實時模式下也維護，切換模式時不重置。
  List<(int, int)> _liveScores = [];

  /// 上一局上場的玩家 ID，用於偵測兩組固定輪替並觸發重新洗牌。
  Set<String> _lastPlayedIds = {};

  /// 上一局的隊友關係：player id → 隊友 id。
  Map<String, String?> _lastTeammates = {};

  bool get _started => _courts.isNotEmpty;

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

  void _onRepoChanged() {
    if (!mounted) return;
    setState(() {});
  }

  List<Player> _loadRoster() {
    final ids = widget.repository.activeRosterIds.toSet();
    return widget.repository.allPlayers
        .where((p) => ids.contains(p.id))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final roster = _loadRoster();
    final canStart = _matchMaker.canStart(roster.length);

    return Scaffold(
      appBar: AppBar(
        title: const Text('比賽'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: '重置',
            onPressed: _reset,
          ),
        ],
      ),
      body: roster.isEmpty
          ? _buildEmpty('尚未設定活動名單\n請先到「活動設定」頁選擇玩家')
          : !canStart
          ? _buildEmpty('名單僅 ${roster.length} 人，需至少 4 人才能開始')
          : !_started
          ? _buildReadyPanel(roster)
          : _buildMatchPanel(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: !_started
              ? FilledButton.icon(
                  onPressed: canStart ? _start : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('開始排場'),
                )
              : _buildHintBar(),
        ),
      ),
    );
  }

  Widget _buildHintBar() {
    final pendingCount = _states.where((s) => s == CourtState.pending).length;
    final msg = pendingCount == 0
        ? '所有場地進行中。結束比賽後會自動從等待區補人。'
        : '有 $pendingCount 個場地待開始，可拖拉場上玩家與等待區互換。';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ],
      ),
    );
  }

  Widget _buildEmpty(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }

  Widget _buildReadyPanel(List<Player> roster) {
    final preferred = widget.repository.preferredCourts;
    final courts = _matchMaker.resolvedCourts(roster.length, preferred);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '已載入名單 ${roster.length} 人 · 將使用 $courts 個場地',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [for (final p in roster) PlayerStatCard(player: p)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchPanel() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = _courts.length >= 2;
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _sectionTitle('比賽場地'),
            if (sideBySide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < _courts.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: _buildCourtCard(i)),
                  ],
                ],
              )
            else
              for (var i = 0; i < _courts.length; i++) _buildCourtCard(i),
            const SizedBox(height: 8),
            _sectionTitle('等待區（${_waiting.length} 人）'),
            _buildWaitingArea(),
          ],
        );
      },
    );
  }

  Widget _buildCourtCard(int i) {
    return CourtCard(
      title: 'Court ${i + 1}',
      courtIndex: i,
      players: _courts[i],
      state: _states[i],
      lastScore: _lastScores[i],
      liveScore: _liveScores[i],
      onTeamScore: (team) => _teamScore(i, team),
      onDecrementScore: (team) => _decrementTeamScore(i, team),
      onStart: () => _startCourt(i),
      onFinish: () => _finishCourt(i),
      onSwap: (from, toPlayer) =>
          _handleSwap(from: from, targetCourtIndex: i, targetPlayer: toPlayer),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _buildWaitingArea() {
    if (_waiting.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text('（全員上場，無人等待）'),
      );
    }
    final canDrag = _states.any((s) => s == CourtState.pending);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final p in _waiting) _buildWaitingChip(p, canDrag: canDrag),
        ],
      ),
    );
  }

  Widget _buildWaitingChip(Player p, {required bool canDrag}) {
    final card = PlayerStatCard(player: p);
    if (!canDrag) return card;

    final handle = PlayerDragHandle(player: p, courtIndex: null);
    final feedback = Material(color: Colors.transparent, child: card);
    final childWhenDragging = Opacity(opacity: 0.3, child: card);
    final Widget draggable = kIsWeb
        ? Draggable<PlayerDragHandle>(
            data: handle,
            feedback: feedback,
            childWhenDragging: childWhenDragging,
            child: card,
          )
        : LongPressDraggable<PlayerDragHandle>(
            data: handle,
            delay: const Duration(milliseconds: 200),
            feedback: feedback,
            childWhenDragging: childWhenDragging,
            child: card,
          );
    return DragTarget<PlayerDragHandle>(
      onWillAcceptWithDetails: (details) =>
          details.data.player.id != p.id && !details.data.fromWaiting,
      onAcceptWithDetails: (details) => _handleSwap(
        from: details.data,
        targetCourtIndex: null,
        targetPlayer: p,
      ),
      builder: (context, candidates, _) {
        final highlighted = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: highlighted
                ? Border.all(color: Colors.yellow.shade600, width: 2)
                : null,
          ),
          padding: const EdgeInsets.all(1),
          child: draggable,
        );
      },
    );
  }

  // ---- Actions ----------------------------------------------------------

  Future<void> _start() async {
    final roster = _loadRoster();
    final session = _matchMaker.startSession(
      roster: roster,
      preferredCourts: widget.repository.preferredCourts,
      balanceByWinRate: widget.repository.balanceByWinRate,
    );
    await widget.repository.setCurrentRound(1);
    setState(() {
      _courts = session.courts.map((c) => List<Player>.of(c)).toList();
      _states = List<CourtState>.filled(
        session.courts.length,
        CourtState.pending,
      );
      _lastScores = List<CourtScore?>.filled(session.courts.length, null);
      _liveScores = [for (var _ in session.courts) (0, 0)];
      _waiting = List<Player>.of(session.waiting);
      _eventCounter = 0;
      _lastPlayedIds = {};
      _lastTeammates = {};
    });
  }

  void _startCourt(int courtIndex) {
    setState(() {
      _states[courtIndex] = CourtState.playing;
      _liveScores[courtIndex] = (0, 0);
    });
  }

  /// 指定隊伍得 1 分（點擊半場觸發）。
  void _teamScore(int courtIndex, int team) {
    setState(() {
      final (a, b) = _liveScores[courtIndex];
      if (team == 0) {
        _liveScores[courtIndex] = ((a + 1).clamp(0, 99), b);
      } else {
        _liveScores[courtIndex] = (a, (b + 1).clamp(0, 99));
      }
    });
  }

  /// 整隊扣 1 分（修正用）。
  void _decrementTeamScore(int courtIndex, int team) {
    setState(() {
      final (a, b) = _liveScores[courtIndex];
      if (team == 0) {
        _liveScores[courtIndex] = ((a - 1).clamp(0, 99), b);
      } else {
        _liveScores[courtIndex] = (a, (b - 1).clamp(0, 99));
      }
    });
  }

  /// 拖拉互換：把 [from]（場地或等待區玩家）與 [targetPlayer]（場地 / 等待區）對調。
  void _handleSwap({
    required PlayerDragHandle from,
    required int? targetCourtIndex,
    required Player targetPlayer,
  }) {
    if (!from.fromWaiting && _states[from.courtIndex!] != CourtState.pending) {
      return;
    }
    if (targetCourtIndex != null &&
        _states[targetCourtIndex] != CourtState.pending) {
      return;
    }

    setState(() {
      final sourcePlayer = from.player;
      if (from.fromWaiting) {
        final i = _waiting.indexWhere((x) => x.id == sourcePlayer.id);
        if (i < 0) return;
        _waiting[i] = targetPlayer;
      } else {
        final court = _courts[from.courtIndex!];
        final i = court.indexWhere((x) => x.id == sourcePlayer.id);
        if (i < 0) return;
        court[i] = targetPlayer;
      }
      if (targetCourtIndex == null) {
        final i = _waiting.indexWhere((x) => x.id == targetPlayer.id);
        if (i < 0) return;
        _waiting[i] = sourcePlayer;
      } else {
        final court = _courts[targetCourtIndex];
        final i = court.indexWhere((x) => x.id == targetPlayer.id);
        if (i < 0) return;
        court[i] = sourcePlayer;
      }
    });
  }

  /// 結束單一場地：詢問使用者採用目前實時比分或手動輸入。
  Future<void> _finishCourt(int courtIndex) async {
    final court = _courts[courtIndex];
    final (a, b) = _liveScores[courtIndex];

    final choice = await showDialog<_FinishChoice>(
      context: context,
      builder: (ctx) => _FinishOptionsDialog(liveA: a, liveB: b),
    );
    if (choice == null || !mounted) return;

    switch (choice) {
      case _FinishChoice.useLive:
        if (a == b) {
          showCenteredToast(
            context,
            '比分相同，無法判定勝負，請繼續計分或改手動輸入',
            kind: ToastKind.warning,
          );
          return;
        }
        await _applyFinish(
          courtIndex,
          CourtScore(teamAScore: a, teamBScore: b),
        );
      case _FinishChoice.manual:
        final score = await showDialog<CourtScore>(
          context: context,
          builder: (ctx) => _ScoreInputDialog(
            teamA: court.sublist(0, 2),
            teamB: court.sublist(2, 4),
          ),
        );
        if (score == null || !mounted) return;
        await _applyFinish(courtIndex, score);
    }
  }

  /// 共用收尾：更新勝負、場次 → 從等待區補 4 人。
  Future<void> _applyFinish(int courtIndex, CourtScore score) async {
    final court = _courts[courtIndex];

    _eventCounter++;
    final roundId = _eventCounter;

    _lastTeammates[court[0].id] = court[1].id;
    _lastTeammates[court[1].id] = court[0].id;
    _lastTeammates[court[2].id] = court[3].id;
    _lastTeammates[court[3].id] = court[2].id;

    final winnerIds = switch (score.winningTeam) {
      0 => {court[0].id, court[1].id},
      1 => {court[2].id, court[3].id},
      _ => <String>{},
    };
    final justFinished = court
        .map(
          (p) => p.copyWith(
            gamesPlayed: p.gamesPlayed + 1,
            wins: p.wins + (winnerIds.contains(p.id) ? 1 : 0),
            lastPlayedRound: roundId,
            waitingRounds: 0,
          ),
        )
        .toList();

    final waitingIds = _waiting.map((p) => p.id).toSet();
    final isCycleRepeat =
        _lastPlayedIds.isNotEmpty &&
        waitingIds.length == _lastPlayedIds.length &&
        waitingIds.containsAll(_lastPlayedIds);
    final bumpedWaiting = _waiting
        .map(
          (p) => p.copyWith(
            waitingRounds: isCycleRepeat ? 0 : p.waitingRounds + 1,
          ),
        )
        .toList();

    final pool = [...justFinished, ...bumpedWaiting];
    final newPlaying = _matchMaker.pickPlayers(
      pool,
      4,
      balanceByWinRate: widget.repository.balanceByWinRate,
      lastTeammates: _lastTeammates,
    );
    final newPlayingIds = newPlaying.map((p) => p.id).toSet();
    final newWaiting = pool
        .where((p) => !newPlayingIds.contains(p.id))
        .toList();

    await widget.repository.updateAll([...justFinished, ...bumpedWaiting]);
    await widget.repository.setCurrentRound(roundId);

    setState(() {
      _courts[courtIndex] = newPlaying;
      _states[courtIndex] = CourtState.pending;
      _lastScores[courtIndex] = score;
      _liveScores[courtIndex] = (0, 0);
      _waiting = newWaiting;
      _lastPlayedIds = court.map((p) => p.id).toSet();
    });
  }

  Future<void> _reset() async {
    final roster = _loadRoster();
    final eligible = roster.where((p) => p.gamesPlayed > 0).toList();
    final Player? mvp = eligible.isEmpty
        ? null
        : eligible.reduce((a, b) => a.winRate >= b.winRate ? a : b);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _EndOfDayDialog(mvp: mvp),
    );
    if (ok == true) {
      await widget.repository.resetSession();
      setState(() {
        _courts = [];
        _states = [];
        _lastScores = [];
        _liveScores = [];
        _waiting = [];
        _eventCounter = 0;
        _lastPlayedIds = {};
        _lastTeammates = {};
      });
    }
  }
}

// ---- Dialogs ---------------------------------------------------------------

enum _FinishChoice { useLive, manual }

/// 結束本場時詢問：使用目前實時比分，或另外手動輸入。
class _FinishOptionsDialog extends StatelessWidget {
  const _FinishOptionsDialog({required this.liveA, required this.liveB});

  final int liveA;
  final int liveB;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('結束本場'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('目前實時比分', style: textTheme.labelLarge),
          const SizedBox(height: 6),
          Center(
            child: Text(
              '$liveA : $liveB',
              style: textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '要採用此比分，還是另外手動輸入？',
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _FinishChoice.manual),
          child: const Text('手動輸入'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _FinishChoice.useLive),
          child: const Text('使用此比分'),
        ),
      ],
    );
  }
}

/// 今日比賽結束 dialog：顯示 MVP（勝率最高的玩家）並確認結束。
class _EndOfDayDialog extends StatelessWidget {
  const _EndOfDayDialog({this.mvp});

  final Player? mvp;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: const Text('今日比賽結束'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (mvp != null) ...[
            const Icon(Icons.emoji_events, size: 56, color: Colors.amber),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.shade600, width: 1.5),
              ),
              child: Text(
                'MVP',
                style: TextStyle(
                  color: Colors.amber.shade800,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 3,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              mvp!.name,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '勝率 ${(mvp!.winRate * 100).toStringAsFixed(0)}%'
              '（${mvp!.wins} 勝 / ${mvp!.gamesPlayed} 場）',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ] else
            Text(
              '尚無比賽紀錄',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 12),
          Text(
            '結束後將清除本次活動狀態，累計勝場數保留。',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('結束比賽'),
        ),
      ],
    );
  }
}

/// 比分輸入 dialog：顯示兩隊名單與兩個數字輸入框。
class _ScoreInputDialog extends StatefulWidget {
  const _ScoreInputDialog({required this.teamA, required this.teamB});

  final List<Player> teamA;
  final List<Player> teamB;

  @override
  State<_ScoreInputDialog> createState() => _ScoreInputDialogState();
}

class _ScoreInputDialogState extends State<_ScoreInputDialog> {
  final _aCtrl = TextEditingController();
  final _bCtrl = TextEditingController();

  @override
  void dispose() {
    _aCtrl.dispose();
    _bCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('輸入比分'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _teamBlock(context, '隊 A', widget.teamA, _aCtrl),
            const SizedBox(height: 12),
            const Center(child: Text('VS', style: TextStyle(fontSize: 18))),
            const SizedBox(height: 12),
            _teamBlock(context, '隊 B', widget.teamB, _bCtrl),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('確定')),
      ],
    );
  }

  Widget _teamBlock(
    BuildContext context,
    String label,
    List<Player> team,
    TextEditingController ctrl,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                for (final p in team) PlayerChip(player: p),
              ],
            ),
          ),
          SizedBox(
            width: 72,
            child: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(hintText: '0'),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final a = int.tryParse(_aCtrl.text.trim());
    final b = int.tryParse(_bCtrl.text.trim());
    if (a == null || b == null) {
      showCenteredToast(context, '請輸入兩隊的比分', kind: ToastKind.warning);
      return;
    }
    if (a == b) {
      showCenteredToast(context, '比分不可相同，請判定勝負', kind: ToastKind.warning);
      return;
    }
    Navigator.pop(context, CourtScore(teamAScore: a, teamBScore: b));
  }
}
