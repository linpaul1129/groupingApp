class Activity {
  const Activity({
    required this.id,
    required this.name,
    required this.rosterIds,
    this.preferredCourts = 1,
  });

  final String id;
  final String name;
  final List<String> rosterIds;
  final int preferredCourts;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'rosterIds': rosterIds,
    'preferredCourts': preferredCourts,
  };

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
    id: json['id'] as String,
    name: json['name'] as String,
    rosterIds: (json['rosterIds'] as List).cast<String>(),
    preferredCourts: (json['preferredCourts'] as num?)?.toInt() ?? 1,
  );

  Activity copyWith({
    String? name,
    List<String>? rosterIds,
    int? preferredCourts,
  }) => Activity(
    id: id,
    name: name ?? this.name,
    rosterIds: rosterIds ?? this.rosterIds,
    preferredCourts: preferredCourts ?? this.preferredCourts,
  );
}
