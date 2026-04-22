# 羽球分組管理 App

一個以 Flutter 開發、可在球場現場使用的羽球分組 / 輪替 App。  
支援 **等待輪數公平排場**、**勝率平衡分組**、玩家頭像、本地持久化（Hive）。

## 執行方式

```bash
flutter pub get
flutter run
# 單元測試
flutter test
```

> 開發環境：Flutter 3.41.x / Dart 3.11.x。

## 專案結構

```
lib/
  main.dart                      // 入口；初始化 Hive 並啟動 HomeScreen
  models/
    player.dart                  // Player 資料模型 + 手寫 Hive TypeAdapter
    player_type.dart             // PlayerType 枚舉（Regular / Guest）+ Adapter
    round_result.dart            // match_maker 的輸出
    court_score.dart             // 場地比分
    court_state.dart             // 場地狀態（pending / playing）
    session_config.dart          // 本次活動設定
  services/
    match_maker.dart             // 分組 / 輪替 / 勝率平衡核心邏輯（純函式、可測）
    avatar_service.dart          // 頭像存取（native 存檔 / web 轉 base64）
  repositories/
    player_repository.dart       // Hive 持久化；CRUD、活動狀態與功能設定
  screens/
    home_screen.dart             // 底部導覽（玩家 / 活動設定 / 比賽）
    player_management_screen.dart
    session_setup_screen.dart
    match_screen.dart            // 主畫面：Court 1/2 左右並排、等待區
  widgets/
    player_chip.dart             // 玩家徽章（顯示勝率）
    player_avatar.dart
    court_card.dart              // 場地卡片；支援拖拉互換
    badminton_court_painter.dart
    player_drag_handle.dart
test/
  widget_test.dart               // MatchMaker 單元測試
```

分層原則：UI 只讀 / 寫 `PlayerRepository`；分組邏輯集中於 `MatchMaker`，不觸碰 UI 與儲存。

## 玩家資料

| 欄位 | 說明 |
| --- | --- |
| `id` | 唯一識別（以 microsecondsSinceEpoch 產生） |
| `name` | 名稱 |
| `type` | `Regular`（固定）/ `Guest`（零打） |
| `avatarPath` | 頭像路徑（native）或 `data:image/…;base64,…`（web） |
| `gamesPlayed` | 累計上場次數 |
| `wins` | 累計勝場 |
| `winRate` | 勝率 `wins / gamesPlayed`（`gamesPlayed == 0` 時為 0.0，computed getter） |
| `lastPlayedRound` | 最後上場輪次（-1 表未上場） |
| `waitingRounds` | 連續等待輪數（排場優先級） |
| `rating` | 預留：玩家強度評分（預設 1000） |
| `notes` | 預留：備註 |

## 場地與人數規則

| 人數 | 行為 |
| --- | --- |
| < 4 | 提示不可開始 |
| 4 ~ 7 | 自動使用 1 場地 |
| ≥ 8 | 可選擇 1 或 2 場地（尊重使用者選擇） |
| > 14 | 超出上限（`SessionSetupScreen` 禁止勾選） |

當使用 2 場地時，Court 1 與 Court 2 **左右並排**顯示。

## 分組演算法（`match_maker.dart`）

### 核心 API

```dart
// 初始化活動，回傳第一批上場者與等待區
({List<List<Player>> courts, List<Player> waiting}) startSession({
  required List<Player> roster,
  required int preferredCourts,
  bool balanceByWinRate = false,
});

// 每場結束後從候選池補 N 位上場者
List<Player> pickPlayers(
  List<Player> candidates,
  int needed, {
  bool balanceByWinRate = false,
});
```

### 選人步驟

1. 依 `roster.length` 與 `preferredCourts` 算出本輪場地數（`resolvedCourts`），需要人數 = 場地數 × 4。
2. 將 roster **洗牌一次**，作為同優先級下的隨機基礎。
3. 以 **`waitingRounds` 由大到小** 做穩定排序；相同者維持洗牌後順序（即隨機）。
4. 取前 N 位為本輪上場。

### 勝率平衡分組（`balanceByWinRate = true`）

選出 4 人後，進行第二步**平衡分隊**：

- 枚舉 4 人的全部 3 種 2v2 分法：`{0,1}vs{2,3}`、`{0,2}vs{1,3}`、`{0,3}vs{1,2}`。
- 計算每種分法的兩隊 `winRate` 總和差，取差值最小者。
- 回傳順序 `[隊A a0, 隊A a1, 隊B b0, 隊B b1]`，與 `CourtCard` 的切割約定一致。
- 若所有玩家 `gamesPlayed == 0`（全新活動），三種分法差距皆為 0，退化為選人後的隨機順序。

