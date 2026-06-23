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

Freewrite is a **distraction-free writing environment** for macOS designed around the concept of stream-of-consciousness writing and video journaling. The core philosophy is to remove barriers between thought and writing by creating a minimalist, opinionated interface that prioritizes the act of writing over formatting, organization, or editing.

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
- The Chat workflow uses founder-specific prompts that turn raw freewriting into a concise debrief: strongest customer/problem signal, risky assumption, ICP/wedge, 48-hour experiment, and memo/product-thesis sentence
- The `Explore` workflow locally turns the current entry or video transcript into founder artifacts: Explore, Assumptions, Customer Story, Opportunity Map, PMF Signal, and Memo. The popover is a two-pane artifact studio: source status + tool cards on the left, markdown preview + actions on the right. Users can save a local draft, copy the draft, copy an AI prompt, or send the selected artifact prompt to ChatGPT/Claude.

**Secondary Use Case - Video Journaling:**
- Quick video capture for visual thoughts/ideas
- Video entries stored alongside text entries in chronological history
- One-click recording with built-in timer
- Local storage ensures privacy for personal video journals

**Tertiary Use Case - AI-Assisted Reflection:**
- "Chat" button sends writing to ChatGPT or Claude
- Prompts designed to help users reflect on and understand their writing
- AI provides feedback, questions, or analysis of stream-of-consciousness text

**Hidden Power Feature - Long-Form Writing:**
- Despite minimalist interface, supports full markdown
- Entries can be exported as PDFs
- Font and size customization for comfort during long sessions
- Dark mode for night writing

## Overview

Freewrite is a native macOS writing application built with SwiftUI that allows users to write text entries and record video entries. All data is stored locally in `~/Documents/Freewrite/`.

## Architecture

### Technology Stack
- **Framework**: SwiftUI (macOS)
- **Minimum macOS Version**: 14.0
- **Language**: Swift 5.0
- **Build System**: Xcode
- **Media**: AVFoundation for camera/video recording

### Project Structure

```
freewrite/
├── freewrite.xcodeproj/          # Xcode project file
├── freewrite/
│   ├── freewriteApp.swift        # App entry point; injects AIProviderStore as @EnvironmentObject
│   ├── GlassStyle.swift          # Shared Liquid Glass/fallback styling helpers
│   ├── ContentView.swift         # Main view (~2450 lines)
│   ├── VideoRecordingView.swift  # Video recording interface
│   ├── VideoPlayerView.swift     # Video playback interface
│   ├── ExploreModels.swift       # ExploreController + ExploreAIAvailability
│   ├── LookBackView.swift        # Weekly digest (on-device @Generable or text-mode)
│   ├── ThinkWithItView.swift     # "Think" panel: Ask (RAG Q&A) + Clarity (structured reasoning)
│   ├── ProviderSettingsView.swift # AI provider + MCP settings UI
│   ├── AIProvider.swift          # AIProvider protocol + AIProviderType enum + errors
│   ├── AIProviderStore.swift     # ObservableObject; active provider, persisted config, MCP flag
│   ├── AppleOnDeviceProvider.swift # FoundationModels-based on-device streaming provider
│   ├── BYOKProvider.swift        # OpenAI-compatible SSE streaming (BYOK)
│   ├── OllamaProvider.swift      # Ollama NDJSON streaming (localhost:11434)
│   ├── KeychainManager.swift     # Security framework Keychain helpers for API keys
│   ├── EntryIndexer.swift        # NLEmbedding semantic index + cosine similarity RAG
│   └── freewrite.entitlements    # App permissions
├── ThinkINMCPServer/             # Standalone Swift Package (Swift 6) — MCP server
│   ├── Package.swift             # swift-tools-version: 6.0; depends on swift-sdk MCP
│   └── Sources/ThinkINMCPServer/main.swift  # StdioTransport server; 5 tools
├── CLAUDE.md                     # This file
└── AGENTS.md                     # Duplicate of this file
```

## Data Model

### Entry Types

