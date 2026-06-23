//
//  MCPSettingsStore.swift
//  freewrite
//

import Foundation

class MCPSettingsStore: ObservableObject {
    @Published var writeEnabled: Bool {
        didSet { writeMCPConfig() }
    }

    private static let configURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("ThinkIN/mcp-config.json")
    }()

    init() {
        if let data = try? Data(contentsOf: MCPSettingsStore.configURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let flag = json["writeEnabled"] as? Bool {
            writeEnabled = flag
        } else {
            writeEnabled = false
        }
    }

    func writeMCPConfig() {
        let dir = MCPSettingsStore.configURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let json: [String: Any] = ["writeEnabled": writeEnabled]
        if let data = try? JSONSerialization.data(withJSONObject: json) {
            try? data.write(to: MCPSettingsStore.configURL, options: .atomic)
        }
    }
}