### 為什麼「waitingRounds 優先」能自動避免連續上場？

- 上一輪剛上場者在結束後 `waitingRounds` 歸 0，等待者 `waitingRounds += 1`。
- 下一輪排序時，等待者自動排在候選順位最前面——只有**人數不足**才會再次選到剛打完的人，不需要額外規則。

## 資料儲存（Hive）

- Box 名稱：
  - `players`：儲存 `Player`（typeId=1）
  - `app_meta`：活動狀態與功能設定

| `app_meta` 鍵值 | 說明 |
| --- | --- |
| `current_round` | 目前輪次 |
| `preferred_courts` | 偏好場地數（1 或 2） |
| `active_roster_ids` | 本次活動名單 ID 清單 |
| `balance_by_win_rate` | 是否啟用勝率平衡分組（bool，預設 false） |

- 採**手寫 TypeAdapter** 以避免 `build_runner` 依賴。
- `PlayerRepository` 繼承 `ChangeNotifier`，任何變動會通知 UI 重繪。

### 重置活動（Reset）

清除本次 session：`currentRound=0`，每位玩家的 `waitingRounds=0`、`lastPlayedRound=-1`；  
**保留** `gamesPlayed` 與 `wins`（歷史統計）。

## UI 流程

1. **玩家管理頁**：新增 / 刪除玩家，切換固定 / 零打，上傳頭像（JPG / PNG / WebP）。
2. **活動設定頁**：
   - 勾選名單（上限 14 人）、選擇 1 / 2 場地。
   - 開關「**勝率平衡分組**」（啟用後每場自動挑最均衡的 2v2）。
   - 頁面即時顯示「實際將啟用幾個場地」。
3. **比賽頁**（主畫面）：
   - 尚未開始：顯示名單與場地數，按「開始排場」生成第 1 輪。
   - 進行中：顯示 Court 1 / 2（兩場地時左右並排）、等待區；可拖拉玩家互換位置。
   - 每場結束輸入比分，系統自動從候選池（剛下場 + 等待區）補滿 4 人。
   - 右上「重置」回到初始狀態。

## 玩家 Chip 顯示

| `gamesPlayed` | 顯示格式 |
| --- | --- |
| 0 | `0場` |
| > 0 | `N場·勝XX%` |

## 頭像處理

- **Native**（iOS / Android / Windows / macOS）：圖片複製到 app documents `avatars/` 目錄。
- **Web**：讀取 bytes 轉 `data:image/…;base64,…` 儲存。
- 不支援 HEIC / HEIF（Safari / iOS 相簿常見格式），選取時會提示改用 JPG / PNG / WebP。
- 顯示失敗時 fallback 為姓名首字圓形頭像。

## 預留擴充點

| 擴充項 | 預留位置 |
| --- | --- |
| ELO / 動態評分 | `Player.rating` 欄位已存在，`MatchMaker` 可依 rating 做跨場地強度均衡 |
| 對戰紀錄查詢 | 新增 `MatchRecord` model + `MatchHistoryRepository` |
| 跨場地強度均衡 | 2 場地時讓兩場整體 `winRate` 相近 |

## 未來如何接入後端（例如 Firebase）

UI 與邏輯都僅依賴 `PlayerRepository` 介面，後端切換可「換掉 repository 實作即可」：

1. 現有 `PlayerRepository` 改為 `LocalPlayerRepository implements PlayerRepository`，抽出 `abstract class PlayerRepository`。
2. 新增 `FirebasePlayerRepository`，以 `cloud_firestore` 讀寫 `players` / `sessions` collection。
3. 使用 `StreamBuilder` 或 Riverpod/Provider 注入，UI 不需改動。
4. `MatchMaker` 是純邏輯、不涉 IO，可直接保留。

---

## 實作備註

- 所有 Hive 操作在 `PlayerRepository` 內；UI 不直接引用 `hive`。
- `MatchMaker` 的隨機性可注入（`MatchMaker(random: Random(seed))`），方便撰寫測試。
- UI 使用 Material 3（`useMaterial3: true`）與 `NavigationBar`。
- Flutter Web 上拖拉改用 `Draggable`（非 `LongPressDraggable`），避免與 `ListView` 滾動手勢衝突。
