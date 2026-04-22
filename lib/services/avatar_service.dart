import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// 取得 / 儲存 / 刪除玩家頭像的小工具。
///
/// - 透過 [ImagePicker] 讓使用者選圖（支援 iOS / Android / Windows / macOS / Linux）。
/// - 會把選到的圖 **複製一份** 到 app documents 目錄的 `avatars/` 之下，
///   避免 gallery 的快取檔被清掉造成圖片失效。
class AvatarService {
  AvatarService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// 彈出系統圖片選擇器，若使用者取消回傳 null；否則回傳複製後的新路徑。
  Future<String?> pickAndSave() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null) return null;
    return _copyIntoAppDir(file.path);
  }

  /// 刪除之前保存的頭像檔（若存在）。錯誤會被吞掉，不影響主流程。
  Future<void> deleteIfExists(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // ignore
    }
  }

  Future<String> _copyIntoAppDir(String sourcePath) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/avatars');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final ext = _extensionOf(sourcePath);
    final newPath =
        '${dir.path}/avatar_${DateTime.now().microsecondsSinceEpoch}$ext';
    await File(sourcePath).copy(newPath);
    return newPath;
  }

  String _extensionOf(String path) {
    final slash = path.lastIndexOf(Platform.pathSeparator);
    final name = slash >= 0 ? path.substring(slash + 1) : path;
    final dot = name.lastIndexOf('.');
    if (dot < 0) return '';
    return name.substring(dot);
  }
}