```swift
enum EntryType {
    case text
    case video
}

struct HumanEntry: Identifiable, Equatable {
    let id: UUID
    let date: String              // Display format: "MMM d" (e.g., "Feb 20")
    let filename: String          // Format: [UUID]-[YYYY-MM-DD-HH-mm-ss].md
    var previewText: String       // First 30 chars or "Video Entry"
    var entryType: EntryType      // .text or .video
    var videoFilename: String?    // Format: [UUID]-[YYYY-MM-DD-HH-mm-ss].mov
}
```

### File Storage

**Location**: `~/Documents/Freewrite/`

**Text Entries**:
- Format: Markdown (.md)
- Naming: `[UUID]-[YYYY-MM-DD-HH-mm-ss].md`
- Content: Plain UTF-8 text
- Example: `[6910BBDE-75FC-415C-ABB9-C76644B037B2]-[2026-02-20-08-01-04].md`

**Video Entries**:
- Format: QuickTime Movie (.mov)
- Naming: `[UUID]-[YYYY-MM-DD-HH-mm-ss].mov`
- Metadata: Corresponding `.md` file with "Video Entry" text in `~/Documents/Freewrite/`
- Storage layout: `~/Documents/Freewrite/Videos/[UUID]-[YYYY-MM-DD-HH-mm-ss]/`
- Directory contents:
  - `[UUID]-[YYYY-MM-DD-HH-mm-ss].mov`
  - `thumbnail.jpg`
  - `transcript.md` (optional; speech transcript for that recording)
- Example directory: `~/Documents/Freewrite/Videos/[6910BBDE-75FC-415C-ABB9-C76644B037B2]-[2026-02-20-08-01-04]/`

## AI Architecture (Think IN)

### Provider Abstraction

All AI features route through `AIProvider` protocol:

```swift
protocol AIProvider {
    var isAvailable: Bool { get }
    var displayName: String { get }
    var requiresKey: Bool { get }
    func stream(prompt: String, instructions: String) -> AsyncThrowingStream<String, Error>
}
```

Three concrete providers:
- **`AppleOnDeviceProvider`**: `FoundationModels.LanguageModelSession.streamResponse`; delta = successive snapshot diffs; `isAvailable` checks `SystemLanguageModel.default.availability`
- **`BYOKProvider`**: OpenAI-compatible SSE; URLSession bytes stream; parses `data: {...}` lines; key in Keychain account `"byok"`
- **`OllamaProvider`**: NDJSON streaming at `localhost:11434`; each line is JSON; reads `message.content`; stops on `done: true`

`AIProviderStore` (`ObservableObject`) holds the active provider type and config, persists to UserDefaults, stores API keys in Keychain via `KeychainManager`, and writes `mcp-config.json` to `~/Library/Application Support/ThinkIN/` for the MCP server to read the write-enable toggle.

Injection: `freewriteApp` creates `@StateObject private var providerStore = AIProviderStore()` and injects it with `.environmentObject(providerStore)` on `ContentView`. All child views that need AI (`ExploreController`, `LookBackView`, `ThinkWithItView`, `ProviderSettingsView`) read it with `@EnvironmentObject private var providerStore: AIProviderStore`.

**Important**: The `ExploreController.run(prompt:provider:)` takes `any AIProvider` — always pass `providerStore.activeProvider`. The old `ExploreController.availability()` static method remains only for on-device status queries (used by `ProviderSettingsView`).

### Semantic Indexer

`EntryIndexer` (`ObservableObject`) builds a `NLEmbedding.sentenceEmbedding(for: .english)` index:
- Triggered by `.onChange(of: entries)` in `ContentView` → `updateIndex(entries:directory:)`
- Stores `[Float]` vectors per entry; cosine similarity search; keyword fallback
- Persisted to `~/Library/Application Support/ThinkIN/index.json`

### Think Panel

`ThinkWithItView` in a popover (nav button "Think"):
- **Ask mode**: semantic RAG query → top-K relevant entry snippets → active provider stream
- **Clarity mode**: on-device uses `@Generable ClarityOutput` (5 structured fields); BYOK/Ollama uses a text-mode structured prompt

`ContentView` owns `@StateObject private var entryIndexer = EntryIndexer()` and passes it to `ThinkWithItView`.

