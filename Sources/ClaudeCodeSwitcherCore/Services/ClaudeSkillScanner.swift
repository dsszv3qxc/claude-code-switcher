import Foundation

public struct ClaudeSkillScanner: @unchecked Sendable {
    public static let skillFileName = "SKILL.md"
    public static let pausedSkillFileName = "SKILL.md.paused-by-claude-code-switcher"

    private let claudeHome: URL
    private let fileManager: FileManager

    public init(
        claudeHome: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude"),
        fileManager: FileManager = .default
    ) {
        self.claudeHome = claudeHome
        self.fileManager = fileManager
    }

    public func scan() throws -> [ClaudeSkillRecord] {
        let records = try personalSkills() + pluginSkills()
        return records.sorted {
            if $0.scope != $1.scope {
                return $0.scope.rawValue < $1.scope.rawValue
            }
            return $0.commandName.localizedStandardCompare($1.commandName) == .orderedAscending
        }
    }

    private func personalSkills() throws -> [ClaudeSkillRecord] {
        let skillsDirectory = claudeHome.appendingPathComponent("skills")
        guard directoryExists(skillsDirectory) else {
            return []
        }

        return try immediateSkillDirectories(in: skillsDirectory).map { skillDirectory in
            try makeRecord(
                skillDirectory: skillDirectory,
                scope: .personal,
                pluginName: nil,
                pluginVersion: nil,
                installedAt: nil,
                lastUpdated: nil
            )
        }
    }

    private func pluginSkills() throws -> [ClaudeSkillRecord] {
        let installedPluginsURL = claudeHome.appendingPathComponent("plugins/installed_plugins.json")
        guard fileManager.fileExists(atPath: installedPluginsURL.path) else {
            return []
        }

        let data = try Data(contentsOf: installedPluginsURL)
        let envelope = try JSONDecoder().decode(InstalledPluginsEnvelope.self, from: data)

        return try envelope.plugins.flatMap { pluginKey, installations in
            try installations.flatMap { installation in
                let installPath = URL(fileURLWithPath: installation.installPath)
                let skillsDirectory = installPath.appendingPathComponent("skills")
                guard directoryExists(skillsDirectory) else {
                    return [ClaudeSkillRecord]()
                }

                let pluginName = pluginKey.components(separatedBy: "@").first ?? pluginKey
                return try immediateSkillDirectories(in: skillsDirectory).map { skillDirectory in
                    try makeRecord(
                        skillDirectory: skillDirectory,
                        scope: .plugin,
                        pluginName: pluginName,
                        pluginVersion: installation.version,
                        installedAt: installation.installedAt,
                        lastUpdated: installation.lastUpdated
                    )
                }
            }
        }
    }

    private func immediateSkillDirectories(in directory: URL) throws -> [URL] {
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        return urls.filter { url in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                return false
            }
            return fileManager.fileExists(atPath: url.appendingPathComponent(Self.skillFileName).path)
                || fileManager.fileExists(atPath: url.appendingPathComponent(Self.pausedSkillFileName).path)
        }
    }

    private func makeRecord(
        skillDirectory: URL,
        scope: ClaudeSkillScope,
        pluginName: String?,
        pluginVersion: String?,
        installedAt: String?,
        lastUpdated: String?
    ) throws -> ClaudeSkillRecord {
        let activeSkillFile = skillDirectory.appendingPathComponent(Self.skillFileName)
        let pausedSkillFile = skillDirectory.appendingPathComponent(Self.pausedSkillFileName)
        let isActive = fileManager.fileExists(atPath: activeSkillFile.path)
        let skillFile = isActive ? activeSkillFile : pausedSkillFile
        let isPaused = !isActive
        let text = try String(contentsOf: skillFile, encoding: .utf8)
        let metadata = SkillMetadataParser.parse(text)
        let folderName = skillDirectory.lastPathComponent
        let name = metadata.name?.isEmpty == false ? metadata.name! : folderName
        let commandName = scope == .plugin && pluginName?.isEmpty == false
            ? "\(pluginName!):\(name)"
            : name
        let category = SkillCategoryClassifier.category(
            name: name,
            commandName: commandName,
            description: metadata.description,
            scope: scope,
            pluginName: pluginName
        )

        return ClaudeSkillRecord(
            id: skillDirectory.path,
            name: name,
            commandName: commandName,
            description: metadata.description,
            category: category,
            scope: scope,
            skillDirectory: skillDirectory,
            skillFile: skillFile,
            pluginName: pluginName,
            pluginVersion: pluginVersion,
            installedAt: installedAt,
            lastUpdated: lastUpdated,
            modifiedAt: modifiedDate(for: skillFile),
            supportingFileCount: supportingFileCount(in: skillDirectory),
            allowedTools: metadata.allowedTools,
            disallowedTools: metadata.disallowedTools,
            disableModelInvocation: metadata.disableModelInvocation,
            isPaused: isPaused
        )
    }

    private func directoryExists(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func modifiedDate(for url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private func supportingFileCount(in directory: URL) -> Int {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var count = 0
        for case let url as URL in enumerator {
            guard url.lastPathComponent != Self.skillFileName,
                  url.lastPathComponent != Self.pausedSkillFileName else {
                continue
            }
            if (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                count += 1
            }
        }
        return count
    }
}

private struct InstalledPluginsEnvelope: Decodable {
    let plugins: [String: [InstalledPlugin]]
}

private struct InstalledPlugin: Decodable {
    let scope: String
    let installPath: String
    let version: String
    let installedAt: String
    let lastUpdated: String
}
