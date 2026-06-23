import Foundation
import MCP

// MARK: - Path helpers

let freewriteDir: URL = {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    return docs.appendingPathComponent("Freewrite")
}()

let appSupportDir: URL = {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    return base.appendingPathComponent("ThinkIN")
}()

func isSafe(_ url: URL) -> Bool {
    url.path.hasPrefix(freewriteDir.path)
}

// MARK: - Write-gate

func writeEnabled() -> Bool {
    let cfg = appSupportDir.appendingPathComponent("mcp-config.json")
    guard let data = try? Data(contentsOf: cfg),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let flag = json["writeEnabled"] as? Bool else { return false }
    return flag
}

// MARK: - Entry helpers

func loadEntries() -> [(filename: String, date: String, preview: String)] {
    guard let files = try? FileManager.default.contentsOfDirectory(
        at: freewriteDir, includingPropertiesForKeys: [.contentModificationDateKey],
        options: .skipsHiddenFiles
    ) else { return [] }

    let mdFiles = files.filter { $0.pathExtension == "md" }.sorted {
        let d1 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        let d2 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        return d1 > d2
    }

    return mdFiles.compactMap { url in
        let filename = url.lastPathComponent
        let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""

        // Skip legacy video metadata entries
        if content.trimmingCharacters(in: .whitespacesAndNewlines) == "Video Entry" { return nil }

        let preview = String(content.replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
        let dateStr: String
        if let range = filename.range(of: #"\[(\d{4}-\d{2}-\d{2})"#, options: .regularExpression) {
            dateStr = String(filename[range]).trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        } else {
            dateStr = ""
        }
        return (filename: filename, date: dateStr, preview: preview)
    }
}

// MARK: - Convenience

func callResult(_ text: String, isError: Bool = false) -> CallTool.Result {
    CallTool.Result(content: [.text(text: text, annotations: nil, _meta: nil)], isError: isError)
}

// MARK: - Thinking-mode prompt definitions

struct ThinkingPrompt {
    let name: String
    let description: String
    let title: String
    let text: String
}

let thinkingPrompts: [ThinkingPrompt] = [
    ThinkingPrompt(
        name: "journal_reflection",
        description: "Surface insights, patterns, and questions from a freewrite entry",
        title: "Journal Reflection",
        text: """
        Read the entry and help the writer reflect more deeply.

        - Surface 2–3 significant moments, emotions, or insights
        - Ask 1–2 questions that invite them to go deeper
        - Note any recurring patterns or themes

        Keep the tone warm and non-judgmental.
        """
    ),
    ThinkingPrompt(
        name: "idea_critique",
        description: "Evaluate an idea or concept from a freewrite entry",
        title: "Idea Critique",
        text: """
        Evaluate the concept explored in this entry.

        1. Core insight — what is the real problem being solved?
        2. Who feels this most acutely? Be specific.
        3. Biggest assumption that could kill this idea
        4. One 48-hour experiment to test that assumption
        5. Honest take: what is exciting, what is concerning?
        """
    ),
    ThinkingPrompt(
        name: "research_frame",
        description: "Organize raw thinking into a research structure",
        title: "Research Frame",
        text: """
        Help organize this raw thinking into a research structure.

        - Extract the core question or hypothesis
        - Identify gaps in the current thinking
        - Suggest 3–5 angles or sources not yet considered
        - Flag unverified assumptions
        - Propose a clear structure for going deeper
        """
    ),
    ThinkingPrompt(
        name: "peace_perspective",
        description: "Find calm and perspective on something weighing on the writer",
        title: "Peace Perspective",
        text: """
        Help find perspective and calm on what is weighing on the writer.

        - Acknowledge what is on their mind without judgment
        - Separate what they can control from what they cannot
        - Offer one grounding reframe or perspective shift
        - End with something affirming drawn from their own words
        """
    ),
    ThinkingPrompt(
        name: "decision_clarity",
        description: "Cut through noise and clarify the real decision at stake",
        title: "Decision Clarity",
        text: """
        Help clarify the real decision being faced.

        - Identify the actual decision (it may not be the stated one)
        - Name the values or constraints driving it
        - List the options and what each costs
        - Surface the fear or assumption blocking clarity
        - Ask one question that would resolve the ambiguity
        """
    ),
]

// MARK: - Server

let server = Server(
    name: "ThinkIN",
    version: "1.0.0",
    capabilities: .init(
        prompts: .init(listChanged: false),
        tools: .init(listChanged: false)
    )
)

// MARK: - Tools

await server.withMethodHandler(ListTools.self) { _ in
    let tools: [Tool] = [
        Tool(
            name: "list_entries",
            description: "List all Freewrite entries newest-first. Returns filename, date, and preview.",
            inputSchema: .object(["type": .string("object"), "properties": .object([:])])
        ),
        Tool(
            name: "search_entries",
            description: "Search Freewrite entries by keyword (case-insensitive substring match on content).",
            inputSchema: .object([
                "type": .string("object"),
                "required": .array([.string("query")]),
                "properties": .object([
                    "query": .object(["type": .string("string"), "description": .string("Search term")])
                ])
            ])
        ),
        Tool(
            name: "read_entry",
            description: "Read the full text of a Freewrite entry by filename.",
            inputSchema: .object([
                "type": .string("object"),
                "required": .array([.string("filename")]),
                "properties": .object([
                    "filename": .object(["type": .string("string"), "description": .string("Exact .md filename")])
                ])
            ])
        ),
        Tool(
            name: "append_to_entry",
            description: "Append text to an existing entry. Requires write access enabled in the app.",
            inputSchema: .object([
                "type": .string("object"),
                "required": .array([.string("filename"), .string("text")]),
                "properties": .object([
                    "filename": .object(["type": .string("string"), "description": .string("Exact .md filename")]),
                    "text": .object(["type": .string("string"), "description": .string("Text to append")])
                ])
            ])
        ),
        Tool(
            name: "create_entry",
            description: "Create a new Freewrite text entry. Requires write access enabled in the app.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "content": .object(["type": .string("string"), "description": .string("Initial content (optional)")])
                ])
            ])
        ),
    ]
    return .init(tools: tools)
}