### MCP Server (External Agents)

`ThinkINMCPServer/` is a standalone Swift 6 Package (separate from the Xcode project):

```bash
# Build once
cd ThinkINMCPServer && swift build -c release

# Claude Desktop config example:
# "thinkin": { "command": ".build/release/ThinkINMCPServer" }
```

Five tools: `list_entries`, `search_entries`, `read_entry`, `append_to_entry`, `create_entry`.

Write tools (`append_to_entry`, `create_entry`) are **gated** — they return an error unless the user has enabled write access in Freewrite → Settings (cpu icon). The app writes `{"writeEnabled": true/false}` to `~/Library/Application Support/ThinkIN/mcp-config.json`; the MCP server reads this file at call time. All paths are scoped to `~/Documents/Freewrite/`.

## Key Components

### ContentView.swift

The main view containing all UI and business logic.

#### State Variables (Selection)

```swift
@State private var entries: [HumanEntry] = []           // All loaded entries
@State private var text: String = ""                    // Current text editor content
@State private var selectedEntryId: UUID? = nil         // Currently selected entry
@State private var showingVideoRecording = false        // Video recording overlay visibility
@State private var currentVideoURL: URL? = nil          // Video playback URL
@State private var showingSidebar = false               // History sidebar visibility
@State private var colorScheme: ColorScheme = .light    // Light/dark theme
@State private var fontSize: CGFloat = 18               // Text size (16-26px)
@State private var selectedFont: String = ...           // Resolved premium writing font preset
@State private var showingFounderTools = false          // Founder Explore popover visibility
@State private var selectedFounderTool = .explore       // Active founder artifact tab
@State private var timerIsRunning = false               // Timer state
@State private var timeRemaining: Int = 900             // Timer (seconds)
```

#### Core Functions

**Entry Management**:
- `loadExistingEntries()` - Loads all .md and .mov files from documents directory
- `createNewEntry()` - Creates new text entry
- `saveEntry(entry:)` - Saves text to .md file
- `loadEntry(entry:)` - Loads text or video for display
- `deleteEntry(entry:)` - Deletes entry and associated files
- `saveVideoEntry(from:)` - Saves recorded video and creates metadata

**Important**: When modifying the `entries` array from async contexts, wrap in `DispatchQueue.main.async` to prevent collection mutation crashes.

### VideoRecordingView.swift

Handles camera access and video recording.

#### CameraManager Class

```swift
class CameraManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: Int = 0
    @Published var permissionGranted = false

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
}
```

**Key Methods**:
- `setupCamera()` - Configures AVCaptureSession with video/audio inputs
- `startRecording(to:)` - Begins recording to temporary file
- `stopRecording()` - Stops recording and triggers completion handler
- `cleanup()` - Releases camera resources

**Critical**: Always use `beginConfiguration()` and `commitConfiguration()` when modifying AVCaptureSession to prevent crashes.
**UI Pattern**: The recorder is rendered as an immersive edge-to-edge overlay with a transparent bottom nav and a floating circular record control.

### VideoPlayerView.swift

Simple AVKit-based video player for playback.

```swift
struct VideoPlayerView: View {
    let videoURL: URL
    @State private var player: AVPlayer?
}
```

### GlassStyle.swift

Centralizes the app's Apple Liquid Glass design-system helpers.

- `freewriteGlassPanel(cornerRadius:interactive:)` applies Liquid Glass on macOS 26+ and falls back to `ultraThinMaterial` on older macOS versions
- `freewriteGlassBand(interactive:)` applies full-height/sidebar glass bands with the same fallback behavior
- `FreewriteGlassContainer(spacing:)` groups nearby glass elements so related controls resolve as one Liquid Glass system
- Interactive controls such as bottom-nav clusters and recorder controls should pass `interactive: true`; passive panels such as popovers and sidebars should usually remain non-interactive
- Avoid adding opaque nested backgrounds inside glass surfaces; use very low-opacity fills for selected/hover states so the glass material remains visible

## UI Layout

