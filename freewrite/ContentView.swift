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

struct HumanEntry: Identifiable, Equatable {
    let id: UUID
    let date: String
    let filename: String
    var previewText: String

    static func createNew() -> HumanEntry {
        let id = UUID()
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let dateString = dateFormatter.string(from: now)
        dateFormatter.dateFormat = "MMM d"
        let displayDate = dateFormatter.string(from: now)
        return HumanEntry(
            id: id,
            date: displayDate,
            filename: "[\(id)]-[\(dateString)].md",
            previewText: ""
        )
    }
}

struct ContentView: View {
    private struct WritingFontPreset {
        let label: String
        let candidates: [String]
    }

    // MARK: - State

    @State private var entries: [HumanEntry] = []
    @State private var text: String = ""
    @State private var isFullscreen = false
    @State private var selectedFontPresetIndex = 0
    @State private var selectedFont: String = ContentView.resolveFontName(["Georgia", "Iowan Old Style", "Times New Roman"])
    @State private var timeRemaining: Int = 900
    @State private var timerIsRunning = false
    @State private var isHoveringTimer = false
    @State private var isHoveringFullscreen = false
    @State private var hoveredFont: String? = nil
    @State private var isHoveringSize = false
    @State private var fontSize: CGFloat = 18
    @State private var lastClickTime: Date? = nil
    @State private var isHoveringBottomNav = false
    @State private var isNavCollapsed = false
    @State private var navCollapseTask: Task<Void, Never>? = nil
    @State private var selectedEntryId: UUID? = nil
    @State private var hoveredEntryId: UUID? = nil
    @State private var showingSidebar = false
    @State private var hoveredTrashId: UUID? = nil
    @State private var hoveredExportId: UUID? = nil
    @State private var placeholderText: String = ""
    @State private var isHoveringNewEntry = false
    @State private var isHoveringClock = false
    @State private var isHoveringHistory = false
    @State private var colorScheme: ColorScheme = .light
    @State private var isHoveringThemeToggle = false
    @State private var showingMCPSettings = false
    @StateObject private var mcpStore = MCPSettingsStore()
    @Namespace private var navGlassNS

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let editorHorizontalPadding: CGFloat = 56

    // MARK: - Constants

    private static let writingFontPresets: [WritingFontPreset] = [
        WritingFontPreset(label: "Serif",  candidates: ["Georgia", "Iowan Old Style", "Times New Roman"]),
        WritingFontPreset(label: "Iowan",  candidates: ["Iowan Old Style", "Athelas", "Hoefler Text", "Georgia"]),
        WritingFontPreset(label: "Avenir", candidates: ["Avenir Next", "Avenir", "Helvetica Neue", ".AppleSystemUIFont"]),
        WritingFontPreset(label: "Lato",   candidates: ["Lato-Regular", "Lato", "Helvetica Neue", ".AppleSystemUIFont"]),
        WritingFontPreset(label: "Mono",   candidates: ["Menlo", "Monaco", "Courier Prime", "Courier"])
    ]

    let fontSizes: [CGFloat] = [16, 18, 20, 22, 24, 26]

    private let founderPlaceholderOptions = [
        "What's on your mind right now",
        "What are you trying to figure out",
        "What happened today that felt significant",
        "What problem keeps coming back to you",
        "What do you want to remember from this week",
        "What are you feeling but haven't said out loud",
        "What idea has been sitting in the back of your mind",
        "What would you write if no one was reading",
        "What decision have you been putting off",
        "What do you notice about yourself lately"
    ]

    // MARK: - Storage

    private let fileManager = FileManager.default

