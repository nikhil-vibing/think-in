# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Freewrite - Technical Documentation for AI Agents

> **⚠️ IMPORTANT FOR AI AGENTS**: This file (`AGENTS.md`) and `CLAUDE.md` are clones and must be kept in sync.
>
> Update both files when changes are **substantial** and meaningfully affect future agent understanding (for example: architecture, data flow, storage/permissions, threading behavior, user-facing workflows, or major bug fixes).
>
> For minor tweaks (small UI polish, copy edits, tiny refactors), updates are optional. Do **not** churn these docs on every small code change.
>
> If one file is updated, mirror the same change in the other file immediately.

## Product Vision & User Experience

### What is Freewrite?

Freewrite is a **distraction-free writing environment** for macOS designed around the concept of stream-of-consciousness writing. The core philosophy is to remove barriers between thought and writing by creating a minimalist, opinionated interface that prioritizes the act of writing over formatting, organization, or editing.

### User Experience Philosophy

**Core Principles:**
1. **Timed Sessions**: Built-in timer (default 15 minutes) creates focused writing sprints
2. **Auto-Everything**: Auto-save, auto-new-entry, auto-timestamp - the app manages logistics so users can focus on writing
3. **Local-First**: All data stays on the user's machine in plain markdown files they can access directly
4. **Minimal UI**: Most UI elements hide during timed sessions, leaving only the text

### Use Cases

**Primary Use Case - Stream of Consciousness Writing:**
- Users open the app and start writing immediately (no "New Document" dialog)
- The app creates a new entry automatically at the start of each day
- Writing is saved continuously with no manual save action
- Timer creates urgency and prevents over-editing
- Minimal controls and timed sessions encourage forward momentum without blocking standard editing keys

**Founder Use Case - Startup Signal Freewriting:**
- Founder-focused freewriting is now the default product posture; there is no separate writing mode toggle
- Empty entries show founder prompts focused on customer signal, problems, shaky assumptions, wedges, and fast experiments
- Entries remain blank markdown files; prompts are placeholders only and are never inserted into saved text

**Secondary Use Case - AI-Assisted Reflection via MCP:**
- The app registers a local MCP server (`ThinkINMCPServer`) with Claude Code via the `cpu` icon → MCPConnectionView popover
- Claude Code (or any MCP-compatible client) can then list, search, read, append to, and create entries directly in `~/Documents/Freewrite/`
- The MCP server also exposes five thinking-mode prompts (journal_reflection, idea_critique, research_frame, peace_perspective, decision_clarity) so users can invoke structured reflection workflows from their AI client
- Write access is gated by a toggle in the app's MCP settings popover

**Hidden Power Feature - Long-Form Writing:**
- Despite minimalist interface, supports full markdown
- Entries can be exported as PDFs
- Font and size customization for comfort during long sessions
- Dark mode for night writing

## Overview

Freewrite is a native macOS writing application built with SwiftUI that allows users to write text entries. All data is stored locally in `~/Documents/Freewrite/`. The app pairs with a local MCP server (`ThinkINMCPServer`) that exposes entries to Claude Code and other MCP-compatible AI clients.

## Architecture

### Technology Stack
- **Framework**: SwiftUI (macOS)
- **Minimum macOS Version**: 14.0
- **Language**: Swift 5.0
- **Build System**: Xcode

### Project Structure

```
freewrite/
├── freewrite.xcodeproj/          # Xcode project file
├── freewrite/
│   ├── freewriteApp.swift        # App entry point; ContentView is self-contained (no EnvironmentObject injection)
│   ├── GlassStyle.swift          # Shared Liquid Glass/fallback styling helpers
│   ├── ContentView.swift         # Main view (~430 lines, text-only)
│   ├── MCPSettingsStore.swift    # ObservableObject; writeEnabled flag; reads/writes mcp-config.json
│   ├── MCPConnectionView.swift   # Settings popover (cpu icon): write toggle, connection status, Connect/Disconnect
│   ├── freewrite.entitlements    # App permissions (emptied — no sandbox, no camera/mic/speech)
│   └── default.md
├── ThinkINMCPServer/             # Standalone Swift Package (Swift 6) — MCP server
│   ├── Package.swift             # swift-tools-version: 6.0; depends on swift-sdk MCP
│   └── Sources/ThinkINMCPServer/main.swift  # StdioTransport server; 6 tools + 5 prompts
├── CLAUDE.md                     # This file
└── AGENTS.md                     # Duplicate of this file
```