### Main Interface

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│                    Text Editor Area                     │
│              (or Video Player if video)                 │
│                                                         │
├─────────────────────────────────────────────────────────┤
│  Bottom Nav Bar:                                        │
│  [16px] • [Toggle Font]                                │
│  ... [15:00] • [🎥] • [Chat] • [Explore] • [...]       │
└─────────────────────────────────────────────────────────┘
```

### Sidebar (History)

```
┌────────────────────────────┐
│ History              📁  × │
│ 12 entries • Local markdown│
├────────────────────────────┤
│ ▌ [thumb] Entry preview    │ ← click row to open
│          Jun 8   Video     │ ← type/date metadata
│   [doc]  Text preview      │ ← hover row for export/delete actions
│          Jun 5   Text      │
└────────────────────────────┘
```

## Navigation Bar Items

### Left Side (Font Controls)
- **Font Size**: Cycles through [16, 18, 20, 22, 24, 26]px
- **Toggle Font**: Cycles through curated writing presets (New York, Iowan, Avenir, Lato, Mono) without showing every font name as separate UI
- Hover changes cursor to pointing hand
- **Video Mode Left Slot**: Replaced by `Copy Transcript` when viewing a video entry

### Liquid Glass Treatment
- Custom grouped surfaces use a local `freewriteGlassPanel(cornerRadius:interactive:)` wrapper
- On macOS 26+, the wrapper applies SwiftUI Liquid Glass via `glassEffect(_:in:)`
- On older macOS versions, the same wrapper falls back to `.ultraThinMaterial`
- Apply glass to grouped surfaces, not every label: bottom nav groups, popovers, Explore tool shell, sidebar band, and recorder controls
- The Explore popover uses one outer `freewriteGlassPanel`; internal source, tool-card, preview, and action regions use translucent fills so nested dark glass panels do not bury the effect. Keep local `Save Entry` as the primary action; `Copy Draft`, `Copy Prompt`, ChatGPT, and Claude are secondary actions.
- The history sidebar uses one background `freewriteGlassBand()` so it can sit flush against the window edge without clipped rounded corners; selected/hovered rows use translucent fills instead of opaque blocks. Rows are tappable containers rather than nested buttons, while export/delete remain separate hover actions.
- Avoid applying separate glass effects to every history row or every small text/button because Apple warns that too many Liquid Glass effects can hurt rendering performance

### Right Side (Utilities)
- **Timer**: Shows time remaining, click to start/stop, double-click to reset
- **Video Camera (🎥)**: Opens immersive video recording overlay
- **Chat**: Opens AI chat menu (ChatGPT/Claude integration)
- **Explore**: Opens local founder tools popover with source status, selectable artifact cards, a markdown preview, secondary `Copy Draft` / `Copy Prompt` / ChatGPT / Claude actions, and primary `Save Entry`. Outputs are generated from the current text entry or selected video transcript; if no source exists, the same tools produce blank templates.
- **Fullscreen**: Toggle fullscreen mode
- **New Entry**: Creates new text entry
- **Theme Toggle**: 🌙/☀️ for dark/light mode
- **History**: 🕐 Shows/hides sidebar

## Video Recording Flow

1. User clicks video camera icon (🎥)
2. Camera icon switches to a small spinner while preflight runs
3. App requests/validates **all required permissions**: camera + microphone + speech recognition
4. If any permission is missing, recorder is **not** presented; a compact popover above the camera icon explains what is missing and links to System Settings
5. Once camera session is fully ready (plus a short presentation delay), `VideoRecordingView` is rendered via `.overlay` on top of `ContentView` with animations disabled for open/close (plain swap, no transition)
6. Camera preview fills the entire window content area edge-to-edge
7. Transparent bottom nav appears over video with: `Close`, recording status, recording control text (`Start Recording` / `Stop Recording`), and timer
8. User clicks "Start Recording"
   - Recording begins to temp file
   - Timer starts counting up
   - Button changes to "Stop Recording"
9. User clicks "Stop Recording"
   - Recording stops
   - Speech transcript is finalized (spacing + sentence endings/capitalization)
   - `onRecordingComplete` closure called with temp URL + finalized transcript
10. `saveVideoEntry(from:transcript:)` called
   - Creates per-entry video directory in `~/Documents/Freewrite/Videos/[UUID]-[date]/`
   - Video copied from temp to `~/Documents/Freewrite/Videos/[UUID]-[date]/[UUID]-[date].mov`
   - Thumbnail generated once and saved to `~/Documents/Freewrite/Videos/[UUID]-[date]/thumbnail.jpg`
   - Transcript saved to `~/Documents/Freewrite/Videos/[UUID]-[date]/transcript.md` when available
   - Metadata file created: `[UUID]-[date].md` with "Video Entry"
   - Entry added to `entries` array (on main thread), selected immediately, and loaded into the main view
   - Playback starts automatically with audio enabled
   - Overlay dismissed
11. If user clicks `Close` while recording, the temp recording is discarded and no entry is created; recorder dismisses first, then camera cleanup runs on disappear

## Video Playback Flow

1. User clicks video entry in sidebar
2. `loadEntry(entry:)` checks `entry.entryType`
3. If `.video`:
   - Sets `currentVideoURL` to video file path
   - Clears `text`
4. Main view checks `if let videoURL = currentVideoURL`
5. Shows `VideoPlayerView(videoURL:)` instead of TextEditor
6. Video auto-plays muted with standard AVKit controls

## Entry Loading Logic

On app launch (`onAppear`):

1. `loadExistingEntries()` called
2. Reads all files from `~/Documents/Freewrite/`
3. Filters for canonical `.md` entries and derives expected `.mov` name from each `.md`
4. For each `.md` file:
   - Extracts UUID and date from filename via regex
   - Checks for corresponding `.mov` in this order:
     - `~/Documents/Freewrite/Videos/[entry-base]/[entry].mov` (current layout)
     - `~/Documents/Freewrite/Videos/[entry].mov` (legacy flat layout)
     - `~/Documents/Freewrite/[entry].mov` (oldest legacy layout)
   - Creates `HumanEntry` with appropriate type
5. Sorts entries by date (newest first)
6. Applies launch selection rules in order:
   - If newest entry is a video entry: create a new text entry and select it (never open directly into video on app launch)
   - Else if no entries: create welcome entry
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

Required entitlements in `freewrite.entitlements`:

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.device.camera</key>
<true/>
<key>com.apple.security.device.audio-input</key>
<true/>
<key>com.apple.security.personal-information.speech-recognition</key>
<true/>
```

