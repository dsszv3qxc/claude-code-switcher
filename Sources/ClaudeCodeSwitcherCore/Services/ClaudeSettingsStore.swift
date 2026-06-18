import Foundation

public struct ClaudeSettingsStore: @unchecked Sendable {
    public let settingsURL: URL
    private let fileManager: FileManager

    public init(
        settingsURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("settings.json"),
        fileManager: FileManager = .default
    ) {
        self.settingsURL = settingsURL
        self.fileManager = fileManager
    }

    public func load() throws -> SettingsDocument {
        guard fileManager.fileExists(atPath: settingsURL.path) else {
            return SettingsDocument()
        }

        do {
            let data = try Data(contentsOf: settingsURL)
            return try SettingsDocument(data: data)
        } catch {
            throw SwitcherError.unreadableSettings(settingsURL)
        }
    }

    public func save(_ document: SettingsDocument) throws {
        let data: Data
        do {
            data = try document.encoded()
        } catch {
            throw SwitcherError.unwritableSettings(settingsURL)
        }

        do {
            try fileManager.createDirectory(
                at: settingsURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: settingsURL, options: [.atomic])
        } catch {
            throw SwitcherError.unwritableSettings(settingsURL)
        }
    }
}