## Data Model

### Entry Type

All entries are text-only. The `EntryType` enum and `videoFilename` field have been removed.

```swift
struct HumanEntry: Identifiable, Equatable {
    let id: UUID
    let date: String              // Display format: "MMM d" (e.g., "Feb 20")
    let filename: String          // Format: [UUID]-[YYYY-MM-DD-HH-mm-ss].md
    var previewText: String       // First 30 chars of content
}
```

### File Storage

**Location**: `~/Documents/Freewrite/`

**Text Entries**:
- Format: Markdown (.md)
- Naming: `[UUID]-[YYYY-MM-DD-HH-mm-ss].md`
- Content: Plain UTF-8 text
- Example: `[6910BBDE-75FC-415C-ABB9-C76644B037B2]-[2026-02-20-08-01-04].md`

**Legacy Video Metadata** (on disk, hidden from UI):
- `.md` files whose content is exactly `"Video Entry"` are skipped by `loadExistingEntries()` and never shown in the sidebar. The actual `.mov` files and video directories remain on disk untouched.

**MCP Config**:
- `~/Library/Application Support/ThinkIN/mcp-config.json` — written by `MCPSettingsStore` when the write-access toggle changes; read by the MCP server at call time.

## MCP Architecture (ThinkIN)

### MCPSettingsStore

`MCPSettingsStore` (`ObservableObject`) is the sole settings object in the app:

```swift
class MCPSettingsStore: ObservableObject {
    @Published var writeEnabled: Bool
    // Reads/writes ~/Library/Application Support/ThinkIN/mcp-config.json
    // {"writeEnabled": true/false}
}
```

There is no `AIProviderStore`, no `AIProvider` protocol, no Keychain usage, and no in-app AI streaming. `freewriteApp.swift` does not inject any `@EnvironmentObject`; `ContentView` is self-contained.

### MCPConnectionView

`MCPConnectionView` is presented from the `cpu` icon in the nav bar as a popover. It provides:

- **Write-access toggle**: enables/disables write tools in the MCP server (persisted via `MCPSettingsStore`)
- **MCP connection status indicator**: shows whether `think-in` is registered with the Claude CLI
- **Connect Claude Code button**: runs `claude mcp add --scope user think-in -- <binary_path>`
  - Finds `claude` CLI at `~/.local/bin/claude`, `/usr/local/bin/claude`, `/opt/homebrew/bin/claude`, or via PATH
  - Finds server binary at `Bundle.main.url(forResource: "ThinkINMCPServer", withExtension: nil)` (production) or a development path search
  - Verifies registration via `claude mcp list | contains("think-in")`
- **Disconnect button**: runs `claude mcp remove think-in`
- **Manual fallback instructions** for users who prefer to configure their MCP client by hand

### MCP Server (ThinkINMCPServer)

`ThinkINMCPServer/` is a standalone Swift 6 Package (separate from the Xcode project). Server name: `"ThinkIN"`.

```bash
# Build once
cd ThinkINMCPServer && swift build -c release
```

**Six tools**: `list_entries`, `search_entries`, `read_entry`, `append_to_entry`, `create_entry` (same semantics as before), plus any newly added tool.

**Five thinking-mode prompts** (via `prompts` capability):
- `journal_reflection` — reflective journaling on an entry
- `idea_critique` — stress-test an idea
- `research_frame` — structure research questions around an entry
- `peace_perspective` — reframe stressful entries with equanimity
- `decision_clarity` — clarify a decision buried in an entry

Each prompt takes a single `entry_content` argument.

Write tools (`append_to_entry`, `create_entry`) are **gated** — they return an error unless the user has enabled write access in the app's MCP settings popover. The server reads `~/Library/Application Support/ThinkIN/mcp-config.json` at call time.

`loadEntries()` in the MCP server skips `.md` files whose content is exactly `"Video Entry"` (legacy video metadata).