Privacy usage descriptions (in Xcode project build settings):

```
INFOPLIST_KEY_NSCameraUsageDescription = "Freewrite needs camera access to record video entries."
INFOPLIST_KEY_NSMicrophoneUsageDescription = "Freewrite needs microphone access to record audio with your video entries."
INFOPLIST_KEY_NSSpeechRecognitionUsageDescription = "Freewrite uses speech recognition to transcribe your video entries."
```

## Technical Nuances & Implementation Details

### Threading Model

The app uses a **hybrid threading approach**:

1. **Main Thread**: All UI updates and `@State` mutations
2. **Global Queue**: File I/O operations (reading/writing markdown files)
3. **AVFoundation Queue**: Camera setup and video capture

**Critical Threading Issue**:
SwiftUI's `ForEach` creates an enumerator over the `entries` array. If you modify this array (insert, remove, replace) while the enumerator is active, you get `NSGenericException: Collection was mutated while being enumerated`.

**Solution Pattern**:
```swift
// When in async context (camera completion handler, DispatchQueue callback):
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
    // Extract UUID from filename using regex
    let uuidMatch = filename.range(of: "\\[(.*?)\\]", options: .regularExpression)
    let uuid = UUID(uuidString: String(filename[uuidMatch].dropFirst().dropLast()))

    // Extract timestamp
    let dateMatch = filename.range(of: "\\[(\\d{4}-\\d{2}-\\d{2}-\\d{2}-\\d{2}-\\d{2})\\]", ...)
    let dateString = String(filename[dateMatch].dropFirst().dropLast())

    // Parse date for sorting
    dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
    let fileDate = dateFormatter.date(from: dateString)

    // Check for corresponding video
    let videoFilename = filename.replacingOccurrences(of: ".md", with: ".mov")
    let hasVideo = hasVideoAsset(for: videoFilename) // checks current + legacy locations

    // Read content for preview
    let content = try String(contentsOf: fileURL, encoding: .utf8)
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

**Why separate .md and .mov files instead of embedding?**

- User can open .md files in any text editor
- Video files can be played in QuickTime independently
- Easier to backup/sync text separately from large video files
- Transparent file format for user ownership
- Per-entry video directories keep each recording's media + thumbnail together

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

### Video Recording Architecture

**AVFoundation Setup Sequence**:

```swift
// 1. Create session
captureSession = AVCaptureSession()

