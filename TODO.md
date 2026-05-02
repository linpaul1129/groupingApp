# TODO

---

## 功能：Google 登入 + Firebase 雲端資料同步

> **設計原則**：未登入維持現有 Hive 本地儲存行為不變；登入後資料改存 Firestore，頭像改存 Firebase Storage。資料層以 interface 隔離，切換時 UI 層無感。

### 任務 1：Firebase 專案與環境設定（手動）

- 在 [Firebase Console](https://console.firebase.google.com/) 建立新專案
- Authentication → 啟用 **Google** 登入方式
- Firestore Database → 建立資料庫（production 模式，之後設 rules）
- Storage → 啟用（用於頭像）
- 下載並放入：
  - `android/app/google-services.json`
  - `ios/Runner/GoogleService-Info.plist`
- 更新 `android/build.gradle`、`android/app/build.gradle` 加入 Google services plugin
- 更新 `ios/Podfile` 最低版本（Firebase iOS SDK 需要 iOS 13+）

---

### 任務 2：加入套件依賴

在 `pubspec.yaml` 新增：

```yaml
firebase_core: ^3.x
firebase_auth: ^5.x
google_sign_in: ^6.x
cloud_firestore: ^5.x
firebase_storage: ^12.x
```

執行 `flutter pub get`。

---

### 任務 3：建立 `AuthService`

新增 `lib/services/auth_service.dart`：

- `Stream<User?> authStateChanges` — 監聽登入狀態
- `Future<UserCredential?> signInWithGoogle()` — 觸發 Google 登入流程
- `Future<void> signOut()` — 登出
- `User? get currentUser` — 取得目前使用者
- 在 `main.dart` 初始化 Firebase（`await Firebase.initializeApp()`）並將 `AuthService` 注入至 widget tree（`Provider` 或 `InheritedWidget`）

---

### 任務 4：資料層抽象化

將現有 `PlayerRepository` 拆成三層：

1. **`lib/repositories/player_data_source.dart`**（abstract interface）
   - 定義 `getPlayers()`、`upsert()`、`delete()`、`getSessionConfig()` 等方法簽名

2. **`lib/repositories/local_player_repository.dart`**
   - 把現有 `player_repository.dart` 的 Hive 實作搬過來，實作上面的 interface

3. **`lib/repositories/firestore_player_repository.dart`**（新建）
   - Firestore 路徑：`users/{uid}/players/{playerId}`
   - Session 設定路徑：`users/{uid}/session`（document，存 current_round、preferred_courts 等）
   - 實作相同 interface，讓上層 UI 無感切換

4. **更新 `PlayerRepository`**（或新建 `RepositoryProvider`）
   - 監聽 `AuthService.authStateChanges`
   - 未登入 → 使用 `LocalPlayerRepository`
   - 登入 → 使用 `FirestorePlayerRepository`（uid 帶入）
   - 切換時通知 UI 重新 build

---

### 任務 5：登入時本地資料遷移

- 使用者**第一次**登入且本地 Hive 有資料時，顯示 dialog 詢問：
  - **「上傳本地資料到雲端」** → 將本地 players 全數寫入 Firestore，本地 Hive 清空
  - **「捨棄本地資料，重新開始」** → 直接切換，不上傳
- 遷移完成後不再詢問（在 Hive `app_meta` 存一個 `migration_done` flag）

---

### 任務 6：頭像儲存切換

- 登入狀態下，`AvatarService.pickAndSave()` 改上傳至 Firebase Storage
  - 路徑：`avatars/{uid}/{playerId}`
  - `Player.avatarPath` 改存 Storage 下載 URL（`https://...`）
- 未登入維持現有本地檔案路徑或 base64 行為不變
- `AvatarService.avatarImageProvider()` 已支援 URL，應可直接相容；確認 `NetworkImage` 路徑正常即可

---

### 任務 7：登入 / 登出 UI

- `HomeScreen` 右上角加入 icon button：
  - 未登入 → 顯示 `Icons.account_circle_outlined`，點擊 → 觸發 `AuthService.signInWithGoogle()`
  - 已登入 → 顯示 Google 帳號頭像，點擊 → 彈出小 menu（顯示 email + 登出按鈕）
- 登入/登出過程顯示 loading indicator，失敗顯示 SnackBar 錯誤訊息

---

### 任務 8：Firestore Security Rules

設定規則確保只有本人可以讀寫自己的資料：

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

Firebase Storage 同理設定。

---