All paths are scoped to `~/Documents/Freewrite/`.

## Key Components

### ContentView.swift

The main view containing all UI and business logic (~430 lines). `ContentView` is self-contained — no `@EnvironmentObject` dependencies.

#### State Variables (Selection)

```swift
@State private var entries: [HumanEntry] = []           // All loaded entries
@State private var text: String = ""                    // Current text editor content
@State private var selectedEntryId: UUID? = nil         // Currently selected entry
@State private var showingSidebar = false               // History sidebar visibility
@State private var colorScheme: ColorScheme = .light    // Light/dark theme
@State private var fontSize: CGFloat = 18               // Text size (16-26px)
@State private var selectedFont: String = ...           // Resolved premium writing font preset
@State private var timerIsRunning = false               // Timer state
@State private var timeRemaining: Int = 900             // Timer (seconds)
@State private var showingMCPSettings = false           // MCPConnectionView popover visibility
```

#### Core Functions

**Entry Management**:
- `loadExistingEntries()` - Loads `.md` files from documents directory; skips files whose content is exactly `"Video Entry"`
- `createNewEntry()` - Creates new text entry
- `saveEntry(entry:)` - Saves text to .md file
- `loadEntry(entry:)` - Loads text content for display
- `deleteEntry(entry:)` - Deletes entry file

**Important**: When modifying the `entries` array from async contexts, wrap in `DispatchQueue.main.async` to prevent collection mutation crashes.

### MCPSettingsStore.swift

`ObservableObject` that owns the write-access gate. Reads and writes `~/Library/Application Support/ThinkIN/mcp-config.json` on every toggle change. The MCP server reads this file at call time to decide whether write tools are permitted.

### MCPConnectionView.swift

SwiftUI popover presented from the `cpu` nav icon. Handles the full Connect/Disconnect lifecycle for registering the bundled `ThinkINMCPServer` binary with the Claude CLI (see MCP Architecture section for details).

### GlassStyle.swift

Centralizes the app's Apple Liquid Glass design-system helpers.

- `freewriteGlassPanel(cornerRadius:interactive:)` applies Liquid Glass on macOS 26+ and falls back to `ultraThinMaterial` on older macOS versions
- `freewriteGlassBand(interactive:)` applies full-height/sidebar glass bands with the same fallback behavior
- `FreewriteGlassContainer(spacing:)` groups nearby glass elements so related controls resolve as one Liquid Glass system
- Interactive controls such as bottom-nav clusters should pass `interactive: true`; passive panels such as popovers and sidebars should usually remain non-interactive
- Avoid adding opaque nested backgrounds inside glass surfaces; use very low-opacity fills for selected/hover states so the glass material remains visible

## UI Layout

