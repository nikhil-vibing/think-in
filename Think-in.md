# Think-in

A distraction-free writing app for macOS built around stream-of-consciousness writing.

## What it is

Think-in gives you a minimal, timed writing environment to get thoughts out of your head and onto the page. No formatting toolbars, no file management, no friction — just you and a blank page with a timer running.

The app is built for founders doing focused freewriting: capturing customer signal, stress-testing assumptions, and thinking through problems in short, timed sprints.

## Features

- **Timed sessions** — 15-minute default timer creates focused writing sprints; scroll to adjust in 5-minute increments
- **Auto-everything** — new entry created each day automatically, saves on every keystroke, no manual save
- **Local-first** — all entries stored as plain markdown in `~/Documents/Freewrite/`, yours forever
- **MCP integration** — connects to Claude Code via a local MCP server so your AI can read, search, and reflect on your writing
- **Minimal UI** — bottom nav fades away when the timer starts, leaving only text

## Getting Started

1. Open `freewrite.xcodeproj` in Xcode
2. Build and run (`⌘R`)
3. Start writing

## MCP Integration (Claude Code)

Think-in ships a local MCP server (`ThinkINMCPServer`) that lets Claude Code interact with your entries.

**To connect:**
1. Click the `cpu` icon in the bottom nav
2. Click **Connect Claude Code**

The server exposes tools to list, search, read, and append to entries, plus five thinking-mode prompts for structured reflection. Write access is gated by a toggle in the same popover.

**To build the server manually:**
```bash
cd ThinkINMCPServer && swift build -c release
```

## Data

All entries are plain UTF-8 markdown files:

```
~/Documents/Freewrite/
└── [UUID]-[YYYY-MM-DD-HH-mm-ss].md
```

No database, no proprietary format. Open them in any editor.

## Requirements

- macOS 14.0+
- Xcode 15+
