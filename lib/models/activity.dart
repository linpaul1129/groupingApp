class Activity {
  const Activity({
    required this.id,
    required this.name,
    required this.rosterIds,
    this.preferredCourts = 1,
    this.balanceByWinRate = false,
  });

  final String id;
  final String name;
  final List<String> rosterIds;
  final int preferredCourts;
  final bool balanceByWinRate;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'rosterIds': rosterIds,
    'preferredCourts': preferredCourts,
    'balanceByWinRate': balanceByWinRate,
  };

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
    id: json['id'] as String,
    name: json['name'] as String,
    rosterIds: (json['rosterIds'] as List).cast<String>(),
    preferredCourts: (json['preferredCourts'] as num?)?.toInt() ?? 1,
    balanceByWinRate: json['balanceByWinRate'] as bool? ?? false,
  );

  Activity copyWith({
    String? name,
    List<String>? rosterIds,
    int? preferredCourts,
    bool? balanceByWinRate,
  }) => Activity(
    id: id,
    name: name ?? this.name,
    rosterIds: rosterIds ?? this.rosterIds,
    preferredCourts: preferredCourts ?? this.preferredCourts,
    balanceByWinRate: balanceByWinRate ?? this.balanceByWinRate,
  );
}
