class Activity {
  const Activity({
    required this.id,
    required this.name,
    required this.rosterIds,
    this.preferredCourts = 1,
    this.balanceByWinRate = false,
    this.liveScoring = false,
  });

  final String id;
  final String name;
  final List<String> rosterIds;
  final int preferredCourts;
  final bool balanceByWinRate;
  final bool liveScoring;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'rosterIds': rosterIds,
    'preferredCourts': preferredCourts,
    'balanceByWinRate': balanceByWinRate,
    'liveScoring': liveScoring,
  };

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
    id: json['id'] as String,
    name: json['name'] as String,
    rosterIds: (json['rosterIds'] as List).cast<String>(),
    preferredCourts: (json['preferredCourts'] as num?)?.toInt() ?? 1,
    balanceByWinRate: json['balanceByWinRate'] as bool? ?? false,
    liveScoring: json['liveScoring'] as bool? ?? false,
  );

  Activity copyWith({
    String? name,
    List<String>? rosterIds,
    int? preferredCourts,
    bool? balanceByWinRate,
    bool? liveScoring,
  }) => Activity(
    id: id,
    name: name ?? this.name,
    rosterIds: rosterIds ?? this.rosterIds,
    preferredCourts: preferredCourts ?? this.preferredCourts,
    balanceByWinRate: balanceByWinRate ?? this.balanceByWinRate,
    liveScoring: liveScoring ?? this.liveScoring,
  );
}
