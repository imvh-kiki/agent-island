# Agent Island

A macOS Dynamic Island for AI coding agents. When Claude Code is running in your terminal, Agent Island shows its status as a floating pill at the top of your screen — so you don't have to keep staring at the terminal.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- **Floating status pill** — real-time status of Claude Code at the top of your screen
- **Permission handling** — approve or deny tool requests directly from the island
- **Question responses** — answer Claude Code's questions without switching to the terminal
- **Plan review** — review and approve/reject execution plans
- **Multi-session support** — manage multiple Claude Code sessions from a single island
- **8-bit sound effects** — retro synth notification sounds (can be toggled off)
- **Auto show/hide** — appears when something needs attention, hides when idle

## Prerequisites

- macOS 13 (Ventura) or later
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and working in your terminal

## Installation

### Option 1: Download (Recommended)

Download the latest `.app` from [Releases](https://github.com/imvh-kiki/agent-island/releases).

> The app is not notarized yet. On first launch, go to System Settings → Privacy & Security and click "Open Anyway".

### Option 2: Build from Source

Make sure you have Xcode Command Line Tools installed (includes the Swift compiler):

```bash
xcode-select --install
```

Then:

```bash
git clone https://github.com/imvh-kiki/agent-island.git
cd agent-island
swift build -c release
```

Bundle it as a .app:

```bash
./scripts/bundle.sh
```

The `Agent Island.app` will be in the `build/` folder. Drag it to your Applications folder and launch it like any other app.

## Usage

1. Launch Agent Island (it appears in the menu bar)
2. Open a terminal and run `claude` to start Claude Code
3. Agent Island will automatically detect the session and show the island

### Controls

| Action | Description |
|--------|-------------|
| Click the island | Expand/collapse details |
| Allow / Deny | Respond to permission requests |
| Answer questions | Type your reply directly in the island |
| Jump to Terminal | Switch to the terminal window running the session |
| Menu bar → Show Island | Manually show the island |
| Menu bar → Quit | Quit Agent Island |

### Sound Effects

Enabled by default, toggleable from the menu bar. Includes:
- Session start
- Permission request
- Question prompt
- Success / error

## FAQ

**Q: I launched it but don't see the island?**
A: The island only appears when it detects an active Claude Code session. Make sure Claude Code is running.

**Q: macOS won't let me open the app?**
A: Go to System Settings → Privacy & Security, find Agent Island, and click "Open Anyway".

**Q: The island stays visible and won't go away?**
A: Check if Claude Code is waiting for your response. If it's genuinely stuck, restart from the menu bar.

**Q: Does it use a lot of system resources?**
A: No. It periodically checks for Claude Code sessions and listens for events — virtually zero CPU and memory when idle.

**Q: Does it cost extra AI credits?**
A: No. Agent Island doesn't call any AI APIs. It only displays Claude Code's status. Costs depend entirely on your Claude Code usage.

**Q: Does it send my data anywhere?**
A: No. All communication stays on your local machine. There are no outbound network connections.

## Report Issues

Found a bug? Open an [Issue](https://github.com/imvh-kiki/agent-island/issues) with:
- Your macOS version
- Steps to reproduce
- Screenshots if possible
