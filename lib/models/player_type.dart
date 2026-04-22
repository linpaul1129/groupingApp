import 'package:hive/hive.dart';

/// 玩家類型：固定班底（Regular）或零打（Guest）。
enum PlayerType {
  regular,
  guest;

  String get label {
    switch (this) {
      case PlayerType.regular:
        return '固定';
      case PlayerType.guest:
        return '零打';
    }
  }
}

/// 手寫 Hive adapter（避免依賴 build_runner）。
class PlayerTypeAdapter extends TypeAdapter<PlayerType> {
  @override
  final int typeId = 0;

  @override
  PlayerType read(BinaryReader reader) {
    final index = reader.readByte();
    return PlayerType.values[index];
  }

  @override
  void write(BinaryWriter writer, PlayerType obj) {
    writer.writeByte(obj.index);
  }
}
