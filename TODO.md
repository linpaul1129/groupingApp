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

## ~~問題 2：實時計分~~ ✅ 已完成

**目標**：比賽進行中可以即時加分，不需要比賽結束後再手動輸入。

**實作方向**：

- `_MatchScreenState` 加入 `List<(int, int)> _liveScores`，每個場地各存 (teamAScore, teamBScore)，初始 (0, 0)。
- `CourtCard` 在 `state == CourtState.playing` 時，改為顯示兩個大分數數字，每隊旁邊加一個 `+` 按鈕（可選加 `-` 按鈕）。
- 按下 `+` 時呼叫 callback（`onScoreChanged`），`MatchScreen` 執行 `setState` 更新 `_liveScores[courtIndex]`。
- `_finishCourt` 直接讀取 `_liveScores[courtIndex]` 產生 `CourtScore`，不再 pop dialog。

**注意事項**：
- `CourtScore` 模型不需要修改。
- `_ScoreInputDialog` 可保留作為備用（讓使用者可以手動修正最終分數）。
- 場地狀態切換為 `playing` 時，重置對應的 `_liveScores[i] = (0, 0)`。

---

## 問題 3：個人得分紀錄（承接問題 2）

**目標**：記錄每一分是由哪一位玩家得到，並累計寫入個人資料。

**實作方向**：

- `Player` 加入 `points` 欄位（累計個人得分），`PlayerAdapter` 新增 field index 10，向後相容（舊資料讀到 null 時預設 0）。
- 實時計分 UI 改為顯示場上 4 位玩家各自的 `+` 按鈕，而非隊伍整體的 `+`。
  - 點擊某玩家 → 該玩家所在的隊 +1 分（同時更新 `_liveScores`），並在本地 `_sessionPoints: Map<String, int>` 累計本場得分。
- `_finishCourt` 結束時：
  - 讀取 `_sessionPoints` 中每位玩家的得分，加到 `p.copyWith(points: p.points + sessionPts)` 並寫入 Hive。
  - 清除本場地對應的 `_sessionPoints` 資料。

**注意事項**：
- `_sessionPoints` 以 player id 為 key，session 內跨多局累加，不要每局重置（除非 reset）。
- `PlayerStatCard` / 玩家管理頁面可在未來顯示個人總得分統計。

---

## 問題 4：依比分顯示發球方正確站位

**目標**：根據當前比分，在場地圖上標示發球員應站的位置（依羽球規則）。

**羽球雙打發球規則**：
- 己方總分為**偶數** → 得分球員（發球員）站**右半場**。
- 己方總分為**奇數** → 得分球員站**左半場**。
- 得分方繼續發球，發球員依奇偶換邊；失分方拿到發球權時，隊員**不換位**，以當前分數的奇偶判斷誰站哪邊。

**實作方向**：

- `_MatchScreenState` 加入 `List<ServeState?> _serveStates`，每個場地儲存：
  ```dart
  ({int servingTeam, int serverIndex}) // servingTeam: 0=隊A / 1=隊B；serverIndex: 0/1 代表隊內位置
  ```
- 場地開始時（`_startCourt`）彈出小 dialog 讓使用者選擇「哪隊先發球、由誰發」，初始化 `_serveStates[i]`。
- 每次加分時（問題 2 的 `onScoreChanged` callback）重新計算站位：
  - 得分方的發球員位置 = 依己方新分數奇偶決定左/右。
  - 若是接球方得分，發球權轉移，接球方依新接收到的發球權和自己的當前分數奇偶判斷。
- `BadmintonCourtPainter`（已存在）加入 `servePosition` 參數，在正確半場畫一個標示圓或箭頭指出發球員位置。
- 站位只需 session 內記憶，不用寫入 Hive。
