# Agent Island

macOS 的 Dynamic Island，專為 AI coding agent 設計。當 Claude Code 在終端機跑的時候，Agent Island 會以浮動小島的形式顯示狀態、攔截權限請求，讓你不用一直盯著終端機。

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)

## 功能

- **浮動狀態列** — 螢幕頂部的小島，即時顯示 Claude Code 的工作狀態
- **權限攔截** — 當 Claude Code 需要 approve/deny 時，直接在小島上操作
- **問題回覆** — Claude Code 提問時，在小島上直接回答
- **Plan 審核** — 查看並批准/拒絕 Claude Code 的執行計畫
- **多 Session 支援** — 同時跑多個 Claude Code，全部在一個小島管理
- **8-bit 音效** — 程式合成的復古音效提示（可關閉）
- **自動顯示/隱藏** — 有事件時自動彈出，閒置後自動收起

## 前置需求

- macOS 13 (Ventura) 或以上
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 已安裝並可在終端機使用

## 安裝

### 方法一：直接下載（推薦）

到 [Releases](https://github.com/imvh-kiki/agent-island/releases) 下載最新的 `.app`。

> 目前尚未公證（notarized），首次開啟需要到「系統設定 → 隱私與安全性」允許執行。

### 方法二：從原始碼 Build

```bash
git clone https://github.com/imvh-kiki/agent-island.git
cd agent-island
swift build -c release
```

Build 完成後執行：

```bash
.build/release/AgentIsland
```

或打包成 .app：

```bash
./scripts/bundle.sh
```

打包完的 `Agent Island.app` 會在 `build/` 資料夾。

## 使用方式

1. 啟動 Agent Island（會出現在 menu bar）
2. 開一個終端機，跑 `claude` 啟動 Claude Code
3. Agent Island 會自動偵測到 session 並顯示小島

### 操作

| 動作 | 說明 |
|------|------|
| 點擊小島 | 展開/收合詳細資訊 |
| Allow / Deny | 回應 Claude Code 的權限請求 |
| 回答問題 | 直接在小島輸入回覆 |
| 跳到終端機 | 點擊按鈕切換到對應的終端機視窗 |
| Menu bar → Show Island | 手動顯示小島 |
| Menu bar → Quit | 結束 Agent Island |

### 音效

預設開啟，可以在 menu bar 選單中切換。包含：
- Session 開始
- 權限請求
- 問題提示
- 操作成功/失敗

## 常見問題

**Q: 啟動後看不到小島？**
A: 小島只在偵測到 Claude Code session 時才會出現。先確認 Claude Code 正在執行。

**Q: 首次開啟被 macOS 擋住？**
A: 到「系統設定 → 隱私與安全性」，找到 Agent Island 點擊「仍要打開」。

**Q: 小島一直顯示不消失？**
A: 確認 Claude Code 沒有在等待你的回應。如果確實卡住，可以從 menu bar 重啟。

## 回報問題

遇到 Bug 歡迎開 [Issue](https://github.com/imvh-kiki/agent-island/issues)，請附上：
- macOS 版本
- 問題描述與重現步驟
- 如果方便，附上截圖
