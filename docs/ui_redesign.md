# 羽球分組管理 App — UI/UX 重設計規格

> 版本：v1.0 · 2026-05-06  
> 目標：兼容 Flutter App（iOS/Android）與手機網頁（Flutter Web）  
> 設計原則：**大字、大按鈕、動作不超過兩步、強光汗手也能操作**

---

## 一、核心問題診斷

| 現況 | 問題 | 影響 |
|------|------|------|
| 場地卡分數用 `headlineSmall`（約 24px）| 球場距離看不清 | 計分體驗差 |
| 兩段式互換（tap A → tap B）| 無視覺引導 | 容易誤觸、誤換人 |
| 右滑刪除活動（`Dismissible`）| Web 滑鼠無法觸發 | 跨平台失效 |
| 底部 `NavigationBar` 固定 | 平板 / 桌面空間浪費 | Web 版體驗差 |
| 等待區用 `Wrap` Chip | 人多時多行換行 | 佔去大量滾動空間 |
| `AspectRatio(16/11)` 固定球場 + 兩場地左右並排 | 手機寬度不足 | 版面被擠壓 |

---

## 二、設計語言（Design Tokens）

```
主色：   indigo[700]   #3730A3   ← 羽球裝備感、高對比
強調色： amber[500]    #F59E0B   ← 計分高亮、MVP、等待優先
錯誤色： red[500]
成功色： green[600]

圓角：
  卡片   16px
  按鈕   12px
  Chip    8px
  對話框 24px

陰影：
  卡片        elevation 0 + 1px outline border
  CourtCard   elevation 1（微陰影）
  浮動按鈕    elevation 3

字型（計分專用）：
  分數數字    40~56px  w900   ← 球場中央主分數
  Live 小分   24px     w800   ← AppBar 次要顯示（進行中）
  一般標題    titleLarge 22px w700
  副標        titleMedium 16px w600
  說明文字    bodySmall 12px  w400
```

---

## 三、自適應導覽系統

### 斷點定義

```dart
class AppBreakpoints {
  static const double tablet = 600;
  static const double wide   = 900;

  static bool isPhone(BuildContext ctx) =>
      MediaQuery.of(ctx).size.width < tablet;
  static bool isTablet(BuildContext ctx) =>
      MediaQuery.of(ctx).size.width >= tablet &&
      MediaQuery.of(ctx).size.width < wide;
  static bool isWide(BuildContext ctx) =>
      MediaQuery.of(ctx).size.width >= wide;
}
```

### 導覽結構

| 寬度 | 元件 | 樣式 |
|------|------|------|
| < 600px（手機）| `NavigationBar` | 底部，現有結構 |
| 600–900px（平板）| `NavigationRail` | 左側 80px，顯示 label |
| > 900px（Web / 桌面）| `NavigationDrawer` | 左側固定 200px |

```
HomeScreen LayoutBuilder 結構：

< 600px：
  Scaffold
    body: IndexedStack
    bottomNavigationBar: NavigationBar

600~900px：
  Scaffold
    body: Row [
      NavigationRail,
      VerticalDivider,
      Expanded(IndexedStack),
    ]

> 900px：
  Scaffold
    body: Row [
      NavigationDrawer (width 200px),
      Expanded(IndexedStack),
    ]
```

---

## 四、各畫面重設計規格

### 4.1 玩家管理頁（`player_management_screen.dart`）

**改動重點：**
- 刪除純 `ListTile`，改為帶 outline border 的 Card
- 刪除按鈕改為三點選單 `⋮`（PopupMenuButton），支援 Web
- 寬螢幕（≥ 600px）改 2-column `GridView`

**版面：**
```
AppBar: 「玩家」  [篩選 Regular/Guest] [+ 新增]

手機 ListView：
  ┌──────────────────────────────────────┐
  │  ○頭像   姓名  [Regular]            ⋮│
  │  radius24  N 場 · 勝 XX%             │
  └──────────────────────────────────────┘

⋮ 選單：[編輯] [刪除（red）]

平板 GridView 2-col：
  每格：大頭像 + 姓名 + 勝率 + [Regular/Guest badge]
  hover（Web）：顯示 [編輯] [刪除] icon
```