// 2. Get devices
let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
let audioDevice = AVCaptureDevice.default(for: .audio)

// 3. Create inputs
let videoInput = try AVCaptureDeviceInput(device: videoDevice)
let audioInput = try AVCaptureDeviceInput(device: audioDevice)

// 4. CRITICAL: Begin configuration
captureSession?.beginConfiguration()

// 5. Configure session
captureSession?.sessionPreset = .high
captureSession?.addInput(videoInput)
captureSession?.addInput(audioInput)

// 6. Add output
videoOutput = AVCaptureMovieFileOutput()
captureSession?.addOutput(videoOutput!)
audioDataOutput = AVCaptureAudioDataOutput()
audioDataOutput?.setSampleBufferDelegate(self, queue: speechQueue)
captureSession?.addOutput(audioDataOutput!)

// 7. CRITICAL: Commit configuration
captureSession?.commitConfiguration()

// 8. Start running on background thread
DispatchQueue.global(qos: .userInitiated).async {
    self.captureSession?.startRunning()
}
```

**Startup/Teardown Safety Rule**:
- Trigger camera setup from a single lifecycle path (avoid duplicate `checkPermissions()` calls for the same view presentation).
- Call `startRunning()` only once per configured session startup path.
- Guard setup with a dedicated in-flight flag (e.g. `isSettingUpSession`) so repeated permission callbacks/onAppear events cannot run parallel setup work.
- Attach/bind `AVCaptureVideoPreviewLayer` only after `startRunning()` completes to avoid concurrent session mutations during startup.
- During teardown, prefer `stopRunning()` + releasing references over removing inputs/outputs while the session may still be transitioning states.

**Why `beginConfiguration()` / `commitConfiguration()`?**

AVCaptureSession maintains internal arrays of inputs/outputs. When you call `addInput()` or `addOutput()`, it mutates these arrays. If the session is actively running or if another thread is enumerating these arrays (for validation, etc.), you get collection mutation crash.

`beginConfiguration()` tells the session: "I'm about to make multiple changes, don't validate or enumerate until I'm done."

`commitConfiguration()` tells the session: "I'm done, now validate everything and update internal state."

**Recording Flow**:

```swift
// Start recording
videoOutput.startRecording(to: tempURL, recordingDelegate: self)

// Delegate callback when done
func fileOutput(_ output: AVCaptureFileOutput,
                didFinishRecordingTo outputFileURL: URL,
                from connections: [AVCaptureConnection],
                error: Error?) {
    DispatchQueue.main.async {
        self.onRecordingComplete?(outputFileURL)
    }
}
```

**Temporary File Strategy**:
- Record to temp directory: `FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")`
- On completion: Copy to permanent location
- Why? If recording fails, temp file is auto-cleaned by OS

### Speech Transcription (Speech Framework)

Speech transcription in `VideoRecordingView` is implemented with Apple's `Speech` framework and runs in the background during recording:

1. Request speech auth with `SFSpeechRecognizer.requestAuthorization`.
2. Keep camera/video recording on `AVCaptureMovieFileOutput`.
3. Add `AVCaptureAudioDataOutput` to the same capture session and stream sample buffers to speech recognition.
4. Feed sample buffers into `SFSpeechAudioBufferRecognitionRequest` (`appendAudioSampleBuffer`).
5. Build partial + committed transcript text while recording (no live caption overlay rendered).
6. Finalize transcript on stop and persist it as `transcript.md` in that entry's video directory.

