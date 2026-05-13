import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/activity.dart';
import '../models/player.dart';
import '../models/player_strength.dart';
import '../models/player_type.dart';

/// 玩家資料 Repository：把 Hive 的細節都藏在這一層，
/// 使 UI / service 只依賴純粹的 [Player] 型別。
///
/// 未來若要改接後端（例如 Firebase Firestore），只需要替換此檔的實作。
class PlayerRepository extends ChangeNotifier {
  PlayerRepository._(this._playerBox, this._metaBox);

  static const String _playerBoxName = 'players';
  static const String _metaBoxName = 'app_meta';
  static const String _currentRoundKey = 'current_round';
  static const String _preferredCourtsKey = 'preferred_courts';
  static const String _rosterKey = 'active_roster_ids';
  static const String _activitiesKey = 'activities_v1';
  static const String _activeActivityIdKey = 'active_activity_id';

  final Box<Player> _playerBox;
  final Box _metaBox;

  /// 註冊 Hive adapters。main.dart 啟動時呼叫一次即可。
  static void registerAdapters() {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PlayerTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(PlayerAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(PlayerStrengthAdapter());
    }
  }

  /// 開啟 box 並建立 repository 實例。
  static Future<PlayerRepository> open() async {
    registerAdapters();
    final playerBox = await Hive.openBox<Player>(_playerBoxName);
    final metaBox = await Hive.openBox(_metaBoxName);
    final repo = PlayerRepository._(playerBox, metaBox);
    await repo._migrateIfNeeded();
    return repo;
  }

  /// 若 activities 為空但舊有名單存在，自動建立一筆「預設活動」。
  Future<void> _migrateIfNeeded() async {
    final raw = _metaBox.get(_activitiesKey);
    if (raw != null) return;
    final existingRoster = activeRosterIds;
    if (existingRoster.isEmpty) return;
    final defaultActivity = Activity(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: '預設活動',
      rosterIds: existingRoster,
      preferredCourts: preferredCourts,
    );
    await _writeActivities([defaultActivity]);
    await _metaBox.put(_activeActivityIdKey, defaultActivity.id);
  }

  // ---- Player CRUD -------------------------------------------------------

  List<Player> get allPlayers => _playerBox.values.toList(growable: false);

  Player? getById(String id) => _playerBox.get(id);

  Future<void> upsert(Player player) async {
    await _playerBox.put(player.id, player);
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await _playerBox.delete(id);
    // 若此玩家在目前名單中，順便移除。
    final roster = activeRosterIds;
    if (roster.contains(id)) {
      await saveActiveRoster(roster.where((e) => e != id).toList());
    }
    // 從所有活動的名單中移除。
    final current = activities;
    if (current.any((a) => a.rosterIds.contains(id))) {
      await _writeActivities(
        current
            .map(
              (a) => a.copyWith(
                rosterIds: a.rosterIds.where((e) => e != id).toList(),
              ),
            )
            .toList(),
      );
    }
    notifyListeners();
  }

  /// 批次覆寫（主要在 [MatchMaker.commitRound] 後套用）。
  Future<void> updateAll(Iterable<Player> players) async {
    final map = {for (final p in players) p.id: p};
    await _playerBox.putAll(map);
    notifyListeners();
  }

  // ---- Session state（上次活動狀態，可選） ------------------------------

  int get currentRound =>
      _metaBox.get(_currentRoundKey, defaultValue: 0) as int;

  Future<void> setCurrentRound(int round) async {
    await _metaBox.put(_currentRoundKey, round);
    notifyListeners();
  }

  int get preferredCourts =>
      _metaBox.get(_preferredCourtsKey, defaultValue: 1) as int;

  Future<void> setPreferredCourts(int courts) async {
    await _metaBox.put(_preferredCourtsKey, courts);
    notifyListeners();
  }

  List<String> get activeRosterIds {
    final raw = _metaBox.get(_rosterKey, defaultValue: <String>[]);
    if (raw is List) {
      return raw.cast<String>();
    }
    return const <String>[];
  }

  Future<void> saveActiveRoster(List<String> ids) async {
    await _metaBox.put(_rosterKey, ids);
    notifyListeners();
  }

  // ---- Activities --------------------------------------------------------

  List<Activity> get activities {
    final raw = _metaBox.get(_activitiesKey, defaultValue: '[]');
    if (raw is! String) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((e) => Activity.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveActivities(List<Activity> list) async {
    await _writeActivities(list);
    notifyListeners();
  }

  Future<void> _writeActivities(List<Activity> list) async {
    await _metaBox.put(
      _activitiesKey,
      jsonEncode(list.map((a) => a.toJson()).toList()),
    );
  }

  String? get activeActivityId => _metaBox.get(_activeActivityIdKey) as String?;

  /// 啟用活動：同步更新 MatchScreen 使用的舊有設定 key。
  Future<void> activateActivity(Activity activity) async {
    await _metaBox.put(_activeActivityIdKey, activity.id);
    await _metaBox.put(_rosterKey, activity.rosterIds);
    await _metaBox.put(_preferredCourtsKey, activity.preferredCourts);
    notifyListeners();
  }

  Future<void> clearActiveActivity() async {
    await _metaBox.delete(_activeActivityIdKey);
    notifyListeners();
  }

  // ---- Reset -------------------------------------------------------------

  /// 重置活動：歸零輪次、清空 waitingRounds / lastPlayedRound（但保留
  /// 累計 gamesPlayed / wins 作為歷史統計）。
  Future<void> resetSession() async {
    await setCurrentRound(0);
    final cleaned = allPlayers
        .map((p) => p.copyWith(waitingRounds: 0, lastPlayedRound: -1))
        .toList();
    await updateAll(cleaned);
  }
}