**互動：**
- 長按（Mobile）→ ContextMenu
- 右鍵（Web）→ ContextMenu
- 空狀態：`FilledButton.icon(Icons.person_add, '新增第一位玩家')`

---

### 4.2 活動設定頁（`session_setup_screen.dart`）

**改動重點：**
- 活動卡 trailing 加 `PopupMenuButton` 三點選單（取代純右滑刪除）
- 右滑刪除保留（Mobile 便利性），但 Web 改為選單
- 活動卡顯示玩家頭像橫排預覽

**活動卡版面：**
```
┌────────────────────────────────────────┐
│  ●  活動名稱              [使用中]   ⋮ │
│     ○ ○ ○ ○ ○ +3  ← 玩家頭像橫排      │
│     [N 人] [N 場地] [勝率平衡?]        │
└────────────────────────────────────────┘

啟用中：primaryContainer 背景 + primary border 2px
未啟用：surface 背景 + outlineVariant border 1px
```

**⋮ 選單項目：**
```
[啟用]
[編輯]
─────
[刪除]  ← red color
```

---

### 4.3 活動編輯頁（`activity_edit_screen.dart`）

**改動重點：**
- 玩家 Grid 改為自適應 `maxCrossAxisExtent`
- 玩家數 > 8 時顯示搜尋列

**版面規格：**
```
手機  (< 600px)：maxCrossAxisExtent 100（現有）
平板  (≥ 600px)：maxCrossAxisExtent 130
Web   (≥ 900px)：改 ListView + CheckboxListTile（支援鍵盤 Tab/Enter）

搜尋列（玩家 > 8 人時顯示）：
  TextField hintText='搜尋玩家'  suffixIcon=Icons.search
  onChanged → 即時 filter players list
```

---

### 4.4 比賽頁（`match_screen.dart`）— 最優先

#### 4.4.1 兩場地佈局自適應

```
手機 (< 600px)：   垂直堆疊，每張 CourtCard 全寬   ← 修改現況
平板 (≥ 600px)：   左右並排（現有行為）
Web  (≥ 900px)：   兩場地 + 等待區三欄並排
```

#### 4.4.2 CourtCard 分數重設計（核心）

**分數移到球場中央，字體放大至 56px**

```
CourtCard 新版佈局：

┌─────────────────────────────────────────┐
│  Court 1                      [進行中]  │
│                                          │
│  ┌─────────────────────────────────┐   │
│  │  [隊A半場 - 淺靛藍底色 10% alpha]│   │
│  │   ○小林          ○阿明          │   │
│  │                                 │   │
│  │         ┌─────────┐            │   │
│  │         │   21    │ ← 56px w900│   │  ← 疊在 CustomPaint 上
│  ├─────────┤         ├────────────┤   │  ← 球網（現有 painter）
│  │         │   18    │            │   │
│  │         └─────────┘            │   │
│  │   ○阿華          ○小美          │   │
│  │  [隊B半場 - 淺橙底色 10% alpha] │   │
│  └─────────────────────────────────┘   │
│                                          │
│  [隊A −1]  [隊B −1]         [結束本場]  │
└─────────────────────────────────────────┘
```

**分數互動：**
- 點擊上半場 → 隊A +1 → `AnimatedScale`（0.8→1.0，150ms）
- 領先方分數：`primary` 色；落後方：灰色
- Pending 狀態：點擊玩家 → `primary` border highlight

**技術實作：**
```dart
// 分數 Stack 疊在 CustomPaint 上
Stack(children: [
  CustomPaint(painter: BadmintonCourtPainter()),
  Positioned.fill(child: _buildScoreOverlay()),   // 新增
  _buildPlayersLayer(teamA, teamB),
])

// 分數動畫
AnimatedScale(
  scale: _justScored ? 1.15 : 1.0,
  duration: const Duration(milliseconds: 150),
  child: Text('$score', style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900)),
)
```