### Main Interface

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│                    Text Editor Area                     │
│                                                         │
├─────────────────────────────────────────────────────────┤
│  Bottom Nav Bar:                                        │
│  [16px] • [Toggle Font]                                │
│  ... [15:00] • [cpu] • [Fullscreen] • [New] • [Theme] • [History]  │
└─────────────────────────────────────────────────────────┘
```

### Sidebar (History)

```
┌────────────────────────────┐
│ History              📁  × │
│ 12 entries • Local markdown│
├────────────────────────────┤
│ ▌ [doc]  Entry preview     │ ← click row to open
│          Jun 8   Text      │ ← date metadata
│   [doc]  Text preview      │ ← hover row for export/delete actions
│          Jun 5   Text      │
└────────────────────────────┘
```

## Navigation Bar Items

### Left Side (Font Controls)
- **Font Size**: Cycles through [16, 18, 20, 22, 24, 26]px
- **Toggle Font**: Cycles through curated writing presets (New York, Iowan, Avenir, Lato, Mono) without showing every font name as separate UI
- Hover changes cursor to pointing hand

### Liquid Glass Treatment
- Custom grouped surfaces use a local `freewriteGlassPanel(cornerRadius:interactive:)` wrapper
- On macOS 26+, the wrapper applies SwiftUI Liquid Glass via `glassEffect(_:in:)`
- On older macOS versions, the same wrapper falls back to `.ultraThinMaterial`
- Apply glass to grouped surfaces, not every label: bottom nav groups, popovers, MCPConnectionView shell, and sidebar band
- The MCPConnectionView popover uses one outer `freewriteGlassPanel`; internal regions use translucent fills so nested dark glass panels do not bury the effect
- The history sidebar uses one background `freewriteGlassBand()` so it can sit flush against the window edge without clipped rounded corners; selected/hovered rows use translucent fills instead of opaque blocks. Rows are tappable containers rather than nested buttons, while export/delete remain separate hover actions.
- Avoid applying separate glass effects to every history row or every small text/button because Apple warns that too many Liquid Glass effects can hurt rendering performance

### Right Side (Utilities)
- **Timer**: Shows time remaining, click to start/stop, double-click to reset
- **MCP Settings (cpu icon)**: Opens `MCPConnectionView` popover — write-access toggle, connection status, Connect/Disconnect Claude Code
- **Fullscreen**: Toggle fullscreen mode
- **New Entry**: Creates new text entry
- **Theme Toggle**: 🌙/☀️ for dark/light mode
- **History**: 🕐 Shows/hides sidebar

## Entry Loading Logic

On app launch (`onAppear`):

1. `loadExistingEntries()` called
2. Reads all `.md` files from `~/Documents/Freewrite/`
3. Skips any `.md` file whose trimmed content is exactly `"Video Entry"` (legacy video metadata)
4. For each remaining `.md` file:
   - Extracts UUID and date from filename via regex
   - Reads content for sidebar preview
   - Creates `HumanEntry`
5. Sorts entries by date (newest first)
6. Applies launch selection rules in order:
   - If no entries: create welcome entry
   - Else if no empty entry exists for today (and app is not in the single-welcome-entry state): create a new empty entry
   - Else select the most recent empty entry from today (or the welcome entry if it's the only entry)

## Auto-Save Behavior

Text is auto-saved on every change:

```swift
.onChange(of: text) { _ in
    if let currentId = selectedEntryId,
       let currentEntry = entries.first(where: { $0.id == currentId }) {
        saveEntry(entry: currentEntry)
    }
}
```

## Permissions

`freewrite.entitlements` has been emptied. The app no longer uses the app sandbox, and all camera, microphone, and speech recognition entitlements have been removed along with their corresponding `INFOPLIST_KEY_NS*UsageDescription` build settings. No privacy usage descriptions are required.

## Technical Nuances & Implementation Details

### Threading Model

The app uses a **hybrid threading approach**:

1. **Main Thread**: All UI updates and `@State` mutations
2. **Global Queue**: File I/O operations (reading/writing markdown files)

**Critical Threading Issue**:
SwiftUI's `ForEach` creates an enumerator over the `entries` array. If you modify this array (insert, remove, replace) while the enumerator is active, you get `NSGenericException: Collection was mutated while being enumerated`.

**Solution Pattern**:
```swift
// When in async context (DispatchQueue callback):
DispatchQueue.main.async {
    self.entries.insert(newEntry, at: 0)  // Safe
}

// When in loadExistingEntries:
let loadedEntries = mdFiles.compactMap { ... }  // Work on local copy
entries = loadedEntries  // Assign once to @State
// Now safe to check entries.contains, entries.first, etc.
```

### File System Architecture

**Why UUID + Timestamp Naming?**

The filename format `[UUID]-[YYYY-MM-DD-HH-mm-ss].md` serves multiple purposes:

1. **UUID**: Ensures global uniqueness even if multiple devices sync to same folder
2. **Timestamp**: Human-readable sorting in Finder without opening files
3. **Brackets**: Makes regex extraction reliable: `\\[(.*?)\\]` and `\\[(\\d{4}-\\d{2}-\\d{2}-\\d{2}-\\d{2}-\\d{2})\\]`

**File Loading Algorithm**:

```swift
// 1. Get all files
let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, ...)
let mdFiles = fileURLs.filter { $0.pathExtension == "md" }