await server.withMethodHandler(CallTool.self) { params in
    switch params.name {

    case "list_entries":
        let entries = loadEntries()
        if entries.isEmpty {
            return callResult("No entries found in ~/Documents/Freewrite/")
        }
        let lines = entries.map { e in
            "[\(e.date)] \(e.filename)\n  \(e.preview)"
        }.joined(separator: "\n\n")
        return callResult(lines)

    case "search_entries":
        guard let query = params.arguments?["query"]?.stringValue?.lowercased(), !query.isEmpty else {
            return callResult("Missing 'query' parameter.", isError: true)
        }
        let entries = loadEntries()
        var results: [String] = []
        for entry in entries {
            let fileURL = freewriteDir.appendingPathComponent(entry.filename)
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8),
                  content.lowercased().contains(query) else { continue }
            let snippet = String(content.replacingOccurrences(of: "\n", with: " ").prefix(200))
            results.append("[\(entry.date)] \(entry.filename)\n  \(snippet)")
        }
        if results.isEmpty { return callResult("No entries match '\(query)'.") }
        return callResult(results.joined(separator: "\n\n"))

    case "read_entry":
        guard let filename = params.arguments?["filename"]?.stringValue else {
            return callResult("Missing 'filename' parameter.", isError: true)
        }
        let fileURL = freewriteDir.appendingPathComponent(filename)
        guard isSafe(fileURL) else {
            return callResult("Access denied: path outside Freewrite directory.", isError: true)
        }
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return callResult("File not found: \(filename)", isError: true)
        }
        return callResult(content)

    case "append_to_entry":
        guard writeEnabled() else {
            return callResult("Write access is disabled. Enable it in Think IN → Settings (cpu icon).", isError: true)
        }
        guard let filename = params.arguments?["filename"]?.stringValue,
              let appendText = params.arguments?["text"]?.stringValue else {
            return callResult("Missing 'filename' or 'text' parameter.", isError: true)
        }
        let fileURL = freewriteDir.appendingPathComponent(filename)
        guard isSafe(fileURL) else { return callResult("Access denied.", isError: true) }
        guard var existing = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return callResult("File not found: \(filename)", isError: true)
        }
        existing += "\n" + appendText
        do {
            try existing.write(to: fileURL, atomically: true, encoding: .utf8)
            return callResult("Appended \(appendText.count) characters to \(filename).")
        } catch {
            return callResult("Write failed: \(error.localizedDescription)", isError: true)
        }

    case "create_entry":
        guard writeEnabled() else {
            return callResult("Write access is disabled. Enable it in Think IN → Settings (cpu icon).", isError: true)
        }
        let content = params.arguments?["content"]?.stringValue ?? ""
        let uuid = UUID().uuidString
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let dateStr = df.string(from: Date())
        let filename = "[\(uuid)]-[\(dateStr)].md"
        let fileURL = freewriteDir.appendingPathComponent(filename)
        let body = content.isEmpty ? "\n\n" : "\n\n" + content
        do {
            try FileManager.default.createDirectory(at: freewriteDir, withIntermediateDirectories: true)
            try body.write(to: fileURL, atomically: true, encoding: .utf8)
            return callResult("Created entry: \(filename)")
        } catch {
            return callResult("Create failed: \(error.localizedDescription)", isError: true)
        }

    default:
        return callResult("Unknown tool: \(params.name)", isError: true)
    }
}

// MARK: - Prompts

await server.withMethodHandler(ListPrompts.self) { _ in
    let prompts = thinkingPrompts.map { p in
        Prompt(
            name: p.name,
            description: p.description,
            arguments: [
                Prompt.Argument(name: "entry_content", description: "The freewrite entry text to analyze", required: true)
            ]
        )
    }
    return .init(prompts: prompts)
}

await server.withMethodHandler(GetPrompt.self) { params in
    guard let prompt = thinkingPrompts.first(where: { $0.name == params.name }) else {
        throw MCPError.invalidParams("Unknown prompt: \(params.name)")
    }
    let entryContent = params.arguments?["entry_content"] ?? "(No entry content provided)"
    let fullText = """
    \(prompt.text)

    Entry:
    \(entryContent)
    """
    return GetPrompt.Result(
        description: prompt.description,
        messages: [
            Prompt.Message.user(.text(text: fullText))
        ]
    )
}

// MARK: - Run

let transport = StdioTransport()
try await server.start(transport: transport)
try await server.waitUntilCompleted()