    private let documentsDirectory: URL = {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Freewrite")
        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                print("Error creating Freewrite directory: \(error)")
            }
        }
        return directory
    }()

    init() {
        let savedScheme = UserDefaults.standard.string(forKey: "colorScheme") ?? "light"
        _colorScheme = State(initialValue: savedScheme == "dark" ? .dark : .light)
    }

    private func getDocumentsDirectory() -> URL { documentsDirectory }

    // MARK: - Computed properties

    var timerButtonTitle: String {
        if !timerIsRunning && timeRemaining == 900 { return "15:00" }
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

    var lineHeight: CGFloat {
        let font = NSFont(name: selectedFont, size: fontSize) ?? .systemFont(ofSize: fontSize)
        let defaultLineHeight = getLineHeight(font: font)
        return max(0, (fontSize * 1.42) - defaultLineHeight)
    }

    var writingColumnWidth: CGFloat { min(720, max(560, fontSize * 36)) }

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

    var fontSizeButtonTitle: String { "\(Int(fontSize))px" }

    var popoverTextColor: Color {
        colorScheme == .light ? Color.primary : Color.white
    }

    // MARK: - Static helpers

    static func resolveFontName(_ candidates: [String]) -> String {
        candidates.first { NSFont(name: $0, size: 18) != nil } ?? ".AppleSystemUIFont"
    }

    // MARK: - Font

    private func toggleWritingFont() {
        let currentFont = selectedFont
        for offset in 1...ContentView.writingFontPresets.count {
            let nextIndex = (selectedFontPresetIndex + offset) % ContentView.writingFontPresets.count
            let nextFont = ContentView.resolveFontName(ContentView.writingFontPresets[nextIndex].candidates)
            selectedFontPresetIndex = nextIndex
            selectedFont = nextFont
            if nextFont != currentFont || offset == ContentView.writingFontPresets.count { break }
        }
    }

    private func refreshPlaceholder() {
        placeholderText = founderPlaceholderOptions.randomElement() ?? "What's on your mind"
    }

    // MARK: - Nav collapse

    private func scheduleNavCollapse() {
        navCollapseTask?.cancel()
        navCollapseTask = Task { [self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.35)) { isNavCollapsed = true }
            }
        }
    }

    private func expandNav() {
        navCollapseTask?.cancel()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { isNavCollapsed = false }
        scheduleNavCollapse()
    }

    // MARK: - Filename parsing

    private func parseCanonicalEntryFilename(_ filename: String) -> (uuid: UUID, timestamp: Date)? {
        guard filename.hasPrefix("["), filename.hasSuffix("].md"),
              let divider = filename.range(of: "]-[") else { return nil }
        let uuidStart = filename.index(after: filename.startIndex)
        let uuidString = String(filename[uuidStart..<divider.lowerBound])
        guard let uuid = UUID(uuidString: uuidString) else { return nil }
        let timestampStart = divider.upperBound
        let timestampEnd = filename.index(filename.endIndex, offsetBy: -4)
        let timestampString = String(filename[timestampStart..<timestampEnd])
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        guard let timestamp = formatter.date(from: timestampString) else { return nil }
        return (uuid: uuid, timestamp: timestamp)
    }

    private func isEntryFromToday(_ entry: HumanEntry, calendar: Calendar = .current, today: Date = Date()) -> Bool {
        guard let timestamp = parseCanonicalEntryFilename(entry.filename)?.timestamp else { return false }
        return calendar.isDate(timestamp, inSameDayAs: today)
    }

    // MARK: - Sidebar helpers

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
        if let currentId = selectedEntryId,
           let currentEntry = entries.first(where: { $0.id == currentId }) {
            saveEntry(entry: currentEntry)
        }
        guard let targetEntry = entries.first(where: { $0.id == entry.id }) else { return }
        selectedEntryId = targetEntry.id
        loadEntry(entry: targetEntry)
    }

    @ViewBuilder
    private func sidebarEntryRowContent(
        entry: HumanEntry, rowTitle: String,
        isSelected: Bool, textColor: Color, textHoverColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(rowTitle)
                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                .lineLimit(1)
                .foregroundColor(colorScheme == .light ? Color.black.opacity(0.82) : Color.white.opacity(0.88))
            Text(entry.date)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
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
                    withAnimation(.easeInOut(duration: 0.15)) { hoveredExportId = hovering ? entry.id : nil }
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
                    withAnimation(.easeInOut(duration: 0.15)) { hoveredTrashId = hovering ? entry.id : nil }
                    hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                }
            }
            .transition(.opacity)
        }
    }

    // MARK: - CRUD

    private func loadExistingEntries() {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            let mdFiles = fileURLs.filter { $0.pathExtension == "md" }

            let entriesWithDates: [(entry: HumanEntry, date: Date, content: String)] = mdFiles.compactMap { fileURL in
                let filename = fileURL.lastPathComponent
                guard let parsed = parseCanonicalEntryFilename(filename) else { return nil }
                do {
                    let content = try String(contentsOf: fileURL, encoding: .utf8)
                    // Skip legacy video metadata entries (kept on disk, just hidden)
                    if content.trimmingCharacters(in: .whitespacesAndNewlines) == "Video Entry" { return nil }

                    let preview = content
                        .replacingOccurrences(of: "\n", with: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let truncated = preview.isEmpty ? "" : (preview.count > 30 ? String(preview.prefix(30)) + "..." : preview)

                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "MMM d"
                    let displayDate = dateFormatter.string(from: parsed.timestamp)

                    return (
                        entry: HumanEntry(id: parsed.uuid, date: displayDate, filename: filename, previewText: truncated),
                        date: parsed.timestamp,
                        content: content
                    )
                } catch {
                    return nil
                }
            }

            let loadedEntries = entriesWithDates
                .sorted { $0.date > $1.date }
                .map { $0.entry }

            let calendar = Calendar.current
            let today = Date()
            let hasEntryToday = loadedEntries.contains { isEntryFromToday($0, calendar: calendar, today: today) }
            let hasEmptyTextEntryToday = loadedEntries.contains {
                isEntryFromToday($0, calendar: calendar, today: today) && $0.previewText.isEmpty
            }
            let hasOnlyWelcomeEntry = loadedEntries.count == 1 &&
                entriesWithDates.first?.content.contains("Welcome to Freewrite.") == true

            entries = loadedEntries

            if entries.isEmpty {
                createNewEntry()
            } else if !hasEntryToday && !hasOnlyWelcomeEntry {
                createNewEntry()
            } else if hasEmptyTextEntryToday,
                      let todayEntry = entries.first(where: {
                          isEntryFromToday($0, calendar: calendar, today: today) && $0.previewText.isEmpty
                      }) {
                selectedEntryId = todayEntry.id
                loadEntry(entry: todayEntry)
            } else if hasOnlyWelcomeEntry {
                selectedEntryId = entries[0].id
                loadEntry(entry: entries[0])
            } else if let latestEntry = entries.first {
                selectedEntryId = latestEntry.id
                loadEntry(entry: latestEntry)
            }
        } catch {
            print("Error loading entries: \(error)")
            createNewEntry()
        }
    }

    private func createNewEntry() {
        let newEntry = HumanEntry.createNew()
        entries.insert(newEntry, at: 0)
        selectedEntryId = newEntry.id

        if entries.count == 1 {
            if let defaultMessageURL = Bundle.main.url(forResource: "default", withExtension: "md"),
               let defaultMessage = try? String(contentsOf: defaultMessageURL, encoding: .utf8) {
                text = defaultMessage
            }
            saveEntry(entry: newEntry)
            updatePreviewText(for: newEntry)
        } else {
            text = ""
            refreshPlaceholder()
            saveEntry(entry: newEntry)
        }
    }

    private func saveEntry(entry: HumanEntry) {
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            updatePreviewText(for: entry)
        } catch {
            print("Error saving entry: \(error)")
        }
    }

    private func loadEntry(entry: HumanEntry) {
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                let rawText = try String(contentsOf: fileURL, encoding: .utf8)
                text = String(rawText.drop(while: { $0 == "\n" }))
            }
        } catch {
            print("Error loading entry: \(error)")
        }
    }

    private func updatePreviewText(for entry: HumanEntry) {
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let preview = content
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let truncated = preview.isEmpty ? "" : (preview.count > 30 ? String(preview.prefix(30)) + "..." : preview)
            if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                entries[index].previewText = truncated
            }
        } catch { }
    }

    private func deleteEntry(entry: HumanEntry) {
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)
        do {
            try fileManager.removeItem(at: fileURL)
            if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                entries.remove(at: index)
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
            print("Error deleting entry: \(error)")
        }
    }

    // MARK: - PDF export

    private func extractTitleFromContent(_ content: String, date: String) -> String {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedContent.isEmpty { return "Entry \(date)" }
        let words = trimmedContent
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:\"'()[]{}<>")).lowercased() }
            .filter { !$0.isEmpty }
        if words.count >= 4 { return "\(words[0])-\(words[1])-\(words[2])-\(words[3])" }
        if !words.isEmpty { return words.joined(separator: "-") }
        return "Entry \(date)"
    }

    private func exportEntryAsPDF(entry: HumanEntry) {
        if selectedEntryId == entry.id { saveEntry(entry: entry) }
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)
        do {
            let entryContent = try String(contentsOf: fileURL, encoding: .utf8)
            let suggestedFilename = extractTitleFromContent(entryContent, date: entry.date) + ".pdf"
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [UTType.pdf]
            savePanel.nameFieldStringValue = suggestedFilename
            savePanel.isExtensionHidden = false
            if savePanel.runModal() == .OK, let url = savePanel.url {
                if let pdfData = createPDFFromText(text: entryContent) {
                    try pdfData.write(to: url)
                }
            }
        } catch {
            print("Error in PDF export: \(error)")
        }
    }

    private func createPDFFromText(text: String) -> Data? {
        let pageWidth: CGFloat = 612.0
        let pageHeight: CGFloat = 792.0
        let margin: CGFloat = 72.0
        let contentRect = CGRect(x: margin, y: margin, width: pageWidth - margin * 2, height: pageHeight - margin * 2)
        let pdfData = NSMutableData()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineHeight
        let font = NSFont(name: selectedFont, size: fontSize) ?? .systemFont(ofSize: fontSize)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1.0),
            .paragraphStyle: paragraphStyle
        ]
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let attributedString = NSAttributedString(string: trimmedText, attributes: textAttributes)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        guard let pdfContext = CGContext(consumer: CGDataConsumer(data: pdfData as CFMutableData)!, mediaBox: nil, nil) else { return nil }
        var currentRange = CFRange(location: 0, length: 0)
        var pageIndex = 0
        let framePath = CGMutablePath()
        framePath.addRect(contentRect)
        while currentRange.location < attributedString.length {
            pdfContext.beginPage(mediaBox: nil)
            pdfContext.setFillColor(NSColor.white.cgColor)
            pdfContext.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
            let frame = CTFramesetterCreateFrame(framesetter, currentRange, framePath, nil)
            CTFrameDraw(frame, pdfContext)
            let visibleRange = CTFrameGetVisibleStringRange(frame)
            currentRange.location += visibleRange.length
            pdfContext.endPage()
            pageIndex += 1
            if pageIndex > 1000 { break }
        }
        pdfContext.closePDF()
        return pdfData as Data
    }

    // MARK: - Body

    var body: some View {
        let navHeight: CGFloat = 68
        let textColor = colorScheme == .light ? Color.gray : Color.gray.opacity(0.8)
        let textHoverColor = colorScheme == .light ? Color.black : Color.white

        HStack(spacing: 0) {
            // Main writing area
            ZStack {
                editorBackgroundColor.ignoresSafeArea()

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
                    .padding(.bottom, isNavCollapsed ? 0 : navHeight)
                    .colorScheme(colorScheme)
                    .onAppear { refreshPlaceholder() }
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

                // Bottom nav
                ZStack(alignment: .bottomTrailing) {
                    VStack {
                        Spacer()
                        FreewriteGlassContainer(spacing: 12) {
                            HStack {
                                // Left — font controls
                                HStack(spacing: 8) {
                                    Button(fontSizeButtonTitle) {
                                        if let currentIndex = fontSizes.firstIndex(of: fontSize) {
                                            fontSize = fontSizes[(currentIndex + 1) % fontSizes.count]
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundColor(isHoveringSize ? textHoverColor : textColor)
                                    .onHover { hovering in
                                        isHoveringSize = hovering
                                        isHoveringBottomNav = hovering
                                        hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                                    }

                                    Text("•").foregroundColor(.gray)

                                    Button("Toggle Font") { toggleWritingFont() }
                                        .buttonStyle(.plain)
                                        .foregroundColor(hoveredFont == "Toggle Font" ? textHoverColor : textColor)
                                        .onHover { hovering in
                                            hoveredFont = hovering ? "Toggle Font" : nil
                                            isHoveringBottomNav = hovering
                                            hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                                        }
                                }
                                .padding(8)
                                .freewriteGlassPanel(cornerRadius: 12, interactive: true)
                                .freewriteGlassID("leftNav", in: navGlassNS)
                                .onHover { isHoveringBottomNav = $0 }

                                Spacer()

                                // Right — utility controls
                                HStack(spacing: 8) {
                                    // Timer
                                    Button(timerButtonTitle) {
                                        let now = Date()
                                        if let lastClick = lastClickTime, now.timeIntervalSince(lastClick) < 0.3 {
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
                                        hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
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
                                                    timeRemaining = min(max(roundedMinutes * 60, 0), 2700)
                                                }
                                            }
                                            return event
                                        }
                                    }

                                    Text("•").foregroundColor(.gray)

                                    // Fullscreen
                                    Button(isFullscreen ? "Minimize" : "Fullscreen") {
                                        NSApplication.shared.windows.first?.toggleFullScreen(nil)
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundColor(isHoveringFullscreen ? textHoverColor : textColor)
                                    .onHover { hovering in
                                        isHoveringFullscreen = hovering
                                        isHoveringBottomNav = hovering
                                        hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                                    }

                                    Text("•").foregroundColor(.gray)

                                    // New Entry
                                    Button("New Entry") { createNewEntry() }
                                        .buttonStyle(.plain)
                                        .foregroundColor(isHoveringNewEntry ? textHoverColor : textColor)
                                        .onHover { hovering in
                                            isHoveringNewEntry = hovering
                                            isHoveringBottomNav = hovering
                                            hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                                        }

                                    Text("•").foregroundColor(.gray)

                                    // Theme toggle
                                    Button(action: {
                                        colorScheme = colorScheme == .light ? .dark : .light
                                        UserDefaults.standard.set(colorScheme == .light ? "light" : "dark", forKey: "colorScheme")
                                    }) {
                                        Image(systemName: colorScheme == .light ? "moon.fill" : "sun.max.fill")
                                            .foregroundColor(isHoveringThemeToggle ? textHoverColor : textColor)
                                    }
                                    .buttonStyle(.plain)
                                    .onHover { hovering in
                                        isHoveringThemeToggle = hovering
                                        isHoveringBottomNav = hovering
                                        hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                                    }

                                    Text("•").foregroundColor(.gray)

                                    // History sidebar
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) { showingSidebar.toggle() }
                                    }) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .foregroundColor(isHoveringClock ? textHoverColor : textColor)
                                    }
                                    .buttonStyle(.plain)
                                    .onHover { hovering in
                                        isHoveringClock = hovering
                                        isHoveringBottomNav = hovering
                                        hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                                    }

                                    Text("•").foregroundColor(.gray)

                                    // MCP settings
                                    Button(action: { showingMCPSettings.toggle() }) {
                                        Image(systemName: "cpu")
                                            .foregroundColor(showingMCPSettings ? textHoverColor : textColor)
                                    }
                                    .buttonStyle(.plain)
                                    .onHover { hovering in
                                        isHoveringBottomNav = hovering
                                        hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                                    }
                                    .popover(
                                        isPresented: $showingMCPSettings,
                                        attachmentAnchor: .point(UnitPoint(x: 0.5, y: 0)),
                                        arrowEdge: .top
                                    ) {
                                        MCPConnectionView(onDismiss: { showingMCPSettings = false })
                                            .environmentObject(mcpStore)
                                    }
                                }
                                .padding(8)
                                .freewriteGlassPanel(cornerRadius: 12, interactive: true)
                                .freewriteGlassID("rightNav", in: navGlassNS)
                                .onHover { isHoveringBottomNav = $0 }
                            }
                        }
                        .padding()
                        .freewriteGlassPanel(cornerRadius: 24)
                        .freewriteGlassID("mainNav", in: navGlassNS)
                        .opacity(isNavCollapsed ? 0 : 1)
                        .allowsHitTesting(!isNavCollapsed)
                        .onHover { hovering in
                            isHoveringBottomNav = hovering
                            if hovering { navCollapseTask?.cancel() }
                            else { scheduleNavCollapse() }
                        }
                    }

                    // Hamburger — appears when nav is collapsed
                    if isNavCollapsed {
                        Button(action: { expandNav() }) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(textColor)
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.plain)
                        .freewriteGlassPanel(cornerRadius: 10, interactive: true)
                        .freewriteGlassID("hamburger", in: navGlassNS)
                        .padding(.bottom, 18)
                        .padding(.trailing, 18)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                        .onHover { h in h ? NSCursor.pointingHand.push() : NSCursor.pop() }
                    }
                }
            }

            // History sidebar
            if showingSidebar {
                Divider()

                ZStack {
                    Rectangle().fill(Color.clear).freewriteGlassBand()

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
                                    .foregroundColor(isHoveringHistory ? (colorScheme == .light ? .black : .white) : Color.gray.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                            .help("Open folder")
                            .onHover { hovering in
                                isHoveringHistory = hovering
                                hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                            }

                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) { showingSidebar = false }
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .semibold))
                                    .frame(width: 20, height: 20)
                                    .foregroundColor(Color.gray.opacity(0.55))
                                    .background(Circle().fill(Color.white.opacity(0.07)))
                            }
                            .buttonStyle(.plain)
                            .help("Close")
                            .onHover { hovering in hovering ? NSCursor.pointingHand.push() : NSCursor.pop() }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 13)
                        .padding(.bottom, 11)

                        Rectangle()
                            .fill(Color.white.opacity(colorScheme == .light ? 0.10 : 0.08))
                            .frame(height: 0.6)

                        // Entry list
                        ScrollView {
                            LazyVStack(spacing: 6) {
                                ForEach(entries) { entry in
                                    let rowTitle = entry.previewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        ? "Untitled entry" : entry.previewText
                                    let isSelected = selectedEntryId == entry.id

                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 8).fill(sidebarRowFill(for: entry))

                                        if isSelected {
                                            Capsule()
                                                .fill(Color.accentColor.opacity(0.8))
                                                .frame(width: 3)
                                                .padding(.vertical, 8)
                                                .padding(.leading, 4)
                                        }

                                        HStack(alignment: .center, spacing: 10) {
                                            sidebarEntryRowContent(
                                                entry: entry, rowTitle: rowTitle,
                                                isSelected: isSelected,
                                                textColor: colorScheme == .light ? .gray : .gray.opacity(0.8),
                                                textHoverColor: colorScheme == .light ? .black : .white
                                            )
                                        }
                                        .padding(.leading, isSelected ? 13 : 10)
                                        .padding(.trailing, 10)
                                        .padding(.vertical, 8)
                                    }
                                    .contentShape(RoundedRectangle(cornerRadius: 10))
                                    .onTapGesture { selectHistoryEntry(entry) }
                                    .onHover { hovering in
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            hoveredEntryId = hovering ? entry.id : nil
                                        }
                                    }
                                    .onAppear { NSCursor.pop() }
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
        .frame(minWidth: 1100, minHeight: 600)
        .animation(.easeInOut(duration: 0.2), value: showingSidebar)
        .preferredColorScheme(colorScheme)
        .onAppear {
            showingSidebar = false
            loadExistingEntries()
            scheduleNavCollapse()
        }
        .onChange(of: text) { _, _ in
            if let currentId = selectedEntryId,
               let currentEntry = entries.first(where: { $0.id == currentId }) {
                saveEntry(entry: currentEntry)
            }
            scheduleNavCollapse()
        }
        .onReceive(timer) { _ in
            if timerIsRunning && timeRemaining > 0 {
                timeRemaining -= 1
            } else if timeRemaining == 0 {
                timerIsRunning = false
                expandNav()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { _ in
            isFullscreen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification)) { _ in
            isFullscreen = false
        }
    }
}

// MARK: - Global helpers

func getLineHeight(font: NSFont) -> CGFloat {
    font.ascender - font.descender + font.leading
}

extension NSView {
    func findTextView() -> NSView? {
        if self is NSTextView { return self }
        for subview in subviews {
            if let textView = subview.findTextView() { return textView }
        }
        return nil
    }

    func findSubview<T: NSView>(ofType type: T.Type) -> T? {
        if let typedSelf = self as? T { return typedSelf }
        for subview in subviews {
            if let found = subview.findSubview(ofType: type) { return found }
        }
        return nil
    }
}

#Preview {
    ContentView()
}