// 2. Parse each .md file
let entriesWithDates = mdFiles.compactMap { fileURL -> (entry, date, content)? in
    // Read content — skip legacy video metadata
    let content = try String(contentsOf: fileURL, encoding: .utf8)
    if content.trimmingCharacters(in: .whitespacesAndNewlines) == "Video Entry" { return nil }

    // Extract UUID from filename using regex
    let uuidMatch = filename.range(of: "\\[(.*?)\\]", options: .regularExpression)
    let uuid = UUID(uuidString: String(filename[uuidMatch].dropFirst().dropLast()))

    // Extract timestamp
    let dateMatch = filename.range(of: "\\[(\\d{4}-\\d{2}-\\d{2}-\\d{2}-\\d{2}-\\d{2})\\]", ...)
    let dateString = String(filename[dateMatch].dropFirst().dropLast())

    // Parse date for sorting
    dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
    let fileDate = dateFormatter.date(from: dateString)

    // Build preview
    let preview = content.replacingOccurrences(of: "\n", with: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
    let truncated = preview.isEmpty ? "" : String(preview.prefix(30)) + "..."

    return (entry: HumanEntry(...), date: fileDate, content: content)
}

// 3. Sort by actual date (not display date)
entries = entriesWithDates
    .sorted { $0.date > $1.date }  // Newest first
    .map { $0.entry }
```

**Why plain .md files?**

- User can open files in any text editor
- Easy to backup and sync
- Transparent file format for user ownership
- MCP server can read them directly without special parsing

### Auto-Save State Machine

The app implements **continuous auto-save** with debouncing:

```swift
.onChange(of: text) { _ in
    if let currentId = selectedEntryId,
       let currentEntry = entries.first(where: { $0.id == currentId }) {
        saveEntry(entry: currentEntry)
    }
}
```

**State Transitions**:
1. User types character → `text` state updates
2. `.onChange` fires immediately
3. `saveEntry()` writes to disk synchronously (fast on SSD)
4. No loading spinner needed (happens in <10ms)

**Edge Case**: What if user switches entries before save completes?

```swift
Button(action: {
    if selectedEntryId != entry.id {
        // Save current entry BEFORE switching
        if let currentId = selectedEntryId,
           let currentEntry = entries.first(where: { $0.id == currentId }) {
            saveEntry(entry: currentEntry)
        }

        selectedEntryId = entry.id
        loadEntry(entry: entry)
    }
})
```

This ensures no data loss on rapid entry switching.

### Timer Implementation Details

The timer is **not a countdown** - it's a visual focus tool:

```swift
@State private var timeRemaining: Int = 900  // 15 minutes default
@State private var timerIsRunning = false

let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

.onReceive(timer) { _ in
    if timerIsRunning && timeRemaining > 0 {
        timeRemaining -= 1
    } else if timeRemaining == 0 {
        timerIsRunning = false
        // Show bottom nav again when timer expires
        bottomNavOpacity = 1.0
    }
}
```

**UI Behavior During Timer**:
- When timer starts: Bottom nav fades out after 1 second
- While running: Nav only appears on hover
- When timer ends: Nav fades back in

This creates **immersion** - the UI disappears, leaving only text and timer.

**Timer Adjustment**:
- Scroll wheel over timer: Adjust in 5-minute increments
- Click: Start/pause
- Double-click: Reset to 15 minutes

```swift
NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
    if isHoveringTimer {
        let scrollBuffer = event.deltaY * 0.25
        if abs(scrollBuffer) >= 0.1 {
            let currentMinutes = timeRemaining / 60
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, ...)
            let direction = -scrollBuffer > 0 ? 5 : -5
            let newMinutes = currentMinutes + direction
            let roundedMinutes = (newMinutes / 5) * 5
            timeRemaining = roundedMinutes * 60
        }
    }
    return event
}
```

### Text Editor Header Behavior

Every entry starts with `\n\n` (two newlines):

```swift
TextEditor(text: Binding(
    get: { text },
    set: { newValue in
        if !newValue.hasPrefix("\n\n") {
            text = "\n\n" + newValue.trimmingCharacters(in: .newlines)
        } else {
            text = newValue
        }
    }
))
```

**Why?** Creates visual breathing room at top of page. All entries look like they start mid-page, not cramped at the top edge.

### Entry Creation Logic

**Complex Decision Tree**:

```swift
if entries.isEmpty {
    // First time user → create welcome entry
    createNewEntry()
} else if !hasEmptyEntryToday && !hasOnlyWelcomeEntry {
    // No empty entry for today → create new entry
    createNewEntry()
} else {
    // Select most recent empty entry from today
    if let todayEntry = entries.first(where: { isFromTodayAndEmpty }) {
        selectedEntryId = todayEntry.id
        loadEntry(entry: todayEntry)
    } else if hasOnlyWelcomeEntry {
        // Only have welcome entry → select it
        selectedEntryId = entries[0].id
        loadEntry(entry: entries[0])
    }
}
```

**Date Comparison Complexity**:

Display dates are "MMM d" (e.g., "Feb 20") without year. To check "is this from today?":

```swift
let dateFormatter = DateFormatter()
dateFormatter.dateFormat = "MMM d"
if let entryDate = dateFormatter.date(from: entry.date) {
    // entryDate is now "Feb 20" in year 1 (default year)
    // Need to add current year to compare
    var components = calendar.dateComponents([.year, .month, .day], from: entryDate)
    components.year = calendar.component(.year, from: Date())

    if let entryDateWithYear = calendar.date(from: components) {
        let entryDayStart = calendar.startOfDay(for: entryDateWithYear)
        let todayStart = calendar.startOfDay(for: Date())
        return calendar.isDate(entryDayStart, inSameDayAs: todayStart)
    }
}
```

This handles edge cases like February 29th on non-leap years.

### Font System

**Available Fonts**:
```swift
let standardFonts = ["Lato-Regular", "Arial", ".AppleSystemUIFont", "Times New Roman"]
let availableFonts = NSFontManager.shared.availableFontFamilies
```

**Random Font Button**:
- Picks random font from `availableFonts` (excludes standardFonts)
- Shows current random font in button: "Random [FontName]"
- Clicking again picks new random font

**Font Rendering**:
```swift
.font(.custom(selectedFont, size: fontSize))
```

`.custom()` falls back to system font if font not found, so app is resilient to missing fonts.

### Line Spacing Calculation

```swift
var lineHeight: CGFloat {
    let font = NSFont(name: selectedFont, size: fontSize) ?? .systemFont(ofSize: fontSize)
    let defaultLineHeight = getLineHeight(font: font)
    return (fontSize * 1.5) - defaultLineHeight
}

