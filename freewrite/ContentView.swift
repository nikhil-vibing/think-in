// Swift 5.0
//
//  ContentView.swift
//  freewrite
//
//  Created by thorfinn on 2/14/25.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PDFKit

enum EntryType {
    case text
    case video
}

struct HumanEntry: Identifiable {
    let id: UUID
    let date: String
    let filename: String
    var previewText: String
    var entryType: EntryType
    var videoFilename: String?

    static func createNew() -> HumanEntry {
        let id = UUID()
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let dateString = dateFormatter.string(from: now)

        // For display
        dateFormatter.dateFormat = "MMM d"
        let displayDate = dateFormatter.string(from: now)

        return HumanEntry(
            id: id,
            date: displayDate,
            filename: "[\(id)]-[\(dateString)].md",
            previewText: "",
            entryType: .text,
            videoFilename: nil
        )
    }

    static func createVideoEntry() -> HumanEntry {
        let id = UUID()
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let dateString = dateFormatter.string(from: now)

        // For display
        dateFormatter.dateFormat = "MMM d"
        let displayDate = dateFormatter.string(from: now)

        let videoFilename = "[\(id)]-[\(dateString)].mov"

        return HumanEntry(
            id: id,
            date: displayDate,
            filename: "[\(id)]-[\(dateString)].md",
            previewText: "Video Entry",
            entryType: .video,
            videoFilename: videoFilename
        )
    }
}

struct HeartEmoji: Identifiable {
    let id = UUID()
    var position: CGPoint
    var offset: CGFloat = 0
}

struct ContentView: View {
    private struct WritingFontPreset {
        let label: String
        let candidates: [String]
    }

