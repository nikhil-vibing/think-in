//
//  MCPConnectionView.swift
//  freewrite
//

import SwiftUI
import AppKit

// Runs a CLI command off the main thread and returns combined stdout+stderr.
private func runProcess(_ launchPath: String, _ args: [String]) async -> String {
    await withCheckedContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.launchPath = launchPath
            process.arguments = args
            process.environment = ProcessInfo.processInfo.environment
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            do {
                try process.run()
                process.waitUntilExit()
            } catch {}
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
        }
    }
}

struct MCPConnectionView: View {
    @EnvironmentObject var mcpStore: MCPSettingsStore
    var onDismiss: () -> Void

    @State private var isConnected: Bool? = nil
    @State private var isChecking = false
    @State private var isConnecting = false
    @State private var statusMessage = ""
    @State private var showManualInstructions = false
    @State private var claudePath: String? = nil
    @State private var serverBinaryPath: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Text("ThinkIN MCP")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .onHover { h in h ? NSCursor.pointingHand.push() : NSCursor.pop() }
            }

            Divider()

            // Write-access toggle
            Toggle("Enable write access", isOn: $mcpStore.writeEnabled)
                .toggleStyle(.switch)
                .font(.system(size: 12))

            Text("Allows Claude Code to create and append entries.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.top, -8)

            Divider()

            // Connection status row
            HStack(spacing: 6) {
                if isChecking || isConnecting {
                    ProgressView().scaleEffect(0.7)
                    Text(isConnecting ? "Connecting…" : "Checking…")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                } else if let connected = isConnected {
                    Image(systemName: connected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(connected ? .green : .secondary)
                        .font(.system(size: 13))
                    Text(connected ? "Connected to Claude Code" : "Not connected")
                        .font(.system(size: 12))
                        .foregroundColor(connected ? .primary : .secondary)
                } else {
                    Image(systemName: "circle").foregroundColor(.secondary).font(.system(size: 13))
                    Text("Checking…").font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
            }

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Action button
            if isConnected == false {
                Button(action: connect) {
                    Text("Connect Claude Code")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isConnecting)
                .onHover { h in h ? NSCursor.pointingHand.push() : NSCursor.pop() }
            } else if isConnected == true {
                Button(action: disconnect) {
                    Text("Disconnect")
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                }
                .buttonStyle(.bordered)
                .onHover { h in h ? NSCursor.pointingHand.push() : NSCursor.pop() }
            }

            // Manual fallback
            if showManualInstructions {
                Divider()
                manualSetupSection
            }
        }
        .padding(16)
        .frame(width: 300)
        .onAppear { checkStatus() }
    }

    @ViewBuilder
    private var manualSetupSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Manual setup")
                .font(.system(size: 11, weight: .semibold))

            if let path = serverBinaryPath {
                Text("Run in Terminal:")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                let cmd = "claude mcp add --scope user think-in -- \(path)"
                HStack(alignment: .top, spacing: 6) {
                    Text(cmd)
                        .font(.system(size: 10, design: .monospaced))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(cmd, forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc").font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .onHover { h in h ? NSCursor.pointingHand.push() : NSCursor.pop() }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
            } else {
                Text("Build the server first:\ncd ThinkINMCPServer && swift build -c release")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Helpers

    private func findClaudePath() -> String? {
        let candidates = [
            "\(NSHomeDirectory())/.local/bin/claude",
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/bin/claude"
        ]
        if let found = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) {
            return found
        }
        // Try PATH via /usr/bin/which
        let process = Process()
        process.launchPath = "/usr/bin/which"
        process.arguments = ["claude"]
        process.environment = ProcessInfo.processInfo.environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch { return nil }
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return output.isEmpty ? nil : output
    }

    private func findServerBinaryPath() -> String? {
        // Production: bundled with app
        if let url = Bundle.main.url(forResource: "ThinkINMCPServer", withExtension: nil) {
            return url.path
        }
        // Development: search common project locations under ~/Documents and ~/Desktop
        let home = NSHomeDirectory()
        let searchRoots = ["\(home)/Documents", "\(home)/Desktop", "\(home)/Developer", "\(home)/Projects"]
        let binaryRelPath = "ThinkINMCPServer/.build/release/ThinkINMCPServer"
        for root in searchRoots {
            guard let items = try? FileManager.default.contentsOfDirectory(atPath: root) else { continue }
            for item in items {
                let candidate = "\(root)/\(item)/\(binaryRelPath)"
                if FileManager.default.fileExists(atPath: candidate) { return candidate }
            }
        }
        return nil
    }

    // MARK: - Actions

    private func checkStatus() {
        isChecking = true
        statusMessage = ""
        Task {
            let cPath = findClaudePath()
            let bPath = findServerBinaryPath()
            var connected = false
            if let cp = cPath {
                let output = await runProcess(cp, ["mcp", "list"])
                connected = output.contains("think-in")
            }
            await MainActor.run {
                claudePath = cPath
                serverBinaryPath = bPath
                isConnected = connected
                isChecking = false
            }
        }
    }

    private func connect() {
        guard let cp = claudePath else {
            statusMessage = "Claude CLI not found. Install via: npm install -g @anthropic-ai/claude-code"
            showManualInstructions = true
            return
        }
        guard let bp = serverBinaryPath else {
            statusMessage = "MCP server binary not found. Build ThinkINMCPServer first."
            showManualInstructions = true
            return
        }
        isConnecting = true
        statusMessage = ""
        Task {
            _ = await runProcess(cp, ["mcp", "add", "--scope", "user", "think-in", "--", bp])
            let listOutput = await runProcess(cp, ["mcp", "list"])
            let success = listOutput.contains("think-in")
            await MainActor.run {
                isConnecting = false
                isConnected = success
                if success {
                    statusMessage = "Connected successfully."
                } else {
                    statusMessage = "Connection failed. Try the manual setup below."
                    showManualInstructions = true
                }
            }
        }
    }

    private func disconnect() {
        guard let cp = claudePath else { return }
        Task {
            _ = await runProcess(cp, ["mcp", "remove", "think-in"])
            let listOutput = await runProcess(cp, ["mcp", "list"])
            let stillConnected = listOutput.contains("think-in")
            await MainActor.run {
                isConnected = !stillConnected
                statusMessage = stillConnected ? "Disconnect failed." : "Disconnected."
            }
        }
    }
}
