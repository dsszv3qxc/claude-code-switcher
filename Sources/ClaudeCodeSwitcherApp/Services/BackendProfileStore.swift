import Foundation
import ClaudeCodeSwitcherCore

struct BackendProfileStore: Sendable {
    private let storeURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.storeURL = appSupport
            .appendingPathComponent("ClaudeCodeSwitcher", isDirectory: true)
            .appendingPathComponent("backend-profiles.json")
    }

    func loadCustomProfiles() throws -> [BackendProfile] {
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            return []
        }

        let data = try Data(contentsOf: storeURL)
        let envelope = try JSONDecoder().decode(BackendProfileEnvelope.self, from: data)
        return envelope.profiles.filter { !$0.isBuiltIn && $0.kind == .anthropicCompatible }
    }

    func saveCustomProfiles(_ profiles: [BackendProfile]) throws {
        let cleanProfiles = profiles
            .filter { !$0.isBuiltIn && $0.kind == .anthropicCompatible }
            .map(Self.normalized)

        try FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let envelope = BackendProfileEnvelope(profiles: cleanProfiles)
        let data = try JSONEncoder.pretty.encode(envelope)
        try data.write(to: storeURL, options: [.atomic])
    }

    private static func normalized(_ profile: BackendProfile) -> BackendProfile {
        BackendProfile(
            id: profile.id,
            displayName: profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            detail: profile.detail,
            kind: profile.kind,
            baseURL: profile.baseURL?.trimmingCharacters(in: .whitespacesAndNewlines),
            primaryModel: profile.primaryModel?.trimmingCharacters(in: .whitespacesAndNewlines),
            fastModel: profile.fastModel?.trimmingCharacters(in: .whitespacesAndNewlines),
            isBuiltIn: false
        )
    }
}

private struct BackendProfileEnvelope: Codable {
    var profiles: [BackendProfile]
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
