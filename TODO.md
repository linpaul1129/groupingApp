# TODO

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