func getLineHeight(font: NSFont) -> CGFloat {
    let layoutManager = NSLayoutManager()
    return layoutManager.defaultLineHeight(for: font)
}
```

**Formula**: Target line height is 1.5× font size. Subtract natural line height to get spacing to add.

Example: 18px font → target 27px line height → natural 21px → add 6px spacing

This creates **generous vertical rhythm** for readability during long writing sessions.

### Chat Integration

**Prompts**:
```swift
let aiChatPrompt = "You are a writing coach. Help me understand what I wrote below and ask me questions about it:\n\n"
let claudePrompt = "You are a thoughtful writing partner. Read what I wrote and help me explore the ideas further:\n\n"
```

**URL Encoding**:
```swift
let fullText = aiChatPrompt + "\n\n" + trimmedText
if let encodedText = fullText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
   let url = URL(string: "https://chat.openai.com/?prompt=" + encodedText) {
    NSWorkspace.shared.open(url)
}
```

**Length Handling**:
- URLs >6000 chars fail in some browsers
- If too long, shows "Copy Prompt" button instead
- Copies to clipboard for manual paste

### PDF Export Implementation

```swift
func exportEntryAsPDF(entry: HumanEntry) {
    let savePanel = NSSavePanel()
    savePanel.title = extractTitleFromContent(content, date: entry.date)
    savePanel.allowedContentTypes = [.pdf]

    if savePanel.runModal() == .OK {
        let pdfData = createPDF(from: content)
        try pdfData.write(to: savePanel.url!)
    }
}
```

**Title Extraction**:
- Takes first 4 words of content
- Removes punctuation
- Falls back to "Entry [date]" if content empty

### Theme System

```swift
@State private var colorScheme: ColorScheme = .light

// Apply to entire window
.preferredColorScheme(colorScheme)

