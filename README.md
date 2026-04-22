# 羽球分組管理 App

一個以 Flutter 開發、可在球場現場使用的羽球分組 / 輪替 App。
包含 **Phase 1（MVP 分組邏輯）** 與 **Phase 2（本地資料持久化 / Hive）**，並預留升級後端與智能配對的擴充點。

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
  main.dart                     // 入口；初始化 Hive 並啟動 HomeScreen
  models/
    player.dart                 // Player 資料模型 + 手寫 Hive TypeAdapter
    player_type.dart            // PlayerType 枚舉（Regular / Guest）+ Adapter
    round_result.dart           // match_maker 的輸出
    session_config.dart         // 本次活動設定
  services/
    match_maker.dart            // 分組 / 輪替核心邏輯（純函式、可測）
  repositories/
    player_repository.dart      // Hive 持久化；CRUD、活動狀態保存
  screens/
    home_screen.dart            // 底部導覽（玩家 / 活動設定 / 比賽）
    player_management_screen.dart
    session_setup_screen.dart
    match_screen.dart           // 主畫面：Court 1/2、下一輪預覽、等待區
  widgets/
    player_chip.dart
    court_card.dart
test/
  widget_test.dart              // MatchMaker 單元測試
```

分層原則：UI 只讀 / 寫 `PlayerRepository`；分組邏輯集中於 `MatchMaker`，不觸碰 UI 與儲存。

## 玩家資料

| 欄位 | 說明 |
| --- | --- |
| `id` | 唯一識別（以 microsecondsSinceEpoch 產生） |
| `name` | 名稱 |
| `type` | `Regular`（固定）/ `Guest`（零打） |
| `gamesPlayed` | 累計上場次數 |
| `wins` | 勝場（Phase 1 保留欄位） |
| `lastPlayedRound` | 最後上場輪次（-1 表未上場） |
| `waitingRounds` | 連續等待輪數（排場優先級） |
| `rating` | 預留：玩家強度（未來智能配對） |
| `notes` | 預留：備註 |

## 場地與人數規則

| 人數 | 行為 |
| --- | --- |
| < 4 | 提示不可開始 |
| 4 ~ 7 | 自動使用 1 場地 |
| ≥ 8 | 可選擇 1 或 2 場地（預設尊重使用者選擇） |
| > 14 | 超出上限（`SessionSetupScreen` 禁止勾選） |

## 分組演算法（`match_maker.dart`）

核心方法：

```dart
RoundResult buildRound({
  required List<Player> roster,
  required int preferredCourts,
  required int roundNumber,
});

void commitRound({
  required List<Player> roster,
  required RoundResult result,
});
```

### 選人步驟

1. 依 `roster.length` 與 `preferredCourts` 算出本輪要用幾個場地（`resolvedCourts`），需要人數 = 場地數 × 4。
2. 將 roster **洗牌一次**，作為同優先級下的隨機基礎。
3. 以 **`waitingRounds` 由大到小** 做穩定排序；相同者維持洗牌後順序（即隨機）。
4. 取前 N 位為本輪上場；依序平均切成 1 或 2 個場地。

### 為什麼「waitingRounds 優先」同時也滿足「避免連續上場」？

- 上一輪剛上場的人在 `commitRound` 中會被把 `waitingRounds` 歸 0。
- 未上場的人 `waitingRounds += 1`。
- 下一輪排序時，等待者自動排在候選順位最前面，只有當 **人數不足** 時才會再次輪到剛打完的人——這就自然符合規格書中「同一玩家連續上場（除非人數不足）」的要求，不需要額外規則。

### 下一輪預覽

`buildRound` 會在不修改輸入 roster 的前提下：
1. 先產出本輪 result；
2. 於記憶體中模擬 commit 後的 roster 狀態；
3. 再跑一次演算法，回傳 `nextRoundPreview`。

### 每輪結束套用

`commitRound` 會 in-place 更新 roster：

- 上場者：`waitingRounds = 0`、`gamesPlayed += 1`、`lastPlayedRound = roundNumber`
- 未上場者：`waitingRounds += 1`

接著由 `PlayerRepository.updateAll(...)` 批次寫回 Hive。

## 資料儲存（Phase 2）

- 使用 `hive` + `hive_flutter`，box 名稱：
  - `players`：儲存 `Player`（typeId=1）
  - `app_meta`：目前輪次、場地偏好、活動名單 id
- 採 **手寫 TypeAdapter** 以避免 `build_runner` 依賴。
- `PlayerRepository` 繼承 `ChangeNotifier`，任何變動都會通知 UI 重繪（各畫面自行 `addListener`）。

### 重置活動（Reset）

清除本次活動 session：`currentRound=0`，每位玩家的 `waitingRounds=0`、`lastPlayedRound=-1`；
**保留** `gamesPlayed` 與 `wins`（視為歷史統計）。

## UI 流程

1. **玩家管理頁**：新增 / 刪除玩家，切換固定 / 零打。
2. **活動設定頁**：勾選名單（上限 14）、選擇 1 / 2 場地；頁面會即時顯示「實際將啟用幾個場地」。
3. **比賽頁**（主畫面）：
   - 尚未開始：顯示名單與將使用的場地數，按下「開始排場」生成第 1 輪。
   - 進行中：顯示本輪 Court 1/2、下一輪預覽、等待區；「下一輪」按鈕會 commit 並產生下一輪。
   - 右上「重置」：回到初始狀態。

## 預留擴充點

| 擴充項 | 預留位置 |
| --- | --- |
| Rating（強度） | `Player.rating` 欄位已存在；`MatchMaker` 未來可依 rating 做分組平衡 |
| Match History | 新增 `MatchRecord` model + `MatchHistoryRepository`，在 `commitRound` 時一併記錄 |
| 智能配對 | 在 `MatchMaker._pickPlayers` 後加入 `_balanceCourts(picked)`，以 rating 做左右場分配 |

## 未來如何接入後端（例如 Firebase）

本專案的 UI 與邏輯都僅依賴 `PlayerRepository` 的介面，所以後端切換可以做到「**換掉 repository 實作** 即可」：

1. 把目前的 `PlayerRepository` 重新命名為 `LocalPlayerRepository implements PlayerRepository`，並抽出 `abstract class PlayerRepository`。
2. 新增 `FirebasePlayerRepository`，以 `cloud_firestore` 讀寫 `players` / `sessions` 兩個 collection。
3. 使用 `StreamBuilder` 或 Riverpod/Provider 注入，UI 不需要改動。
4. 玩家資料建議結構：
   - `users/{uid}/players/{playerId}`：私人名單（離線先快取，Firestore 作為主源）。
   - `sessions/{sessionId}`：活動狀態（roster、currentRound、preferredCourts），支援多裝置共用。
5. `MatchMaker` 本身是純邏輯、不涉 IO，可直接保留。
6. 若要做多人共同操作（教練 / 幹部一起排場），可以用 Firestore transaction 來避免同時 `commitRound` 的競態。

---

## 實作備註

- 所有 Hive 操作都在 `PlayerRepository` 內；UI 不直接引用 `hive`。
- `MatchMaker` 的隨機性可注入（`MatchMaker(random: Random(seed))`），方便寫測試。
- UI 使用 Material 3（`useMaterial3: true`）與 `NavigationBar`，在手機上自然響應式。
