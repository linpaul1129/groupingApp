import 'package:hive/hive.dart';

import 'player_type.dart';

/// 玩家資料模型。
///
/// 欄位設計同時考慮 Phase 1 分組需要（waitingRounds / lastPlayedRound）
/// 與 Phase 2 持久化（gamesPlayed / wins）；另外預留了 [rating] 與
/// [notes] 以便未來加入「智能配對 / 對戰紀錄」時不必修改資料結構。
class Player {
  Player({
    required this.id,
    required this.name,
    this.type = PlayerType.regular,
    this.gamesPlayed = 0,
    this.wins = 0,
    this.lastPlayedRound = -1,
    this.waitingRounds = 0,
    this.rating = 1000,
    this.notes = '',
    this.avatarPath,
  });

  final String id;
  String name;
  PlayerType type;

  /// 頭像檔案絕對路徑（存放在 app documents 目錄）；null 代表未設定。
  String? avatarPath;

  /// 累計上場次數。
  int gamesPlayed;

  /// 勝場（欄位預留，Phase 1 不會變動）。
  int wins;

  /// 最後一次上場的輪次（-1 代表尚未上場）。
  int lastPlayedRound;

  /// 連續等待的輪數，分組時作為優先級使用。
  int waitingRounds;

  /// 預留：玩家強度（Phase 3 智能配對）。
  int rating;

  /// 預留：備註欄。
  String notes;

  Player copyWith({
    String? name,
    PlayerType? type,
    int? gamesPlayed,
    int? wins,
    int? lastPlayedRound,
    int? waitingRounds,
    int? rating,
    String? notes,
    Object? avatarPath = _sentinel,
  }) {
    return Player(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      wins: wins ?? this.wins,
      lastPlayedRound: lastPlayedRound ?? this.lastPlayedRound,
      waitingRounds: waitingRounds ?? this.waitingRounds,
      rating: rating ?? this.rating,
      notes: notes ?? this.notes,
      avatarPath: identical(avatarPath, _sentinel)
          ? this.avatarPath
          : avatarPath as String?,
    );
  }

  static const Object _sentinel = Object();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Player && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// 手寫 Hive TypeAdapter，避免 code-gen 依賴。
class PlayerAdapter extends TypeAdapter<Player> {
  @override
  final int typeId = 1;

  @override
  Player read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < fieldCount; i++) reader.readByte(): reader.read(),
    };
    return Player(
      id: fields[0] as String,
      name: fields[1] as String,
      type: fields[2] as PlayerType? ?? PlayerType.regular,
      gamesPlayed: fields[3] as int? ?? 0,
      wins: fields[4] as int? ?? 0,
      lastPlayedRound: fields[5] as int? ?? -1,
      waitingRounds: fields[6] as int? ?? 0,
      rating: fields[7] as int? ?? 1000,
      notes: fields[8] as String? ?? '',
      avatarPath: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Player obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.gamesPlayed)
      ..writeByte(4)
      ..write(obj.wins)
      ..writeByte(5)
      ..write(obj.lastPlayedRound)
      ..writeByte(6)
      ..write(obj.waitingRounds)
      ..writeByte(7)
      ..write(obj.rating)
      ..writeByte(8)
      ..write(obj.notes)
      ..writeByte(9)
      ..write(obj.avatarPath);
  }
}