#### 4.4.3 等待區重設計

**現況問題：** Wrap 多行，佔太多空間。

**重設計：單行橫向捲動**
```
等待區（N 人）                        [收合 ▲]
───────────────────────────────────────────────
← 橫向 SingleChildScrollView →
  [頭像+名字] [頭像+名字] [頭像+名字] ...

等待輪數 ≥ 2 的玩家：amber border 2px（提示優先上場）
正在被選擇中：primary border 2px + pulse 動畫
```

#### 4.4.4 互換操作引導改善

**問題：** 現有選中後底部 hint bar 文字小、不明顯。

**重設計：**
```
選中玩家後：
  1. 被選玩家：primary border + 縮放 1.05 動畫
  2. 其他可互換玩家（場上 pending + 等待區）：
     顯示輕微 amber tint 背景（「我可被點」的視覺暗示）
  3. 頂部浮動提示（OverlayEntry 或 MaterialBanner）：
     「已選 ○○，點選另一位互換　[取消]」
  4. 互換完成 → SnackBar：「已互換 ○○ ↔ ○○ ✓」
```

---

## 五、Web 專用補強

| 問題 | 解法 | 元件 |
|------|------|------|
| 右滑刪除失效 | `PopupMenuButton` 三點選單 | 活動卡、玩家列表 |
| 無 hover 狀態 | `MouseRegion` + elevation/背景色變化 | 所有卡片 |
| 無鍵盤導覽 | `FocusNode` + Enter 觸發 | 名單 Grid、按鈕 |
| 觸控目標偏小 | 所有互動元件 minHeight 48px | 全域 ButtonStyle |
| 無選取游標 | `SystemMouseCursors.click` | 可點擊區域 |
| 無右鍵選單 | `GestureDetector.onSecondaryTap` → ContextMenu | 列表項目 |

---

## 六、實作 Agent 分工

### Agent 0：前置準備（必須最先完成）
- **工作**：新增 `lib/utils/breakpoints.dart`（`AppBreakpoints`）
- **驗證**：可在所有畫面 import 且 `flutter analyze` 無錯誤
- **依賴**：無（其他 Agent 都需要這個）

---

### Agent 1：自適應導覽（`home_screen.dart`）
- **工作**：
  - `HomeScreen` 包一層 `LayoutBuilder`
  - `< 600px` → 現有 `NavigationBar`
  - `600~900px` → `NavigationRail`（含 label）
  - `> 900px` → `NavigationDrawer`（固定展開）
- **檔案**：`lib/screens/home_screen.dart`
- **驗證**：
  - 手機寬度：底部導覽正常顯示
  - 平板寬度：左側 Rail 顯示
  - 桌面寬度：左側 Drawer 顯示
- **依賴**：Agent 0

---

### Agent 2：比賽頁分數與球場佈局（`match_screen.dart` + `court_card.dart`）
- **工作**：
  1. `CourtCard`：分數移到球場中央 Stack，字體 56px w900
  2. `CourtCard`：分數動畫（`AnimatedScale` 0.8→1.15→1.0）
  3. `CourtCard`：領先方分數 primary 色、落後方灰色
  4. 隊A半場淺靛藍底、隊B半場淺橙底（10% alpha overlay）
  5. `MatchScreen._buildMatchPanel`：手機（< 600px）改垂直堆疊
- **檔案**：
  - `lib/widgets/court_card.dart`
  - `lib/screens/match_screen.dart`
- **驗證**：
  - 分數顯示在球場中間
  - 點擊半場有 Scale 動畫
  - 手機單場地、平板兩場地並排
- **依賴**：Agent 0

---