Key details:
- Camera, microphone, and speech recognition permissions are all required before opening the recorder.
- If any permission is denied, the app keeps the user in the writing view and shows a compact camera-icon popover with the missing permission(s).
- Transcription is started on recording start and stopped on recording stop.
- Final transcript formatting is applied at stop to improve readability before saving/copying.
- Video playback nav exposes `Copy Transcript` for saved video entries with a transcript file.
- App sandbox requires `com.apple.security.personal-information.speech-recognition` entitlement plus `NSSpeechRecognitionUsageDescription`.

### Video Thumbnail Generation Nuances

```swift
func generateVideoThumbnail(from url: URL) -> NSImage? {
    let asset = AVAsset(url: url)
    let imageGenerator = AVAssetImageGenerator(asset: asset)
    imageGenerator.appliesPreferredTrackTransform = true  // CRITICAL

    let cgImage = try imageGenerator.copyCGImage(at: CMTime(seconds: 0, preferredTimescale: 1), ...)
    return NSImage(cgImage: cgImage, size: NSSize(...))
}
```

**`appliesPreferredTrackTransform = true`**:

Videos recorded on front-facing camera are often rotated 90°. The video file contains a transform matrix that says "rotate this video when playing." Without `appliesPreferredTrackTransform`, the thumbnail would be sideways.

**Performance Note**: Thumbnails are generated once when a recording is saved and persisted as `thumbnail.jpg` in each entry's video directory. Sidebar rows load precomputed image files instead of extracting frames from `.mov` during render. For older entries without thumbnails, the app lazily generates once and saves for subsequent loads.

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

### AVCaptureSession Crashes

**Problem**: Session internals can crash with `Collection ... was mutated while being enumerated` when session startup/teardown overlaps (for example duplicate setup/start calls or mutating inputs/outputs during active transitions).

**Solution**:
```swift
captureSession?.beginConfiguration()
// Add/remove inputs and outputs here
captureSession?.sessionPreset = .high
captureSession?.addInput(videoInput)
captureSession?.commitConfiguration()
```

Also:
```swift
// Avoid duplicate startup paths for the same presentation
// and avoid repeated startRunning() calls on the same setup cycle.

if session.isRunning {
    session.stopRunning()
}
// Release session/output references without input/output removal churn.
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

## Testing Video Feature

1. Build and run app
2. Grant camera/microphone permissions when prompted
3. Click video camera icon in bottom nav
4. Click "Start Recording" (turns red)
5. Record for a few seconds
6. Click "Stop Recording"
7. Recorder overlay closes, new video entry is selected, and video opens immediately playing muted
8. Click video entry to play it

## Video Thumbnail Generation

```swift
func generateVideoThumbnail(from url: URL) -> NSImage? {
    let asset = AVAsset(url: url)
    let imageGenerator = AVAssetImageGenerator(asset: asset)
    imageGenerator.appliesPreferredTrackTransform = true

    let cgImage = try imageGenerator.copyCGImage(at: CMTime(seconds: 0, preferredTimescale: 1), actualTime: nil)
    return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
}
```

Generated at save time and stored in the per-entry video directory; sidebar loads this cached image file.

## Feature Flags / Settings

Stored in `UserDefaults`:
- `colorScheme`: "light" or "dark"

Other settings are session-only (not persisted):
- Font size, font family, timer duration

## Future Development Notes

### Adding New Entry Types

1. Add case to `EntryType` enum
2. Update `HumanEntry` with relevant properties
3. Modify `loadExistingEntries()` to detect new file type
4. Update `loadEntry()` to handle new type
5. Add UI in main view for new entry type
6. Update `deleteEntry()` to clean up new file types

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
- Entry creation: "Successfully created video entry"
- Errors: "Error saving video entry: ..."

Check `~/Documents/Freewrite/` in Finder to verify files are being created.

## Code Organization

- **Lines 1-130**: Imports, models, state variables
- **Lines 130-430**: Computed properties and helpers
- **Lines 430-1200**: Main view body and UI
- **Lines 1200-1400**: Helper functions (save, load, delete, etc.)

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
