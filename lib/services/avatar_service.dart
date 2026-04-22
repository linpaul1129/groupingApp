import 'dart:convert';
import 'dart:io' show Directory, File, Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// 取得 / 儲存 / 刪除玩家頭像。
///
/// - Native（iOS / Android / Windows / macOS / Linux）：把選到的圖 **複製一份** 到
///   app documents 目錄的 `avatars/` 之下，`avatarPath` 存放該檔案絕對路徑。
/// - Web：`path_provider` 不支援，改為將圖片讀成 bytes 後以 `data:image/...;base64,...`
///   字串存入 `avatarPath`，由 [avatarImageProvider] 還原成 `MemoryImage`。
class AvatarService {
  AvatarService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// 彈出系統圖片選擇器，若使用者取消回傳 null；否則回傳保存後的 avatarPath。
  Future<String?> pickAndSave() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null) return null;

    if (kIsWeb) {
      final ext = file.name.split('.').last.toLowerCase();
      if (ext == 'heic' || ext == 'heif') {
        throw UnsupportedError('不支援 HEIC / HEIF 格式，請選 JPG、PNG 或 WebP 圖片');
      }
      final bytes = await file.readAsBytes();
      final mime = _mimeFromName(file.name);
      return 'data:$mime;base64,${base64Encode(bytes)}';
    }
    return _copyIntoAppDir(file.path);
  }

  /// 刪除之前保存的頭像檔（若存在）。錯誤會被吞掉，不影響主流程。
  /// Web 上 avatarPath 為 data URL，不需刪除。
  Future<void> deleteIfExists(String? path) async {
    if (path == null || path.isEmpty) return;
    if (kIsWeb || path.startsWith('data:')) return;
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

  String _mimeFromName(String name) {
    final dot = name.lastIndexOf('.');
    final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'bmp' => 'image/bmp',
      _ => 'image/png',
    };
  }
}

/// 把 avatarPath（檔案路徑 or data URL）轉成 [ImageProvider]；若路徑無效回傳 null。
///
/// 同時解決 `File(path).existsSync()` 在 web 無法使用的問題。
ImageProvider? avatarImageProvider(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('data:')) {
    final comma = path.indexOf(',');
    if (comma < 0) return null;
    final b64 = path.substring(comma + 1);
    try {
      final bytes = base64Decode(b64);
      return MemoryImage(Uint8List.fromList(bytes));
    } catch (_) {
      return null;
    }
  }
  if (kIsWeb) return null; // 非 data URL 的外部檔案路徑在 web 無法讀取
  final f = File(path);
  if (!f.existsSync()) return null;
  return FileImage(f);
}
