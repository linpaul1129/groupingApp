# Proposal：Firebase Firestore 雲端同步

## 問題陳述

玩家勝率（`gamesPlayed` / `wins`）目前存於裝置本地 Hive，換手機即歸零，無法作為跨裝置分組依據。

## 目標

- 任何裝置輸入同一個**群組碼**，即可讀寫同一份玩家資料
- 不需帳號登入
- 現有 `MatchMaker` 邏輯與 UI 不需修改
- 防止惡意讀寫與費用暴增

---

## 核心設計決策

### 群組碼（Group Code）

- 格式：10 位英數字（大小寫 + 數字，62 種字元）
- 可能組合：62¹⁰ ≈ 8.4 × 10¹⁷，實務上無法暴力破解
- 不需帳號，首次開啟 App 時輸入或掃描 QR Code

### Firestore 資料結構

```
groups/
  {groupCode}/               ← 群組根節點
    players/
      {playerId}/            ← 對應 Player.id
        name:        String
        type:        String  ("regular" | "guest")
        gamesPlayed: int
        wins:        int
        points:      int
        strength:    String  ("strong" | "medium" | "weak")
        rating:      int
        notes:       String
        updatedAt:   Timestamp
    meta/
      config/                ← 對應 app_meta
        activities_v1:      String  (JSON)
        active_activity_id: String
        preferred_courts:   int
        current_round:      int
```

> `avatarPath` 不同步至雲端（各裝置本地圖片路徑不通用）；
> `lastPlayedRound` / `waitingRounds` 屬於 session 暫態，不同步。

---

## 架構變更

### 抽出 Repository 介面

現有 `PlayerRepository` 改名為 `LocalPlayerRepository`，並新增 abstract 介面：

```dart
// lib/repositories/player_repository.dart（新）
abstract class PlayerRepository extends ChangeNotifier {
  List<Player> get allPlayers;
  Player? getById(String id);
  Future<void> upsert(Player player);
  Future<void> delete(String id);
  Future<void> updateAll(Iterable<Player> players);
  int get currentRound;
  Future<void> setCurrentRound(int round);
  int get preferredCourts;
  Future<void> setPreferredCourts(int courts);
  List<String> get activeRosterIds;
  Future<void> saveActiveRoster(List<String> ids);
  List<Activity> get activities;
  Future<void> saveActivities(List<Activity> list);
  String? get activeActivityId;
  Future<void> activateActivity(Activity activity);
  Future<void> clearActiveActivity();
  Future<void> resetSession();
}
```

新增 `FirebasePlayerRepository implements PlayerRepository`，以 Firestore 讀寫。

UI 與 `MatchMaker` **不需改動**，只在 `main.dart` 依群組碼決定注入哪個實作。

---

## 安全防護

### 1. Firebase App Check（最重要）

啟用 App Check（Android 用 Play Integrity，iOS 用 DeviceCheck），確保只有你打包的 App 可以呼叫 Firestore。繞過 App 直接打 API 的攻擊會被擋在 Firebase 層。

### 2. Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 只允許存取自己群組的資料，且必須通過 App Check
    match /groups/{groupCode}/{document=**} {
      allow read, write: if request.auth == null
                         && request.app != null;  // App Check 通過
    }
    // 其他路徑一律拒絕
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

補充規則（可選）：限制 player 文件欄位型別與數值範圍，防止資料污染。

### 3. Firebase 預算警報

在 Firebase Console → Billing → Budgets 設定每月 $1 USD 警報（免費方案超出時會暫停服務，不會繼續計費）。

---

## 實作階段

### Phase 1：抽出介面（1 天）

- 將現有 `PlayerRepository` 抽成 abstract class
- 現有實作改名 `LocalPlayerRepository`
- `main.dart` 改用介面型別注入
- 所有測試應維持通過

**驗證**：`flutter test` 全過，App 行為無變化。

### Phase 2：Firebase 專案設定（半天）

- 建立 Firebase 專案，啟用 Firestore（Production mode）
- 加入 `firebase_core`、`cloud_firestore` 套件
- 設定 App Check（Android / iOS 各自的 provider）
- 部署 Security Rules
- 設定預算警報

**驗證**：Firebase Console 顯示 App Check metrics 正常。

### Phase 3：FirebasePlayerRepository（2 天）

- 實作所有介面方法，以 Firestore stream 驅動 `notifyListeners()`
- Player ↔ Firestore document 的序列化 / 反序列化
- 離線快取（Firestore SDK 預設啟用，無網路時讀取上次快取）

**驗證**：兩支手機輸入同一群組碼，操作其中一支，另一支即時同步。

### Phase 4：群組碼 UI（1 天）

- 首次啟動顯示「輸入群組碼」或「產生新群組碼」畫面
- 群組碼儲存於本地 `SharedPreferences`（下次自動帶入）
- 設定頁提供「複製群組碼」與「產生 QR Code」功能

**驗證**：新裝置掃描 QR Code 後，玩家名單與勝率完整呈現。

### Phase 5：現有資料遷移（半天）

見下節。

---

## 現有本機勝率資料遷移

### 操作方式（手動觸發，一次性）

在「玩家管理頁」加一個「上傳本機資料至雲端」按鈕（Phase 4 完成後才出現）：

1. 讀取 `LocalPlayerRepository.allPlayers`
2. 對每位玩家，以 `id` 查詢 Firestore 是否已存在：
   - **不存在**：直接寫入
   - **已存在**：合併策略——取兩者中較大的 `gamesPlayed` 與 `wins`（避免覆蓋掉其他裝置已累積的資料）
3. 顯示上傳結果（N 位玩家已同步）

### 你現在可以做的事

**在 Phase 3 實作前，先把現有的勝率資料記錄下來，避免遺失：**

1. 開啟 App，進入「玩家管理頁」
2. 截圖或手動記錄每位玩家的 `場數` 與 `勝率`（Chip 上有顯示）
3. Phase 5 完成後，系統會自動幫你上傳，或你可以手動在 Firebase Console 補填

> 若你有開發環境，也可以在實作 Phase 1 後執行一段 migration script，
> 直接從 Hive 讀出資料並寫入 Firestore，不需手動記錄。

---

## 套件異動

```yaml
# pubspec.yaml 新增
dependencies:
  firebase_core: ^3.x
  cloud_firestore: ^5.x
  firebase_app_check: ^0.3.x
  shared_preferences: ^2.x   # 儲存群組碼（若尚未引入）
```

---

## 不在本 Proposal 範圍內

- 頭像雲端同步（需 Firebase Storage，複雜度另計）
- 多群組管理（單一裝置同時屬於多個球隊）
- 對戰紀錄查詢（`MatchRecord` model，預留擴充點）
