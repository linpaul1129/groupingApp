/// 本次活動的基本設定。
class SessionConfig {
  SessionConfig({required this.rosterIds, this.preferredCourts = 1});

  /// 本次活動名單（玩家 id 集合）。
  final List<String> rosterIds;

  /// 使用者選擇的場地數（1 或 2）。實際會依人數自動降為 1。
  final int preferredCourts;

  SessionConfig copyWith({List<String>? rosterIds, int? preferredCourts}) {
    return SessionConfig(
      rosterIds: rosterIds ?? this.rosterIds,
      preferredCourts: preferredCourts ?? this.preferredCourts,
    );
  }
}
