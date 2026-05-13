import 'package:hive/hive.dart';

/// 玩家強度分級：強 / 中 / 弱。新增成員時手動指定，用於分組時的概略均衡參考。
enum PlayerStrength {
  strong,
  medium,
  weak;

  String get label {
    switch (this) {
      case PlayerStrength.strong:
        return '強';
      case PlayerStrength.medium:
        return '中';
      case PlayerStrength.weak:
        return '弱';
    }
  }
}

/// 手寫 Hive adapter（避免依賴 build_runner）。
class PlayerStrengthAdapter extends TypeAdapter<PlayerStrength> {
  @override
  final int typeId = 2;

  @override
  PlayerStrength read(BinaryReader reader) {
    final index = reader.readByte();
    if (index < 0 || index >= PlayerStrength.values.length) {
      return PlayerStrength.medium;
    }
    return PlayerStrength.values[index];
  }

  @override
  void write(BinaryWriter writer, PlayerStrength obj) {
    writer.writeByte(obj.index);
  }
}