// Persisted to UserDefaults
UserDefaults.standard.set(colorScheme == .light ? "light" : "dark", forKey: "colorScheme")
```

**Colors**:
- Light mode text: `Color(red: 0.20, green: 0.20, blue: 0.20)` (dark gray, not black, easier on eyes)
- Dark mode text: `Color(red: 0.9, green: 0.9, blue: 0.9)` (off-white, not pure white)

## Common Pitfalls

### Collection Mutation Crashes

**Problem**: Modifying `entries` array while SwiftUI is enumerating it.

**Solution**:
```swift
// BAD
entries.insert(newEntry, at: 0)

// GOOD (from async context)
DispatchQueue.main.async {
    self.entries.insert(newEntry, at: 0)
}
```

### File Path Issues

Always use absolute paths:
```swift
let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("Freewrite")
let fileURL = documentsDirectory.appendingPathComponent(filename)
```

## Build Configuration

**Scheme**: freewrite
**Configuration**: Debug or Release
**Build Command**:
```bash
xcodebuild -project freewrite.xcodeproj -scheme freewrite -configuration Debug build
```

**Clean Build**:
```bash
xcodebuild -project freewrite.xcodeproj -scheme freewrite -configuration Debug clean build
```

(The README's intended workflow is simpler: open `freewrite.xcodeproj` in Xcode and click Build/Run.)

## Running Tests

Tests use Apple's **Swift Testing** framework (`import Testing`, `@Test`, `#expect(...)`) — not XCTest. Targets: `freewriteTests` (unit) and `freewriteUITests` (UI). Both are largely placeholder stubs today.

**Run all tests**:
```bash
xcodebuild test -project freewrite.xcodeproj -scheme freewrite -destination 'platform=macOS'
```

**Run a single test** (target/suite/function):
```bash
xcodebuild test -project freewrite.xcodeproj -scheme freewrite -destination 'platform=macOS' \
  -only-testing:freewriteTests/freewriteTests/example
```

## Feature Flags / Settings

Stored in `UserDefaults`:
- `colorScheme`: "light" or "dark"

Other settings are session-only (not persisted):
- Font size, font family, timer duration

## Future Development Notes

### Adding New Navigation Items

Add to bottom nav in ContentView.swift around line 500-950:

```swift
Text("•")
    .foregroundColor(.gray)

Button(action: {
    // Your action
}) {
    Image(systemName: "icon.name") // or Text("Label")
        .foregroundColor(isHovering ? textHoverColor : textColor)
}
.buttonStyle(.plain)
.onHover { hovering in
    isHovering = hovering
    isHoveringBottomNav = hovering
    if hovering {
        NSCursor.pointingHand.push()
    } else {
        NSCursor.pop()
    }
}
```

## Debugging

Enable console output in Xcode to see:
- File loading: "Processing: [filename]"
- Entry creation: "Successfully created entry"
- Errors: "Error saving entry: ..."

Check `~/Documents/Freewrite/` in Finder to verify files are being created.

For MCP issues: check `~/Library/Application Support/ThinkIN/mcp-config.json` for the write-enable flag, and run `claude mcp list` in terminal to verify `think-in` registration.

## Code Organization

ContentView.swift (~430 lines total):
- **Lines 1-80**: Imports, models, state variables
- **Lines 80-200**: Computed properties and helpers
- **Lines 200-350**: Main view body and UI
- **Lines 350-430**: Helper functions (save, load, delete, etc.)

## Key SwiftUI Patterns Used

- `@State` for local view state
- `@StateObject` for CameraManager
- `.overlay { if showingVideoRecording { ... } }` for immersive video recording
- `.onChange(of:)` for auto-save
- `.onAppear` for initialization
- `ForEach(entries)` with `Identifiable` for list rendering
- Conditional views: `if currentVideoURL != nil { VideoPlayerView } else { TextEditor }`

## Summary

Freewrite is a straightforward macOS writing app with video recording capabilities. All data is local, no backend required. The main complexity is in:

1. Proper file management and UUID-based naming
2. Thread-safe array mutations for entries
3. AVFoundation camera setup with proper configuration blocks
4. Conditional rendering between text and video content

When making changes, always:
- Test with actual video recording
- Check for collection mutation crashes
- Verify files are created in correct location
- Ensure privacy permissions are properly configured
