# CLAUDE.md

## 專案說明

羽球分組管理 Flutter App。

## 開發規則

### 格式化

每次修改完 Dart 檔案後，**必須**在 commit 前執行：

```bash
dart format .
```

CI 會用 `dart format --output=none --set-exit-if-changed .` 檢查格式，未格式化的檔案會導致 CI 失敗。