    private enum FounderTool: String, CaseIterable, Identifiable {
        case explore = "Explore"
        case assumptions = "Assumptions"
        case customerStory = "Customer Story"
        case opportunityMap = "Opportunity Map"
        case pmfSignal = "PMF Signal"
        case memo = "Memo"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .explore: return "sparkles"
            case .assumptions: return "checklist"
            case .customerStory: return "person.text.rectangle"
            case .opportunityMap: return "map"
            case .pmfSignal: return "waveform.path.ecg"
            case .memo: return "doc.text"
            }
        }

        var lane: String {
            switch self {
            case .explore: return "Synthesize"
            case .assumptions: return "Validate"
            case .customerStory: return "Research"
            case .opportunityMap: return "Map"
            case .pmfSignal: return "Measure"
            case .memo: return "Decide"
            }
        }
    }

    private struct VideoPermissionPopoverItem: Identifiable {
        let id = UUID()
        let message: String
        let buttonLabel: String
        let settingsPane: String
    }

    @State private var entries: [HumanEntry] = []
    @State private var text: String = ""  // Remove initial welcome text since we'll handle it in createNewEntry
    
    @State private var isFullscreen = false
    @State private var selectedFontPresetIndex = 0
    @State private var selectedFont: String = ContentView.resolveFontName(["Georgia", "Iowan Old Style", "Times New Roman"])
    @State private var timeRemaining: Int = 900  // Changed to 900 seconds (15 minutes)
    @State private var timerIsRunning = false
    @State private var isHoveringTimer = false
    @State private var isHoveringFullscreen = false
    @State private var hoveredFont: String? = nil
    @State private var isHoveringSize = false
    @State private var fontSize: CGFloat = 18
    @State private var blinkCount = 0
    @State private var isBlinking = false
    @State private var opacity: Double = 1.0
    @State private var shouldShowGray = true // New state to control color
    @State private var lastClickTime: Date? = nil
    @State private var bottomNavOpacity: Double = 1.0
    @State private var isHoveringBottomNav = false
    @State private var selectedEntryIndex: Int = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var selectedEntryId: UUID? = nil
    @State private var hoveredEntryId: UUID? = nil
    @State private var isHoveringExplore = false
    @State private var showingFounderTools = false
    @State private var selectedFounderTool: FounderTool = .explore
    @State private var didCopyFounderTool = false
    @State private var showingSidebar = false  // Add this state variable
    @State private var hoveredTrashId: UUID? = nil
    @State private var hoveredExportId: UUID? = nil
    @State private var placeholderText: String = ""  // Add this line
    @State private var isHoveringNewEntry = false
    @State private var isHoveringClock = false
    @State private var isHoveringHistory = false
    @State private var isHoveringCopyTranscript = false
    @State private var colorScheme: ColorScheme = .light // Add state for color scheme
    @State private var isHoveringThemeToggle = false // Add state for theme toggle hover
    @State private var didCopyTranscript: Bool = false
    @State private var selectedVideoHasTranscript = false
    @State private var showingVideoRecording = false // Add state for video recording view
    @State private var isHoveringVideoButton = false // Add state for video button hover
    @State private var currentVideoURL: URL? = nil // Add state for current video being viewed
    @State private var isPreparingVideoRecording = false
    @State private var preparedCameraManager: CameraManager? = nil
    @State private var videoRecordingPreparationID: UUID? = nil
    @State private var showingVideoPermissionPopover = false
    @State private var videoPermissionPopoverItems: [VideoPermissionPopoverItem] = []
    @State private var videoPermissionPopoverFallbackMessage: String? = nil
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let entryHeight: CGFloat = 40
    let editorHorizontalPadding: CGFloat = 56
    
    private static let writingFontPresets: [WritingFontPreset] = [
        WritingFontPreset(label: "Serif", candidates: ["Georgia", "Iowan Old Style", "Times New Roman"]),
        WritingFontPreset(label: "Iowan", candidates: ["Iowan Old Style", "Athelas", "Hoefler Text", "Georgia"]),
        WritingFontPreset(label: "Avenir", candidates: ["Avenir Next", "Avenir", "Helvetica Neue", ".AppleSystemUIFont"]),
        WritingFontPreset(label: "Lato", candidates: ["Lato-Regular", "Lato", "Helvetica Neue", ".AppleSystemUIFont"]),
        WritingFontPreset(label: "Mono", candidates: ["Menlo", "Monaco", "Courier Prime", "Courier"])
    ]

    let fontSizes: [CGFloat] = [16, 18, 20, 22, 24, 26]
    private let founderPlaceholderOptions = [
        "What customer signal keeps bothering you",
        "What problem did you see today",
        "What are users doing manually",
        "What assumption feels shaky",
        "What would make this obviously useful",
        "What did a customer say that stuck",
        "What are you avoiding because it is messy",
        "What tiny experiment would teach you the most",
        "What do you know that the market is missing",
        "Where is the wedge"
    ]
    
    // Add file manager and save timer
    private let fileManager = FileManager.default
    private let saveTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    // Add cached documents directory
    private let documentsDirectory: URL = {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Freewrite")
        
        // Create Freewrite directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                print("Successfully created Freewrite directory")
            } catch {
                print("Error creating directory: \(error)")
            }
        }
        
        return directory
    }()

    private let videosDirectory: URL = {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Freewrite")
            .appendingPathComponent("Videos")

        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                print("Successfully created Freewrite/Videos directory")
            } catch {
                print("Error creating videos directory: \(error)")
            }
        }

        return directory
    }()

    private let thumbnailMemoryCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 512
        return cache
    }()
    
    // Add shared prompt constant
    private let founderAIChatPrompt = """
    I am a founder freewriting to generate startup clarity. Do not treat this like polished strategy. Treat it like raw signal.

    First, read through the mess without judging grammar, structure, or contradictions. Then give me a concise founder debrief:
    - the strongest customer/problem signal
    - the hidden assumption I should test
    - the sharpest wedge or ICP implied by what I wrote
    - one small experiment I can run in the next 48 hours
    - one sentence I could use as a clearer founder memo or product thesis

    Be direct and practical. Preserve the useful weirdness. Do not over-sanitize the idea.

    My founder freewrite:
    """

    private let founderClaudePrompt = """
    I am a founder using freewriting to find startup signal before I prematurely plan. Read this as raw founder thinking, not as a finished memo.

    Help me extract the business clarity underneath it:
    - what problem or customer pain is most alive here
    - what founder insight or unfair advantage might be hiding here
    - what assumption is dangerous if false
    - what I should ask customers next
    - what tiny build, sales, or research action would create evidence fast

    Keep it candid, specific, and founder-to-founder. If the entry is scattered, find the pattern instead of summarizing every line.

    My founder freewrite:
    """
    
    // Initialize with saved theme preference if available
    init() {
        // Load saved color scheme preference
        let savedScheme = UserDefaults.standard.string(forKey: "colorScheme") ?? "light"
        _colorScheme = State(initialValue: savedScheme == "dark" ? .dark : .light)
    }
    
    // Modify getDocumentsDirectory to use cached value
    private func getDocumentsDirectory() -> URL {
        return documentsDirectory
    }

    private func getVideosDirectory() -> URL {
        return videosDirectory
    }

    private func getVideoEntryDirectory(for videoFilename: String) -> URL {
        let baseName = (videoFilename as NSString).deletingPathExtension
        return getVideosDirectory().appendingPathComponent(baseName, isDirectory: true)
    }

    private func getManagedVideoURL(for filename: String) -> URL {
        getVideoEntryDirectory(for: filename).appendingPathComponent(filename)
    }

    private func getVideoThumbnailURL(for filename: String) -> URL {
        getVideoEntryDirectory(for: filename).appendingPathComponent("thumbnail.jpg")
    }

    private func getVideoTranscriptURL(for filename: String) -> URL {
        getVideoEntryDirectory(for: filename).appendingPathComponent("transcript.md")
    }

    @discardableResult
    private func ensureVideoEntryDirectoryExists(for videoFilename: String) throws -> URL {
        let directory = getVideoEntryDirectory(for: videoFilename)
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private func getVideoURL(for filename: String) -> URL {
        // Current production layout: Videos/[entry-base]/[entry-filename].mov
        let managedVideoURL = getManagedVideoURL(for: filename)
        if fileManager.fileExists(atPath: managedVideoURL.path) {
            return managedVideoURL
        }

        // Backward compatibility: older builds stored videos flat under Videos/
        let flatVideosURL = getVideosDirectory().appendingPathComponent(filename)
        if fileManager.fileExists(atPath: flatVideosURL.path) {
            return flatVideosURL
        }

        // Backward compatibility: oldest builds stored videos in root Freewrite folder
        let rootVideosURL = getDocumentsDirectory().appendingPathComponent(filename)
        if fileManager.fileExists(atPath: rootVideosURL.path) {
            return rootVideosURL
        }

        // Default to managed path for newly created entries.
        return managedVideoURL
    }

    private func hasVideoAsset(for filename: String) -> Bool {
        let managedVideoURL = getManagedVideoURL(for: filename)
        if fileManager.fileExists(atPath: managedVideoURL.path) {
            return true
        }

        let flatVideosURL = getVideosDirectory().appendingPathComponent(filename)
        if fileManager.fileExists(atPath: flatVideosURL.path) {
            return true
        }

        let rootVideosURL = getDocumentsDirectory().appendingPathComponent(filename)
        return fileManager.fileExists(atPath: rootVideosURL.path)
    }

    private let historyDebugEnabled = true

    private func historyDebug(_ message: String) {
        guard historyDebugEnabled else { return }
        print("[HistoryDebug] \(message)")
    }

    private func debugEntrySummary(_ entry: HumanEntry) -> String {
        let shortID = String(entry.id.uuidString.prefix(8))
        let type = entry.entryType == .video ? "video" : "text"
        let videoFilename = resolvedVideoFilename(for: entry) ?? "-"
        return "id=\(shortID) type=\(type) file=\(entry.filename) video=\(videoFilename)"
    }

    private func logEntriesOrder(_ reason: String, limit: Int = 20) {
        guard historyDebugEnabled else { return }
        historyDebug("ORDER SNAPSHOT (\(reason)) total=\(entries.count) selected=\(selectedEntryId?.uuidString ?? "nil")")
        for (index, entry) in entries.prefix(limit).enumerated() {
            historyDebug("#\(index + 1) \(debugEntrySummary(entry))")
        }
    }

    private func resolvedVideoFilename(for entry: HumanEntry) -> String? {
        guard entry.entryType == .video else {
            return nil
        }
        if let videoFilename = entry.videoFilename, !videoFilename.isEmpty {
            return videoFilename
        }
        return entry.filename.replacingOccurrences(of: ".md", with: ".mov")
    }

    private func persistThumbnail(_ image: NSImage, for videoFilename: String) {
        do {
            let directory = try ensureVideoEntryDirectoryExists(for: videoFilename)
            let thumbnailURL = directory.appendingPathComponent("thumbnail.jpg")
            guard let tiff = image.tiffRepresentation,
                  let bitmapRep = NSBitmapImageRep(data: tiff),
                  let imageData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.82]) else {
                print("Could not convert thumbnail image to JPEG data")
                return
            }
            try imageData.write(to: thumbnailURL, options: .atomic)
        } catch {
            print("Error saving thumbnail: \(error)")
        }
    }

    private func loadThumbnailImage(for videoFilename: String) -> NSImage? {
        let cacheKey = videoFilename as NSString
        if let cachedImage = thumbnailMemoryCache.object(forKey: cacheKey) {
            return cachedImage
        }

        let thumbnailURL = getVideoThumbnailURL(for: videoFilename)
        if fileManager.fileExists(atPath: thumbnailURL.path),
           let image = NSImage(contentsOf: thumbnailURL) {
            thumbnailMemoryCache.setObject(image, forKey: cacheKey)
            return image
        }

        // Backward compatibility: generate once for old video entries, then persist.
        let videoURL = getVideoURL(for: videoFilename)
        guard fileManager.fileExists(atPath: videoURL.path),
              let generated = generateVideoThumbnail(from: videoURL) else {
            historyDebug("THUMBNAIL MISS video=\(videoFilename) thumbnailPath=\(thumbnailURL.path) videoPath=\(videoURL.path)")
            return nil
        }
        persistThumbnail(generated, for: videoFilename)
        thumbnailMemoryCache.setObject(generated, forKey: cacheKey)
        historyDebug("THUMBNAIL GENERATED video=\(videoFilename) thumbnailPath=\(thumbnailURL.path)")
        return generated
    }

    private func deleteVideoAssets(for videoFilename: String) {
        thumbnailMemoryCache.removeObject(forKey: videoFilename as NSString)

        let managedDirectory = getVideoEntryDirectory(for: videoFilename)
        let managedVideoURL = managedDirectory.appendingPathComponent(videoFilename)
        let managedThumbnailURL = managedDirectory.appendingPathComponent("thumbnail.jpg")
        let managedTranscriptURL = managedDirectory.appendingPathComponent("transcript.md")
        let flatVideosURL = getVideosDirectory().appendingPathComponent(videoFilename)
        let rootVideosURL = getDocumentsDirectory().appendingPathComponent(videoFilename)

        let candidateURLs = [managedVideoURL, managedThumbnailURL, managedTranscriptURL, flatVideosURL, rootVideosURL]
        for url in candidateURLs where fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.removeItem(at: url)
            } catch {
                print("Error deleting video asset \(url.lastPathComponent): \(error)")
            }
        }

        if fileManager.fileExists(atPath: managedDirectory.path) {
            do {
                try fileManager.removeItem(at: managedDirectory)
            } catch {
                print("Error deleting video entry directory: \(error)")
            }
        }
    }

    private func loadTranscriptText(for videoFilename: String) -> String? {
        let transcriptURL = getVideoTranscriptURL(for: videoFilename)
        guard fileManager.fileExists(atPath: transcriptURL.path),
              let content = try? String(contentsOf: transcriptURL, encoding: .utf8) else {
            return nil
        }
        let cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private func previewTextFromTranscript(_ transcript: String?) -> String {
        guard let transcript else {
            return "Video Entry"
        }

        let normalized = transcript
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else {
            return "Video Entry"
        }

        var preview = String(normalized.prefix(10))

        while let last = preview.last, (!last.isLetter && !last.isNumber) {
            preview.removeLast()
        }

        if preview.isEmpty {
            return "Video Entry"
        }

        return preview + "..."
    }

    private func videoPreviewText(for videoFilename: String) -> String {
        previewTextFromTranscript(loadTranscriptText(for: videoFilename))
    }

    private func copyTranscriptForSelectedVideoEntry() {
        guard let selectedEntryId,
              let selectedEntry = entries.first(where: { $0.id == selectedEntryId }),
              let videoFilename = resolvedVideoFilename(for: selectedEntry),
              let transcript = loadTranscriptText(for: videoFilename) else {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(transcript, forType: .string)
        didCopyTranscript = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            didCopyTranscript = false
        }
    }
    
    private func parseCanonicalEntryFilename(_ filename: String) -> (uuid: UUID, timestamp: Date)? {
        guard filename.hasPrefix("["),
              filename.hasSuffix("].md"),
              let divider = filename.range(of: "]-[") else {
            return nil
        }

        let uuidStart = filename.index(after: filename.startIndex)
        let uuidString = String(filename[uuidStart..<divider.lowerBound])
        guard let uuid = UUID(uuidString: uuidString) else {
            return nil
        }

        let timestampStart = divider.upperBound
        let timestampEnd = filename.index(filename.endIndex, offsetBy: -4) // before ".md"
        let timestampString = String(filename[timestampStart..<timestampEnd])
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        guard let timestamp = formatter.date(from: timestampString) else {
            return nil
        }

        return (uuid: uuid, timestamp: timestamp)
    }
    
    private func isEntryNewer(_ lhs: HumanEntry, than rhs: HumanEntry) -> Bool {
        let lhsTimestamp = parseCanonicalEntryFilename(lhs.filename)?.timestamp ?? .distantPast
        let rhsTimestamp = parseCanonicalEntryFilename(rhs.filename)?.timestamp ?? .distantPast
        if lhsTimestamp == rhsTimestamp {
            return lhs.filename > rhs.filename
        }
        return lhsTimestamp > rhsTimestamp
    }
    
    private func isEntryFromToday(_ entry: HumanEntry, calendar: Calendar = .current, today: Date = Date()) -> Bool {
        guard let timestamp = parseCanonicalEntryFilename(entry.filename)?.timestamp else {
            return false
        }
        return calendar.isDate(timestamp, inSameDayAs: today)
    }
    
    // Add function to save text
    private func saveText() {
        let documentsDirectory = getDocumentsDirectory()
        let fileURL = documentsDirectory.appendingPathComponent("entry.md")
        
        print("Attempting to save file to: \(fileURL.path)")
        
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Successfully saved file")
        } catch {
            print("Error saving file: \(error)")
            print("Error details: \(error.localizedDescription)")
        }
    }
    
    // Add function to load text
    private func loadText() {
        let documentsDirectory = getDocumentsDirectory()
        let fileURL = documentsDirectory.appendingPathComponent("entry.md")
        
        print("Attempting to load file from: \(fileURL.path)")
        
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                text = try String(contentsOf: fileURL, encoding: .utf8)
                print("Successfully loaded file")
            } else {
                print("File does not exist yet")
            }
        } catch {
            print("Error loading file: \(error)")
            print("Error details: \(error.localizedDescription)")
        }
    }
    
    // Add function to load existing entries
    private func loadExistingEntries() {
        let documentsDirectory = getDocumentsDirectory()
        print("Looking for entries in: \(documentsDirectory.path)")
        print("Looking for videos in: \(getVideosDirectory().path)")
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            let mdFiles = fileURLs.filter { $0.pathExtension == "md" }

            print("Found \(mdFiles.count) .md files")

            // Process each file
            let entriesWithDates = mdFiles.compactMap { fileURL -> (entry: HumanEntry, date: Date, content: String)? in
                let filename = fileURL.lastPathComponent
                print("Processing: \(filename)")

                // Only accept canonical entry filenames: [UUID]-[yyyy-MM-dd-HH-mm-ss].md
                guard let parsed = parseCanonicalEntryFilename(filename) else {
                    print("Skipping non-canonical entry filename: \(filename)")
                    return nil
                }
                let uuid = parsed.uuid
                let fileDate = parsed.timestamp

                // Check if there's a corresponding video file
                let videoFilename = filename.replacingOccurrences(of: ".md", with: ".mov")
                let hasVideo = hasVideoAsset(for: videoFilename)

                // Read file contents for preview
                do {
                    let content = try String(contentsOf: fileURL, encoding: .utf8)
                    let preview = content
                        .replacingOccurrences(of: "\n", with: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let truncated = preview.isEmpty ? "" : (preview.count > 30 ? String(preview.prefix(30)) + "..." : preview)

                    // Format display date
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "MMM d"
                    let displayDate = dateFormatter.string(from: fileDate)

                    return (
                        entry: HumanEntry(
                            id: uuid,
                            date: displayDate,
                            filename: filename,
                            previewText: hasVideo ? videoPreviewText(for: videoFilename) : truncated,
                            entryType: hasVideo ? .video : .text,
                            videoFilename: hasVideo ? videoFilename : nil
                        ),
                        date: fileDate,
                        content: content  // Store the full content to check for welcome message
                    )
                } catch {
                    print("Error reading file: \(error)")
                    return nil
                }
            }
            
            // Sort and extract entries - store in temporary variable
            let loadedEntries = entriesWithDates
                .sorted {
                    if $0.date == $1.date {
                        return $0.entry.filename > $1.entry.filename
                    }
                    return $0.date > $1.date
                }
                .map { $0.entry }

            print("Successfully loaded and sorted \(loadedEntries.count) entries")

            // Check if we need to create a new entry
            let calendar = Calendar.current
            let today = Date()
            let hasEntryToday = loadedEntries.contains { isEntryFromToday($0, calendar: calendar, today: today) }
            let hasEmptyTextEntryToday = loadedEntries.contains {
                isEntryFromToday($0, calendar: calendar, today: today) &&
                $0.entryType == .text &&
                $0.previewText.isEmpty
            }

            // Check if we have only one entry and it's the welcome message
            let hasOnlyWelcomeEntry = loadedEntries.count == 1 && entriesWithDates.first?.content.contains("Welcome to Freewrite.") == true

            // Now assign to the state variable
            entries = loadedEntries
            logEntriesOrder("loadExistingEntries")

            // Never open directly into video on startup; create a fresh text entry instead.
            if let latestEntry = entries.first, latestEntry.entryType == .video {
                print("Latest entry is video, creating new text entry for startup")
                createNewEntry()
                return
            }

            if entries.isEmpty {
                // First time user - create entry with welcome message
                print("First time user, creating welcome entry")
                createNewEntry()
            } else if !hasEntryToday && !hasOnlyWelcomeEntry {
                // No entries at all for today - create a new text entry
                print("No entry for today, creating new entry")
                createNewEntry()
            } else {
                // Prefer an empty text entry from today for writing continuity; otherwise pick latest entry.
                if hasEmptyTextEntryToday,
                   let todayEntry = entries.first(where: {
                       isEntryFromToday($0, calendar: calendar, today: today) &&
                       $0.entryType == .text &&
                       $0.previewText.isEmpty
                   }) {
                    selectedEntryId = todayEntry.id
                    loadEntry(entry: todayEntry)
                } else if hasOnlyWelcomeEntry {
                    // If we only have the welcome entry, select it
                    selectedEntryId = entries[0].id
                    loadEntry(entry: entries[0])
                } else if let latestEntry = entries.first {
                    selectedEntryId = latestEntry.id
                    loadEntry(entry: latestEntry)
                }
            }
            
        } catch {
            print("Error loading directory contents: \(error)")
            print("Creating default entry after error")
            createNewEntry()
        }
    }
    
    private func startVideoRecordingPreflight() {
        guard !isPreparingVideoRecording, !showingVideoRecording else {
            return
        }

        showingVideoPermissionPopover = false
        videoPermissionPopoverItems = []
        videoPermissionPopoverFallbackMessage = nil

        let preparationID = UUID()
        let manager = CameraManager()

        videoRecordingPreparationID = preparationID
        preparedCameraManager = manager

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isPreparingVideoRecording = true
        }

        manager.onReadyToRecord = { [weak manager] in
            guard let manager else { return }
            DispatchQueue.main.async {
                finishVideoRecordingPreflight(
                    preparationID: preparationID,
                    manager: manager,
                    presentationDelay: 0.5
                )
            }
        }

        manager.onCannotRecord = { [weak manager] in
            guard let manager else { return }
            DispatchQueue.main.async {
                guard self.videoRecordingPreparationID == preparationID else {
                    return
                }
                let payload = self.videoPermissionPopoverPayload(
                    cameraGranted: manager.permissionGranted,
                    microphoneGranted: manager.microphonePermissionGranted,
                    speechGranted: manager.speechPermissionGranted
                )
                self.videoPermissionPopoverItems = payload.items
                self.videoPermissionPopoverFallbackMessage = payload.fallbackMessage
                self.showingVideoPermissionPopover = true
                self.clearVideoRecordingPreparationState()
            }
        }

        manager.checkPermissions()
    }

    private func finishVideoRecordingPreflight(
        preparationID: UUID,
        manager: CameraManager,
        presentationDelay: TimeInterval = 0
    ) {
        let presentRecorder = {
            guard videoRecordingPreparationID == preparationID else {
                return
            }

            videoRecordingPreparationID = nil
            manager.onReadyToRecord = nil
            manager.onCannotRecord = nil
            preparedCameraManager = manager

            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                isPreparingVideoRecording = false
                showingVideoRecording = true
            }
        }

        if presentationDelay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + presentationDelay) {
                presentRecorder()
            }
        } else {
            presentRecorder()
        }
    }

    private func clearVideoRecordingPreparationState() {
        preparedCameraManager?.onReadyToRecord = nil
        preparedCameraManager?.onCannotRecord = nil
        videoRecordingPreparationID = nil
        isPreparingVideoRecording = false
        preparedCameraManager = nil
    }

    private func videoPermissionPopoverPayload(
        cameraGranted: Bool,
        microphoneGranted: Bool,
        speechGranted: Bool
    ) -> (items: [VideoPermissionPopoverItem], fallbackMessage: String?) {
        var items: [VideoPermissionPopoverItem] = []
        if !cameraGranted {
            items.append(
                VideoPermissionPopoverItem(
                    message: "Hey, we need camera permission.",
                    buttonLabel: "Open Camera Settings",
                    settingsPane: "Privacy_Camera"
                )
            )
        }
        if !microphoneGranted {
            items.append(
                VideoPermissionPopoverItem(
                    message: "Hey, we need microphone permission.",
                    buttonLabel: "Open Microphone Settings",
                    settingsPane: "Privacy_Microphone"
                )
            )
        }
        if !speechGranted {
            items.append(
                VideoPermissionPopoverItem(
                    message: "Hey, we need speech recognition permission.",
                    buttonLabel: "Open Speech Settings",
                    settingsPane: "Privacy_SpeechRecognition"
                )
            )
        }

        if items.isEmpty {
            return (
                items: [],
                fallbackMessage: "Could not prepare camera right now. Please try again."
            )
        }

        return (
            items: items,
            fallbackMessage: nil
        )
    }

    private func openVideoPermissionSettings(_ settingsPane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(settingsPane)") {
            NSWorkspace.shared.open(url)
        }
    }

    var timerButtonTitle: String {
        if !timerIsRunning && timeRemaining == 900 {
            return "15:00"
        }
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var timerColor: Color {
        if timerIsRunning {
            return isHoveringTimer ? (colorScheme == .light ? .black : .white) : .gray.opacity(0.8)
        } else {
            return isHoveringTimer ? (colorScheme == .light ? .black : .white) : (colorScheme == .light ? .gray : .gray.opacity(0.8))
        }
    }

    private var activeAIChatPrompt: String {
        founderAIChatPrompt
    }

    private var activeClaudePrompt: String {
        founderClaudePrompt
    }

    private func refreshPlaceholder() {
        placeholderText = founderPlaceholderOptions.randomElement() ?? "What customer signal keeps bothering you"
    }
    
    var lineHeight: CGFloat {
        let font = NSFont(name: selectedFont, size: fontSize) ?? .systemFont(ofSize: fontSize)
        let defaultLineHeight = getLineHeight(font: font)
        return max(0, (fontSize * 1.42) - defaultLineHeight)
    }

    var writingColumnWidth: CGFloat {
        min(720, max(560, fontSize * 36))
    }

    var editorBackgroundColor: Color {
        colorScheme == .light
            ? Color(red: 0.985, green: 0.982, blue: 0.965)
            : Color(red: 0.045, green: 0.047, blue: 0.050)
    }

    var editorTextColor: Color {
        colorScheme == .light
            ? Color(red: 0.18, green: 0.18, blue: 0.17)
            : Color(red: 0.88, green: 0.87, blue: 0.84)
    }

    static func resolveFontName(_ candidates: [String]) -> String {
        candidates.first { NSFont(name: $0, size: 18) != nil } ?? ".AppleSystemUIFont"
    }

    private func selectWritingFont(at index: Int) {
        let clampedIndex = index % ContentView.writingFontPresets.count
        selectedFontPresetIndex = clampedIndex
        selectedFont = ContentView.resolveFontName(ContentView.writingFontPresets[clampedIndex].candidates)
    }

    private func toggleWritingFont() {
        let currentFont = selectedFont
        for offset in 1...ContentView.writingFontPresets.count {
            let nextIndex = (selectedFontPresetIndex + offset) % ContentView.writingFontPresets.count
            let nextFont = ContentView.resolveFontName(ContentView.writingFontPresets[nextIndex].candidates)
            selectedFontPresetIndex = nextIndex
            selectedFont = nextFont

            if nextFont != currentFont || offset == ContentView.writingFontPresets.count {
                break
            }
        }
    }

    private func founderToolSummary(for sourceText: String) -> String {
        let cleaned = sourceText
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else {
            return "No founder signal yet. Write for a few minutes, then come back."
        }

        let separators = CharacterSet(charactersIn: ".!?")
        let sentences = cleaned
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let keywordSentence = sentences.first { sentence in
            let lowercased = sentence.lowercased()
            return ["customer", "user", "problem", "pain", "manual", "assumption", "market", "wedge", "experiment"].contains { lowercased.contains($0) }
        }

        return keywordSentence ?? sentences.first ?? String(cleaned.prefix(220))
    }

    private func founderToolMarkdown(for tool: FounderTool, sourceText: String) -> String {
        let trimmed = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let signal = founderToolSummary(for: trimmed)
        let hasSource = !trimmed.isEmpty

        switch tool {
        case .explore:
            return """
            # Founder Explore

            ## Raw Signal
            \(signal)

            ## Customer Pain
            - What concrete struggle, workaround, delay, cost, or frustration is visible here?

            ## Founder Hypothesis
            - I believe this matters because:
            - I believe the first customer is:
            - I believe the current workaround is:

            ## Riskiest Assumption
            - The idea breaks if:

            ## Next 48-Hour Test
            - Talk to:
            - Ask:
            - Evidence that would change my mind:
            """

        case .assumptions:
            return """
            # Assumption Ledger

            | Assumption | Evidence Today | Confidence | Next Test | Status |
            | --- | --- | --- | --- | --- |
            | Customer has this problem often | \(hasSource ? signal : "No evidence yet") | Low | Ask 5 target customers for a recent story | Untested |
            | Current workaround is painful enough to switch |  | Low | Capture workaround, cost, and urgency | Untested |
            | This wedge is narrow enough to win early users |  | Low | Define one ICP and one painful use case | Untested |
            | A small MVP can prove value quickly |  | Low | Build or fake the smallest proof | Untested |
            """

        case .customerStory:
            return """
            # Customer Story Capture

            ## Interview Prompt
            Tell me about the last time you dealt with this problem.

            ## Capture
            - Customer:
            - Segment / role:
            - Situation:
            - Trigger:
            - Current workaround:
            - Pain / cost:
            - Quote:
            - Urgency signal:

            ## From This Freewrite
            \(signal)
            """

        case .opportunityMap:
            return """
            # Opportunity Map

            ## Outcome
            - The business/customer outcome I want to move:

            ## Opportunity Space
            - Need / pain / desire: \(signal)
            - Related customer moment:
            - Segment affected:

            ## Possible Solutions
            - Solution 1:
            - Solution 2:
            - Solution 3:

            ## Assumption Tests
            - Test the customer pain:
            - Test willingness to switch/pay:
            - Test MVP usefulness:
            """

        case .pmfSignal:
            return """
            # PMF Signal

            ## Sean Ellis / Superhuman Question
            How would you feel if you could no longer use this product?
            - Very disappointed
            - Somewhat disappointed
            - Not disappointed

            ## Follow-Ups
            - What type of person would most benefit?
            - What is the main benefit you receive?
            - How can we improve it for you?

            ## From This Freewrite
            - Likely champion segment:
            - Loved benefit:
            - Blocker:
            - Weekly PMF score:
            """

        case .memo:
            return """
            # Founder Memo

            ## Thesis
            \(signal)

            ## Customer
            - Who:
            - Moment:
            - Pain:

            ## Why Now
            -

            ## Wedge
            -

            ## Evidence
            - From freewrite: \(hasSource ? signal : "No evidence yet")
            - From customers:

            ## Next Decision
            -
            """
        }
    }

    private func founderToolDescription(for tool: FounderTool) -> String {
        switch tool {
        case .explore:
            return "Turn raw founder notes into pain, hypothesis, risk, and a 48-hour test."
        case .assumptions:
            return "Convert uncertainty into a visible ledger of evidence, confidence, and tests."
        case .customerStory:
            return "Prepare a customer interview capture sheet from the signal you already wrote."
        case .opportunityMap:
            return "Map outcome, opportunity space, solution options, and assumption tests."
        case .pmfSignal:
            return "Frame product-market-fit survey prompts and weekly signal tracking."
        case .memo:
            return "Shape the raw thought into a concise founder memo for decisions."
        }
    }

    private func founderToolSourceTitle() -> String {
        if currentVideoURL != nil {
            return selectedVideoHasTranscript ? "Video transcript" : "Video selected"
        }
        return "Current entry"
    }

    private func founderToolSourceStatus(for sourceText: String) -> String {
        let characterCount = sourceText.trimmingCharacters(in: .whitespacesAndNewlines).count
        guard characterCount > 0 else {
            return currentVideoURL != nil ? "No transcript found. Blank template." : "No writing yet. Blank template."
        }
        return "\(characterCount) characters loaded"
    }

    private func founderToolPrompt(for tool: FounderTool, sourceText: String) -> String {
        let source = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let draft = founderToolMarkdown(for: tool, sourceText: source)
        return """
        You are a practical founder research partner. Use the source notes below to produce a sharper \(tool.rawValue) artifact in concise markdown.

        Rules:
        - Keep the useful weirdness from the raw notes.
        - Separate evidence from assumptions.
        - Make the next action small enough to do in 48 hours.
        - Do not invent customer facts that are not in the source.

        Current local draft:
        \(draft)

        Source notes:
        \(source.isEmpty ? "No source notes yet. Return a clean blank template." : source)
        """
    }

    private func copyFounderToolPrompt() {
        let prompt = founderToolPrompt(for: selectedFounderTool, sourceText: currentChatSourceText())
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(prompt, forType: .string)
        didCopyFounderTool = true
    }

    private func openFounderToolPromptInChatGPT() {
        openFounderToolPrompt(baseURL: "https://chat.openai.com/?prompt=")
    }

    private func openFounderToolPromptInClaude() {
        openFounderToolPrompt(baseURL: "https://claude.ai/new?q=")
    }

    private func openFounderToolPrompt(baseURL: String) {
        let prompt = founderToolPrompt(for: selectedFounderTool, sourceText: currentChatSourceText())
        guard let encodedPrompt = prompt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        let fullURLString = baseURL + encodedPrompt
        if fullURLString.count > 6000 {
            copyFounderToolPrompt()
            return
        }
        if let url = URL(string: fullURLString) {
            showingFounderTools = false
            NSWorkspace.shared.open(url)
        }
    }

    private func copyFounderToolOutput() {
        let output = founderToolMarkdown(for: selectedFounderTool, sourceText: currentChatSourceText())
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(output, forType: .string)
        didCopyFounderTool = true
    }

    private func saveFounderToolOutputAsEntry() {
        let newEntry = HumanEntry.createNew()
        let output = founderToolMarkdown(for: selectedFounderTool, sourceText: currentChatSourceText())
        entries.insert(newEntry, at: 0)
        selectedEntryId = newEntry.id
        currentVideoURL = nil
        selectedVideoHasTranscript = false
        didCopyTranscript = false
        text = output
        saveEntry(entry: newEntry)
        updatePreviewText(for: newEntry)
        showingFounderTools = false
    }
    
    var fontSizeButtonTitle: String {
        return "\(Int(fontSize))px"
    }
    
    // Add a color utility computed property
    var popoverBackgroundColor: Color {
        return colorScheme == .light ? Color(NSColor.controlBackgroundColor) : Color(NSColor.darkGray)
    }
    
    var popoverTextColor: Color {
        return colorScheme == .light ? Color.primary : Color.white
    }

    private func sidebarRowFill(for entry: HumanEntry) -> Color {
        if selectedEntryId == entry.id {
            return colorScheme == .light ? Color.white.opacity(0.14) : Color.white.opacity(0.08)
        }
        if hoveredEntryId == entry.id {
            return colorScheme == .light ? Color.white.opacity(0.08) : Color.white.opacity(0.04)
        }
        return Color.clear
    }

    private func selectHistoryEntry(_ entry: HumanEntry) {
        guard selectedEntryId != entry.id else { return }
        historyDebug("ROW TAP \(debugEntrySummary(entry))")

        if let currentId = selectedEntryId,
           let currentEntry = entries.first(where: { $0.id == currentId }),
           currentEntry.entryType == .text {
            saveEntry(entry: currentEntry)
        }

        guard let targetEntry = entries.first(where: { $0.id == entry.id }) else {
            historyDebug("ROW TAP target missing id=\(entry.id.uuidString)")
            return
        }

        selectedEntryId = targetEntry.id
        historyDebug("ROW TAP resolved target \(debugEntrySummary(targetEntry))")
        loadEntry(entry: targetEntry)
    }

    
    var body: some View {
        let navHeight: CGFloat = 68
        let textColor = colorScheme == .light ? Color.gray : Color.gray.opacity(0.8)
        let textHoverColor = colorScheme == .light ? Color.black : Color.white
        let isViewingVideoEntry = currentVideoURL != nil
        
        HStack(spacing: 0) {
            // Main content
            ZStack {
                editorBackgroundColor
                    .ignoresSafeArea()

                // Show video player if a video entry is selected
                if let videoURL = currentVideoURL {
                    VideoPlayerView(
                        videoURL: videoURL,
                        isPlaybackSuspended: isPreparingVideoRecording || showingVideoRecording
                    )
                        .id(videoURL.path)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea(edges: .top)
                } else {
                    // Show text editor for text entries
                    TextEditor(text: $text)
                    .background(editorBackgroundColor)
                    .font(.custom(selectedFont, size: fontSize))
                    .foregroundColor(editorTextColor)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.never)
                    .lineSpacing(lineHeight)
                    .frame(maxWidth: writingColumnWidth)
                    .padding(.horizontal, editorHorizontalPadding)
                    .padding(.top, 40)
                    .id("\(selectedFont)-\(fontSize)-\(colorScheme)")
                    .padding(.bottom, bottomNavOpacity > 0 ? navHeight : 0)
                    .colorScheme(colorScheme)
                    .onAppear {
                        refreshPlaceholder()
                    }
                    .overlay(
                        ZStack(alignment: .topLeading) {
                            if text.isEmpty {
                                Text(placeholderText)
                                    .font(.custom(selectedFont, size: fontSize))
                                    .foregroundColor(editorTextColor.opacity(0.38))
                                    .allowsHitTesting(false)
                                    .offset(x: editorHorizontalPadding + 5, y: 40)
                            }
                        }, alignment: .topLeading
                    )
                }
                    
                
                VStack {
                    Spacer()
                    FreewriteGlassContainer(spacing: 12) {
                        HStack {
                            if isViewingVideoEntry {
                            HStack(spacing: 8) {
                                if selectedVideoHasTranscript {
                                    Button(action: {
                                        copyTranscriptForSelectedVideoEntry()
                                    }) {
                                        Text(didCopyTranscript ? "Copied Transcript" : "Copy Transcript")
                                            .font(.system(size: 13))
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundColor(isHoveringCopyTranscript ? textHoverColor : textColor)
                                    .onHover { hovering in
                                        isHoveringCopyTranscript = hovering
                                        isHoveringBottomNav = hovering
                                        if hovering {
                                            NSCursor.pointingHand.push()
                                        } else {
                                            NSCursor.pop()
                                        }
                                    }
                                }
                            }
                            .padding(8)
                            .freewriteGlassPanel(cornerRadius: 12, interactive: true)
                            .onHover { hovering in
                                isHoveringBottomNav = hovering
                            }
                        } else {
                            // Font buttons (left)
                            HStack(spacing: 8) {
                                Button(fontSizeButtonTitle) {
                                    if let currentIndex = fontSizes.firstIndex(of: fontSize) {
                                        let nextIndex = (currentIndex + 1) % fontSizes.count
                                        fontSize = fontSizes[nextIndex]
                                    }
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(isHoveringSize ? textHoverColor : textColor)
                                .onHover { hovering in
                                    isHoveringSize = hovering
                                    isHoveringBottomNav = hovering
                                    if hovering {
                                        NSCursor.pointingHand.push()
                                    } else {
                                        NSCursor.pop()
                                    }
                                }
                                
                                Text("•")
                                    .foregroundColor(.gray)
                                
                                Button("Toggle Font") {
                                    toggleWritingFont()
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(hoveredFont == "Toggle Font" ? textHoverColor : textColor)
                                .onHover { hovering in
                                    hoveredFont = hovering ? "Toggle Font" : nil
                                    isHoveringBottomNav = hovering
                                    if hovering {
                                        NSCursor.pointingHand.push()
                                    } else {
                                        NSCursor.pop()
                                    }
                                }
                            }
                            .padding(8)
                            .freewriteGlassPanel(cornerRadius: 12, interactive: true)
                            .onHover { hovering in
                                isHoveringBottomNav = hovering
                            }
                        }
                        
                        Spacer()
                        
                        // Utility buttons (moved to right)
                        HStack(spacing: 8) {
                            Button(timerButtonTitle) {
                                let now = Date()
                                if let lastClick = lastClickTime,
                                   now.timeIntervalSince(lastClick) < 0.3 {
                                    timeRemaining = 900
                                    timerIsRunning = false
                                    lastClickTime = nil
                                } else {
                                    timerIsRunning.toggle()
                                    lastClickTime = now
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(timerColor)
                            .onHover { hovering in
                                isHoveringTimer = hovering
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            .onAppear {
                                NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                                    if isHoveringTimer {
                                        let scrollBuffer = event.deltaY * 0.25
                                        
                                        if abs(scrollBuffer) >= 0.1 {
                                            let currentMinutes = timeRemaining / 60
                                            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                                            let direction = -scrollBuffer > 0 ? 5 : -5
                                            let newMinutes = currentMinutes + direction
                                            let roundedMinutes = (newMinutes / 5) * 5
                                            let newTime = roundedMinutes * 60
                                            timeRemaining = min(max(newTime, 0), 2700)
                                        }
                                    }
                                    return event
                                }
                            }

                            Text("•")
                                .foregroundColor(.gray)

                            // Video camera button
                            Button(action: {
                                guard !isPreparingVideoRecording else { return }
                                startVideoRecordingPreflight()
                            }) {
                                Group {
                                    if isPreparingVideoRecording {
                                        ProgressView()
                                            .controlSize(.small)
                                            .tint(isHoveringVideoButton ? textHoverColor : textColor)
                                    } else {
                                        Image(systemName: "video.fill")
                                            .foregroundColor(isHoveringVideoButton ? textHoverColor : textColor)
                                    }
                                }
                                .frame(width: 14, height: 14)
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                isHoveringVideoButton = hovering
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            .popover(
                                isPresented: $showingVideoPermissionPopover,
                                attachmentAnchor: .point(UnitPoint(x: 0.5, y: 0.0)),
                                arrowEdge: .top
                            ) {
                                VStack(spacing: 0) {
                                    if let fallbackMessage = videoPermissionPopoverFallbackMessage {
                                        Text(fallbackMessage)
                                            .font(.system(size: 14))
                                            .foregroundColor(popoverTextColor)
                                            .lineLimit(nil)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                }

                                    ForEach(videoPermissionPopoverItems) { item in
                                        if item.id != videoPermissionPopoverItems.first?.id || videoPermissionPopoverFallbackMessage != nil {
                                            Divider()
                                        }

                                        Button(action: {
                                            showingVideoPermissionPopover = false
                                            openVideoPermissionSettings(item.settingsPane)
                                        }) {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(item.message)
                                                    .font(.system(size: 14))
                                                    .lineLimit(nil)
                                                    .multilineTextAlignment(.leading)
                                                    .fixedSize(horizontal: false, vertical: true)

                                                Text(item.buttonLabel)
                                                    .font(.system(size: 12))
                                                    .opacity(0.85)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(popoverTextColor)
                                        .onHover { hovering in
                                            if hovering {
                                                NSCursor.pointingHand.push()
                                            } else {
                                                NSCursor.pop()
                                            }
                                        }
                                    }
                                }
                                .frame(minWidth: 300, idealWidth: 320, maxWidth: 360)
                                .freewriteGlassPanel(cornerRadius: 12, interactive: true)
                            }

                            Text("•")
                                .foregroundColor(.gray)

                            Button("Explore") {
                                showingFounderTools = true
                                didCopyFounderTool = false
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(isHoveringExplore ? textHoverColor : textColor)
                            .onHover { hovering in
                                isHoveringExplore = hovering
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            .popover(isPresented: $showingFounderTools, attachmentAnchor: .point(UnitPoint(x: 0.5, y: 0)), arrowEdge: .top) {
                                VStack(alignment: .leading, spacing: 0) {
                                    let sourceText = currentChatSourceText()
                                    let charCount = sourceText.trimmingCharacters(in: .whitespacesAndNewlines).count

                                    // Header
                                    HStack(alignment: .center, spacing: 8) {
                                        Text("Explore")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(popoverTextColor)
                                        Spacer()
                                        Text(charCount > 0 ? "\(charCount) chars" : "no text")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                        Button(action: { showingFounderTools = false }) {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 10, weight: .semibold))
                                                .frame(width: 20, height: 20)
                                                .foregroundColor(popoverTextColor.opacity(0.55))
                                                .background(Circle().fill(Color.white.opacity(0.07)))
                                        }
                                        .buttonStyle(.plain)
                                        .onHover { h in h ? NSCursor.pointingHand.push() : NSCursor.pop() }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.top, 13)
                                    .padding(.bottom, 12)

                                    // 3×2 artifact grid — scan, click, done
                                    LazyVGrid(
                                        columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                                        spacing: 8
                                    ) {
                                        ForEach(FounderTool.allCases) { tool in
                                            let isSelected = selectedFounderTool == tool
                                            Button(action: { selectedFounderTool = tool }) {
                                                VStack(spacing: 5) {
                                                    Image(systemName: tool.icon)
                                                        .font(.system(size: 15, weight: .medium))
                                                        .foregroundColor(isSelected ? .accentColor : popoverTextColor.opacity(0.68))
                                                    Text(tool.rawValue)
                                                        .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                                                        .foregroundColor(isSelected ? popoverTextColor : popoverTextColor.opacity(0.62))
                                                        .multilineTextAlignment(.center)
                                                        .lineLimit(2)
                                                        .fixedSize(horizontal: false, vertical: true)
                                                }
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 10)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .fill(isSelected
                                                            ? (colorScheme == .light ? Color.black.opacity(0.055) : Color.white.opacity(0.11))
                                                            : Color.clear)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(
                                                            isSelected
                                                                ? Color.white.opacity(colorScheme == .light ? 0.18 : 0.14)
                                                                : Color.clear,
                                                            lineWidth: 0.6
                                                        )
                                                )
                                            }
                                            .buttonStyle(.plain)
                                            .onHover { h in h ? NSCursor.pointingHand.push() : NSCursor.pop() }
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.bottom, 12)

                                    Rectangle()
                                        .fill(Color.white.opacity(colorScheme == .light ? 0.10 : 0.08))
                                        .frame(height: 0.6)

                                    // Provider row — equal-width, one click redirects with pre-built prompt
                                    HStack(spacing: 0) {
                                        Button(action: { openFounderToolPromptInChatGPT() }) {
                                            Text("ChatGPT")
                                                .font(.system(size: 12, weight: .medium))
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 13)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(popoverTextColor)
                                        .onHover { h in h ? NSCursor.pointingHand.push() : NSCursor.pop() }

                                        Rectangle()
                                            .fill(Color.white.opacity(colorScheme == .light ? 0.10 : 0.07))
                                            .frame(width: 0.6)

                                        Button(action: { openFounderToolPromptInClaude() }) {
                                            Text("Claude")
                                                .font(.system(size: 12, weight: .medium))
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 13)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(popoverTextColor)
                                        .onHover { h in h ? NSCursor.pointingHand.push() : NSCursor.pop() }

                                        Rectangle()
                                            .fill(Color.white.opacity(colorScheme == .light ? 0.10 : 0.07))
                                            .frame(width: 0.6)

                                        Button(action: { openFounderToolPromptInGemini() }) {
                                            VStack(spacing: 2) {
                                                Text("Gemini")
                                                    .font(.system(size: 12, weight: .medium))
                                                Text("paste")
                                                    .font(.system(size: 9))
                                                    .foregroundColor(.secondary)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 9)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(popoverTextColor)
                                        .onHover { h in h ? NSCursor.pointingHand.push() : NSCursor.pop() }
                                    }

                                    Rectangle()
                                        .fill(Color.white.opacity(colorScheme == .light ? 0.10 : 0.08))
                                        .frame(height: 0.6)

                                    // Copy fallback for entries that exceed URL limits
                                    Button(action: { copyFounderToolPrompt() }) {
                                        Text(didCopyFounderTool ? "Prompt copied" : "Copy prompt")
                                            .font(.system(size: 11))
                                            .foregroundColor(didCopyFounderTool ? .secondary : popoverTextColor.opacity(0.50))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .onHover { h in h ? NSCursor.pointingHand.push() : NSCursor.pop() }
                                }
                                .frame(width: 360)
                                .freewriteGlassPanel(cornerRadius: 16)
                                .shadow(color: Color.black.opacity(0.12), radius: 6, y: 3)
                                .onChange(of: selectedFounderTool) { _, _ in
                                    didCopyFounderTool = false
                                }
                                .onChange(of: showingFounderTools) { _, newValue in
                                    if !newValue { didCopyFounderTool = false }
                                }
                            }

                            Text("•")
                                .foregroundColor(.gray)

                            Button(isFullscreen ? "Minimize" : "Fullscreen") {
                                if let window = NSApplication.shared.windows.first {
                                    window.toggleFullScreen(nil)
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(isHoveringFullscreen ? textHoverColor : textColor)
                            .onHover { hovering in
                                isHoveringFullscreen = hovering
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            
                            Text("•")
                                .foregroundColor(.gray)
                            
                            Button(action: {
                                createNewEntry()
                            }) {
                                Text("New Entry")
                                    .font(.system(size: 13))
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(isHoveringNewEntry ? textHoverColor : textColor)
                            .onHover { hovering in
                                isHoveringNewEntry = hovering
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            
                            Text("•")
                                .foregroundColor(.gray)
                            
                            // Theme toggle button
                            Button(action: {
                                colorScheme = colorScheme == .light ? .dark : .light
                                // Save preference
                                UserDefaults.standard.set(colorScheme == .light ? "light" : "dark", forKey: "colorScheme")
                            }) {
                                Image(systemName: colorScheme == .light ? "moon.fill" : "sun.max.fill")
                                    .foregroundColor(isHoveringThemeToggle ? textHoverColor : textColor)
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                isHoveringThemeToggle = hovering
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }

                            Text("•")
                                .foregroundColor(.gray)

                            // Version history button
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showingSidebar.toggle()
                                }
                            }) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(isHoveringClock ? textHoverColor : textColor)
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                isHoveringClock = hovering
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                        }
                        .padding(8)
                        .freewriteGlassPanel(cornerRadius: 12, interactive: true)
                        .onHover { hovering in
                            isHoveringBottomNav = hovering
                        }
                    }
                    }
                    .padding()
                    .freewriteGlassPanel(cornerRadius: 24)
                    .opacity(bottomNavOpacity)
                    .onHover { hovering in
                        isHoveringBottomNav = hovering
                        if hovering {
                            withAnimation(.easeOut(duration: 0.2)) {
                                bottomNavOpacity = 1.0
                            }
                        } else if timerIsRunning {
                            withAnimation(.easeIn(duration: 1.0)) {
                                bottomNavOpacity = 0.0
                            }
                        }
                    }
                }
            }
            
            // Right sidebar
            if showingSidebar {
                Divider()
                
                ZStack {
                    Rectangle()
                        .fill(Color.clear)
                        .freewriteGlassBand()

                    VStack(spacing: 0) {
                        // Header
                        HStack(alignment: .center, spacing: 8) {
                            Text("History")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(colorScheme == .light ? Color.black.opacity(0.82) : Color.white.opacity(0.90))

                            Text("\(entries.count)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            Spacer()

                            Button(action: {
                                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: getDocumentsDirectory().path)
                            }) {
                                Image(systemName: "folder")
                                    .font(.system(size: 12))
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(isHoveringHistory ? textHoverColor : textColor.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                            .help("Open folder")
                            .onHover { hovering in
                                isHoveringHistory = hovering
                                hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                            }

                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showingSidebar = false
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .semibold))
                                    .frame(width: 20, height: 20)
                                    .foregroundColor(textColor.opacity(0.55))
                                    .background(Circle().fill(Color.white.opacity(0.07)))
                            }
                            .buttonStyle(.plain)
                            .help("Close")
                            .onHover { hovering in
                                hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 13)
                        .padding(.bottom, 11)

                        Rectangle()
                            .fill(Color.white.opacity(colorScheme == .light ? 0.10 : 0.08))
                            .frame(height: 0.6)
                        
                        // Entries List
                        ScrollView {
                            LazyVStack(spacing: 6) {
                                ForEach(entries) { entry in
                                    let rowTitle = entry.previewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled entry" : entry.previewText
                                    let isSelected = selectedEntryId == entry.id

                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(sidebarRowFill(for: entry))

                                        if isSelected {
                                            Capsule()
                                                .fill(Color.accentColor.opacity(0.8))
                                                .frame(width: 3)
                                                .padding(.vertical, 8)
                                                .padding(.leading, 4)
                                        }

                                        HStack(alignment: .center, spacing: 10) {
                                            // Thumbnail only for video entries with real thumbnails
                                            if entry.entryType == .video,
                                               let videoFilename = resolvedVideoFilename(for: entry),
                                               let thumbnail = loadThumbnailImage(for: videoFilename) {
                                                Image(nsImage: thumbnail)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 34, height: 34)
                                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                                    .overlay(
                                                        Image(systemName: "play.circle.fill")
                                                            .foregroundColor(.white.opacity(0.9))
                                                            .font(.system(size: 13))
                                                    )
                                            }

                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(rowTitle)
                                                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                                                    .lineLimit(1)
                                                    .foregroundColor(colorScheme == .light ? Color.black.opacity(0.82) : Color.white.opacity(0.88))

                                                HStack(spacing: 5) {
                                                    Text(entry.date)
                                                        .font(.system(size: 10))
                                                        .foregroundColor(.secondary)

                                                    if entry.entryType == .video {
                                                        Text("video")
                                                            .font(.system(size: 9, weight: .medium))
                                                            .foregroundColor(.secondary.opacity(0.8))
                                                            .padding(.horizontal, 4)
                                                            .padding(.vertical, 1)
                                                            .background(
                                                                Capsule()
                                                                    .fill(colorScheme == .light ? Color.black.opacity(0.05) : Color.white.opacity(0.06))
                                                            )
                                                    }
                                                }
                                            }

                                            Spacer(minLength: 0)

                                            if hoveredEntryId == entry.id {
                                                HStack(spacing: 6) {
                                                    Button(action: { exportEntryAsPDF(entry: entry) }) {
                                                        Image(systemName: "arrow.down.circle")
                                                            .font(.system(size: 11))
                                                            .foregroundColor(hoveredExportId == entry.id ? textHoverColor : textColor.opacity(0.6))
                                                    }
                                                    .buttonStyle(.plain)
                                                    .help("Export as PDF")
                                                    .onHover { hovering in
                                                        withAnimation(.easeInOut(duration: 0.15)) {
                                                            hoveredExportId = hovering ? entry.id : nil
                                                        }
                                                        hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                                                    }

                                                    Button(action: { deleteEntry(entry: entry) }) {
                                                        Image(systemName: "trash")
                                                            .font(.system(size: 11))
                                                            .foregroundColor(hoveredTrashId == entry.id ? .red : textColor.opacity(0.6))
                                                    }
                                                    .buttonStyle(.plain)
                                                    .help("Delete entry")
                                                    .onHover { hovering in
                                                        withAnimation(.easeInOut(duration: 0.15)) {
                                                            hoveredTrashId = hovering ? entry.id : nil
                                                        }
                                                        hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                                                    }
                                                }
                                                .transition(.opacity)
                                            }
                                        }
                                        .padding(.leading, isSelected ? 13 : 10)
                                        .padding(.trailing, 10)
                                        .padding(.vertical, 8)
                                    }
                                    .contentShape(RoundedRectangle(cornerRadius: 10))
                                    .onTapGesture {
                                        selectHistoryEntry(entry)
                                    }
                                    .onHover { hovering in
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            hoveredEntryId = hovering ? entry.id : nil
                                        }
                                    }
                                    .onAppear {
                                        NSCursor.pop()
                                    }
                                    .help("Open this entry")
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                        }
                        .scrollIndicators(.never)
                    }
                }
                .frame(width: 280)
            }
        }
        .overlay {
            if showingVideoRecording {
                VideoRecordingView(
                    isPresented: $showingVideoRecording,
                    cameraManager: preparedCameraManager
                ) { videoURL, transcript in
                    // Save the video and create entry
                    saveVideoEntry(from: videoURL, transcript: transcript)
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        showingVideoRecording = false
                    }
                }
                .zIndex(10)
            }
        }
        .frame(minWidth: 1100, minHeight: 600)
        .animation(.easeInOut(duration: 0.2), value: showingSidebar)
        .preferredColorScheme(colorScheme)
        .onAppear {
            showingSidebar = false  // Hide sidebar by default
            loadExistingEntries()
        }
        .onChange(of: showingVideoRecording) { _, isShowing in
            if !isShowing {
                clearVideoRecordingPreparationState()
            }
        }
        .onChange(of: text) { _, _ in
            // Save current entry when text changes
            if let currentId = selectedEntryId,
               let currentEntry = entries.first(where: { $0.id == currentId }),
               currentEntry.entryType == .text {
                saveEntry(entry: currentEntry)
            }
        }
        .onReceive(timer) { _ in
            if timerIsRunning && timeRemaining > 0 {
                timeRemaining -= 1
            } else if timeRemaining == 0 {
                timerIsRunning = false
                if !isHoveringBottomNav {
                    withAnimation(.easeOut(duration: 1.0)) {
                        bottomNavOpacity = 1.0
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { _ in
            isFullscreen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification)) { _ in
            isFullscreen = false
        }
    }
    
    private func backgroundColor(for entry: HumanEntry) -> Color {
        if entry.id == selectedEntryId {
            return Color.gray.opacity(0.1)  // More subtle selection highlight
        } else if entry.id == hoveredEntryId {
            return Color.gray.opacity(0.05)  // Even more subtle hover state
        } else {
            return Color.clear
        }
    }
    
    private func updatePreviewText(for entry: HumanEntry) {
        if entry.entryType == .video {
            if let index = entries.firstIndex(where: { $0.id == entry.id }),
               let videoFilename = resolvedVideoFilename(for: entry) {
                entries[index].previewText = videoPreviewText(for: videoFilename)
            }
            return
        }

        let documentsDirectory = getDocumentsDirectory()
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)
        
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let preview = content
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let truncated = preview.isEmpty ? "" : (preview.count > 30 ? String(preview.prefix(30)) + "..." : preview)
            
            // Find and update the entry in the entries array
            if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                entries[index].previewText = truncated
            }
        } catch {
            print("Error updating preview text: \(error)")
        }
    }
    
    private func saveEntry(entry: HumanEntry) {
        guard entry.entryType == .text else {
            return
        }

        let documentsDirectory = getDocumentsDirectory()
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)
        
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Successfully saved entry: \(entry.filename)")
            updatePreviewText(for: entry)  // Update preview after saving
        } catch {
            print("Error saving entry: \(error)")
        }
    }
    
    private func loadEntry(entry: HumanEntry) {
        if let videoFilename = resolvedVideoFilename(for: entry) {
            // Load video entry
            let videoURL = getVideoURL(for: videoFilename)
            let thumbnailURL = getVideoThumbnailURL(for: videoFilename)
            let transcriptURL = getVideoTranscriptURL(for: videoFilename)
            historyDebug("LOAD VIDEO \(debugEntrySummary(entry)) resolvedVideoPath=\(videoURL.path) videoExists=\(fileManager.fileExists(atPath: videoURL.path)) thumbnailPath=\(thumbnailURL.path) thumbnailExists=\(fileManager.fileExists(atPath: thumbnailURL.path))")
            text = ""
            didCopyTranscript = false
            selectedVideoHasTranscript = fileManager.fileExists(atPath: transcriptURL.path)
            if fileManager.fileExists(atPath: videoURL.path) {
                currentVideoURL = videoURL
                print("Successfully loaded video entry: \(videoFilename)")
            } else {
                print("Video file missing for entry: \(videoFilename)")
            }
        } else {
            // Load text entry
            historyDebug("LOAD TEXT \(debugEntrySummary(entry))")
            currentVideoURL = nil
            selectedVideoHasTranscript = false
            didCopyTranscript = false
            let documentsDirectory = getDocumentsDirectory()
            let fileURL = documentsDirectory.appendingPathComponent(entry.filename)

            do {
                if fileManager.fileExists(atPath: fileURL.path) {
                    let rawText = try String(contentsOf: fileURL, encoding: .utf8)
                    // Strip legacy leading newlines from older entries
                    text = String(rawText.drop(while: { $0 == "\n" }))
                    print("Successfully loaded entry: \(entry.filename)")
                }
            } catch {
                print("Error loading entry: \(error)")
            }
        }
    }
    
    private func createNewEntry() {
        let newEntry = HumanEntry.createNew()
        entries.insert(newEntry, at: 0) // Add to the beginning
        selectedEntryId = newEntry.id
        currentVideoURL = nil
        selectedVideoHasTranscript = false
        didCopyTranscript = false
        historyDebug("NEW ENTRY created \(debugEntrySummary(newEntry))")
        logEntriesOrder("createNewEntry")

        // If this is the first entry (entries was empty before adding this one)
        if entries.count == 1 {
            // Read welcome message from default.md
            if let defaultMessageURL = Bundle.main.url(forResource: "default", withExtension: "md"),
               let defaultMessage = try? String(contentsOf: defaultMessageURL, encoding: .utf8) {
                text = defaultMessage
            }
            // Save the welcome message immediately
            saveEntry(entry: newEntry)
            // Update the preview text
            updatePreviewText(for: newEntry)
        } else {
            text = ""
            // Randomize placeholder text for new entry
            refreshPlaceholder()
            // Save the empty entry
            saveEntry(entry: newEntry)
        }
    }
    
    private func openChatGPT() {
        let fullText = activeAIChatPrompt + "\n\n" + currentChatSourceText()
        
        if let encodedText = fullText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://chat.openai.com/?prompt=" + encodedText) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openClaude() {
        let fullText = activeClaudePrompt + "\n\n" + currentChatSourceText()

        if let encodedText = fullText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://claude.ai/new?q=" + encodedText) {
            NSWorkspace.shared.open(url)
        }
    }

    private func openGemini() {
        copyPromptToClipboard()
        if let url = URL(string: "https://gemini.google.com/app") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openFounderToolPromptInGemini() {
        copyFounderToolPrompt()
        if let url = URL(string: "https://gemini.google.com/app") {
            showingFounderTools = false
            NSWorkspace.shared.open(url)
        }
    }

    @ViewBuilder
    private func exploreProviderButton(_ title: String, gemini: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                if gemini {
                    Text("paste")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.trailing, 4)
                }
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(popoverTextColor)
        .onHover { h in h ? NSCursor.pointingHand.push() : NSCursor.pop() }
    }

    @ViewBuilder
    private func chatProviderButton(_ title: String, gemini: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                if gemini {
                    Text("paste")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.trailing, 4)
                }
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(popoverTextColor)
        .onHover { h in h ? NSCursor.pointingHand.push() : NSCursor.pop() }
    }

    private func copyPromptToClipboard() {
        let fullText = activeAIChatPrompt + "\n\n" + currentChatSourceText()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(fullText, forType: .string)
        print("Prompt copied to clipboard")
    }

    private func currentChatSourceText() -> String {
        if currentVideoURL != nil,
           let selectedEntryId,
           let selectedEntry = entries.first(where: { $0.id == selectedEntryId }),
           let videoFilename = resolvedVideoFilename(for: selectedEntry),
           let transcript = loadTranscriptText(for: videoFilename) {
            return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveVideoEntry(from tempURL: URL, transcript: String?) {
        let replacementEntry = selectedEntryId
            .flatMap { id in entries.first(where: { $0.id == id }) }
            .flatMap { entry -> HumanEntry? in
                guard entry.entryType == .text else { return nil }
                guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                return entry
            }

        let videoEntry: HumanEntry
        if let replacementEntry {
            let videoFilename = replacementEntry.filename.replacingOccurrences(of: ".md", with: ".mov")
            videoEntry = HumanEntry(
                id: replacementEntry.id,
                date: replacementEntry.date,
                filename: replacementEntry.filename,
                previewText: previewTextFromTranscript(transcript),
                entryType: .video,
                videoFilename: videoFilename
            )
        } else {
            let newEntry = HumanEntry.createVideoEntry()
            videoEntry = HumanEntry(
                id: newEntry.id,
                date: newEntry.date,
                filename: newEntry.filename,
                previewText: previewTextFromTranscript(transcript),
                entryType: .video,
                videoFilename: newEntry.videoFilename
            )
        }

        // Get the documents directory
        let documentsDirectory = getDocumentsDirectory()

        // Save the video file
        if let videoFilename = videoEntry.videoFilename {
            do {
                let videoEntryDirectory = try ensureVideoEntryDirectoryExists(for: videoFilename)
                let videoDestURL = videoEntryDirectory.appendingPathComponent(videoFilename)
                let transcriptURL = videoEntryDirectory.appendingPathComponent("transcript.md")
                let cleanedTranscript = transcript?.trimmingCharacters(in: .whitespacesAndNewlines)

                // Copy the video file from temp location to documents directory
                if fileManager.fileExists(atPath: videoDestURL.path) {
                    try fileManager.removeItem(at: videoDestURL)
                }
                try fileManager.copyItem(at: tempURL, to: videoDestURL)
                print("Successfully saved video: \(videoFilename)")

                if let thumbnailImage = generateVideoThumbnail(from: videoDestURL) {
                    persistThumbnail(thumbnailImage, for: videoFilename)
                    print("Successfully saved thumbnail for video: \(videoFilename)")
                } else {
                    print("Could not generate thumbnail for video: \(videoFilename)")
                }

                // Create the metadata file
                let metadataURL = documentsDirectory.appendingPathComponent(videoEntry.filename)
                let metadataContent = "Video Entry"
                try metadataContent.write(to: metadataURL, atomically: true, encoding: .utf8)

                if let cleanedTranscript, !cleanedTranscript.isEmpty {
                    try cleanedTranscript.write(to: transcriptURL, atomically: true, encoding: .utf8)
                    print("Successfully saved transcript for video: \(videoFilename)")
                } else if fileManager.fileExists(atPath: transcriptURL.path) {
                    try fileManager.removeItem(at: transcriptURL)
                }

                let selectNewVideoEntry = {
                    if let existingIndex = self.entries.firstIndex(where: { $0.id == videoEntry.id }) {
                        self.entries[existingIndex] = videoEntry
                    } else {
                        self.entries.insert(videoEntry, at: 0)
                    }
                    self.entries.sort { self.isEntryNewer($0, than: $1) }
                    guard let insertedEntry = self.entries.first(where: { $0.id == videoEntry.id }) else {
                        print("Could not find saved video entry in entries array")
                        return
                    }
                    self.selectedEntryId = insertedEntry.id
                    self.currentVideoURL = videoDestURL
                    self.text = ""
                    self.didCopyTranscript = false
                    self.selectedVideoHasTranscript = (cleanedTranscript?.isEmpty == false)
                    print("Successfully loaded new video entry: \(videoFilename)")
                    self.historyDebug("VIDEO SAVE selected \(self.debugEntrySummary(insertedEntry)) videoPath=\(videoDestURL.path)")
                    self.logEntriesOrder("saveVideoEntry")
                }
                
                if Thread.isMainThread {
                    selectNewVideoEntry()
                } else {
                    DispatchQueue.main.async {
                        selectNewVideoEntry()
                    }
                }

                if replacementEntry != nil {
                    print("Successfully replaced empty text entry with video entry")
                } else {
                    print("Successfully created video entry")
                }
            } catch {
                print("Error saving video entry: \(error)")
            }
        }
    }

    private func deleteEntry(entry: HumanEntry) {
        // Delete the file from the filesystem
        let documentsDirectory = getDocumentsDirectory()
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)

        do {
            try fileManager.removeItem(at: fileURL)
            print("Successfully deleted file: \(entry.filename)")

            // If this is a video entry, also delete the video file
            if let videoFilename = resolvedVideoFilename(for: entry) {
                deleteVideoAssets(for: videoFilename)
                print("Successfully deleted video assets: \(videoFilename)")
            }

            // Remove the entry from the entries array
            if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                entries.remove(at: index)
                historyDebug("DELETE ENTRY removed \(debugEntrySummary(entry))")
                logEntriesOrder("deleteEntry")

                // If the deleted entry was selected, select the first entry or create a new one
                if selectedEntryId == entry.id {
                    if let firstEntry = entries.first {
                        selectedEntryId = firstEntry.id
                        loadEntry(entry: firstEntry)
                    } else {
                        createNewEntry()
                    }
                }
            }
        } catch {
            print("Error deleting file: \(error)")
        }
    }
    
    // Extract a title from entry content for PDF export
    private func extractTitleFromContent(_ content: String, date: String) -> String {
        // Clean up content by removing leading/trailing whitespace and newlines
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If content is empty, just use the date
        if trimmedContent.isEmpty {
            return "Entry \(date)"
        }
        
        // Split content into words, ignoring newlines and removing punctuation
        let words = trimmedContent
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .map { word in
                word.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:\"'()[]{}<>"))
                    .lowercased()
            }
            .filter { !$0.isEmpty }
        
        // If we have at least 4 words, use them
        if words.count >= 4 {
            return "\(words[0])-\(words[1])-\(words[2])-\(words[3])"
        }
        
        // If we have fewer than 4 words, use what we have
        if !words.isEmpty {
            return words.joined(separator: "-")
        }
        
        // Fallback to date if no words found
        return "Entry \(date)"
    }
    
    private func exportEntryAsPDF(entry: HumanEntry) {
        // First make sure the current entry is saved
        if selectedEntryId == entry.id {
            saveEntry(entry: entry)
        }
        
        // Get entry content
        let documentsDirectory = getDocumentsDirectory()
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)
        
        do {
            // Read the content of the entry
            let entryContent = try String(contentsOf: fileURL, encoding: .utf8)
            
            // Extract a title from the entry content and add .pdf extension
            let suggestedFilename = extractTitleFromContent(entryContent, date: entry.date) + ".pdf"
            
            // Create save panel
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [UTType.pdf]
            savePanel.nameFieldStringValue = suggestedFilename
            savePanel.isExtensionHidden = false  // Make sure extension is visible
            
            // Show save dialog
            if savePanel.runModal() == .OK, let url = savePanel.url {
                // Create PDF data
                if let pdfData = createPDFFromText(text: entryContent) {
                    try pdfData.write(to: url)
                    print("Successfully exported PDF to: \(url.path)")
                }
            }
        } catch {
            print("Error in PDF export: \(error)")
        }
    }
    
    private func createPDFFromText(text: String) -> Data? {
        // Letter size page dimensions
        let pageWidth: CGFloat = 612.0  // 8.5 x 72
        let pageHeight: CGFloat = 792.0 // 11 x 72
        let margin: CGFloat = 72.0      // 1-inch margins
        
        // Calculate content area
        let contentRect = CGRect(
            x: margin,
            y: margin,
            width: pageWidth - (margin * 2),
            height: pageHeight - (margin * 2)
        )
        
        // Create PDF data container
        let pdfData = NSMutableData()
        
        // Configure text formatting attributes
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineHeight
        
        let font = NSFont(name: selectedFont, size: fontSize) ?? .systemFont(ofSize: fontSize)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1.0),
            .paragraphStyle: paragraphStyle
        ]
        
        // Trim the initial newlines before creating the PDF
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Create the attributed string with formatting
        let attributedString = NSAttributedString(string: trimmedText, attributes: textAttributes)
        
        // Create a Core Text framesetter for text layout
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        
        // Create a PDF context with the data consumer
        guard let pdfContext = CGContext(consumer: CGDataConsumer(data: pdfData as CFMutableData)!, mediaBox: nil, nil) else {
            print("Failed to create PDF context")
            return nil
        }
        
        // Track position within text
        var currentRange = CFRange(location: 0, length: 0)
        var pageIndex = 0
        
        // Create a path for the text frame
        let framePath = CGMutablePath()
        framePath.addRect(contentRect)
        
        // Continue creating pages until all text is processed
        while currentRange.location < attributedString.length {
            // Begin a new PDF page
            pdfContext.beginPage(mediaBox: nil)
            
            // Fill the page with white background
            pdfContext.setFillColor(NSColor.white.cgColor)
            pdfContext.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
            
            // Create a frame for this page's text
            let frame = CTFramesetterCreateFrame(
                framesetter, 
                currentRange, 
                framePath, 
                nil
            )
            
            // Draw the text frame
            CTFrameDraw(frame, pdfContext)
            
            // Get the range of text that was actually displayed in this frame
            let visibleRange = CTFrameGetVisibleStringRange(frame)
            
            // Move to the next block of text for the next page
            currentRange.location += visibleRange.length
            
            // Finish the page
            pdfContext.endPage()
            pageIndex += 1
            
            // Safety check - don't allow infinite loops
            if pageIndex > 1000 {
                print("Safety limit reached - stopping PDF generation")
                break
            }
        }
        
        // Finalize the PDF document
        pdfContext.closePDF()
        
        return pdfData as Data
    }
}

// Helper function to calculate line height
func getLineHeight(font: NSFont) -> CGFloat {
    return font.ascender - font.descender + font.leading
}

// Add helper extension to find NSTextView
extension NSView {
    func findTextView() -> NSView? {
        if self is NSTextView {
            return self
        }
        for subview in subviews {
            if let textView = subview.findTextView() {
                return textView
            }
        }
        return nil
    }
}

// Add helper extension for finding subviews of a specific type
extension NSView {
    func findSubview<T: NSView>(ofType type: T.Type) -> T? {
        if let typedSelf = self as? T {
            return typedSelf
        }
        for subview in subviews {
            if let found = subview.findSubview(ofType: type) {
                return found
            }
        }
        return nil
    }
}

#Preview {
    ContentView()
}