### Agent 3：等待區橫向捲動 + 互換提示改善（`match_screen.dart`）
- **工作**：
  1. `_buildWaitingArea` 改為橫向 `SingleChildScrollView`
  2. 等待輪數 ≥ 2 的玩家加 amber border
  3. 選中玩家後顯示頂部 `MaterialBanner`（取代底部 hint bar 文字）
  4. 其他可互換玩家加 amber tint 背景提示
  5. 互換完成後顯示 `ScaffoldMessenger` SnackBar
- **檔案**：`lib/screens/match_screen.dart`
- **驗證**：
  - 等待區單行橫向捲動
  - 等待久的玩家有 amber 框
  - 選中後頂部有 banner 提示
- **依賴**：Agent 0

---

### Agent 4：玩家管理頁重設計（`player_management_screen.dart`）
- **工作**：
  1. `ListTile` 改為帶 outline border 的 Card
  2. 刪除 icon 改為 `PopupMenuButton`（含編輯 / 刪除）
  3. 寬螢幕（≥ 600px）改 2-column `GridView`
  4. Web hover：`MouseRegion` + 淺色背景
- **檔案**：`lib/screens/player_management_screen.dart`
- **驗證**：
  - 手機顯示 Card 列表，⋮ 選單正常
  - 寬螢幕顯示 Grid
  - 刪除確認 dialog 正常
- **依賴**：Agent 0

---

### Agent 5：活動設定頁重設計（`session_setup_screen.dart`）
- **工作**：
  1. 活動卡加 `PopupMenuButton` 三點選單
  2. 活動卡新增玩家頭像橫排預覽（最多 5 顆 + `+N`）
  3. 右滑刪除保留（Mobile），三點選單同步支援刪除
- **檔案**：`lib/screens/session_setup_screen.dart`
- **驗證**：
  - 活動卡顯示玩家頭像
  - 三點選單可啟用 / 編輯 / 刪除
  - 右滑刪除仍正常
- **依賴**：Agent 0

---

### Agent 6：活動編輯頁搜尋與自適應 Grid（`activity_edit_screen.dart`）
- **工作**：
  1. 玩家 Grid 自適應（手機 100px / 平板 130px / 桌面 CheckboxListTile）
  2. 玩家 > 8 人時顯示搜尋列，即時 filter
  3. Web 模式下玩家列表 `FocusNode` + Enter 觸發選取
- **檔案**：`lib/screens/activity_edit_screen.dart`
- **驗證**：
  - 手機格子大小不變
  - 寬螢幕格子變大
  - 搜尋有效（大小寫 insensitive）
- **依賴**：Agent 0

---

## 七、實作優先順序

```
Phase 1 — 核心體驗（P0）：
  Agent 0 → Agent 2 → Agent 3

Phase 2 — 跨平台必要（P1）：
  Agent 1 → Agent 4 → Agent 5

Phase 3 — 體驗提升（P2）：
  Agent 6
```

### 相依圖

```
Agent 0（breakpoints）
    ├── Agent 1（導覽）
    ├── Agent 2（分數 + 球場）
    ├── Agent 3（等待區 + 互換）
    ├── Agent 4（玩家管理）
    ├── Agent 5（活動設定）
    └── Agent 6（活動編輯）
```

Agent 1~6 在 Agent 0 完成後**可平行執行**（各自操作不同檔案）。  
Agent 3 與 Agent 2 都修改 `match_screen.dart`，建議**依序執行**以避免 merge conflict。

建議啟動順序： Agent 0 → Agent 2 + Agent 3（依序）→ Agent 1 + 4 + 5（平行） → Agent 6

---

## 八、驗收標準

- `flutter analyze` 零錯誤、零 warning
- `dart format .` 通過
- `flutter test` 全綠
- 手機寬度（360px）：底部導覽、垂直球場、單行等待區
- 平板寬度（768px）：側邊 Rail、兩場地並排
- Web 寬度（1280px）：側邊 Drawer、三欄比賽頁、⋮ 選單可操作
