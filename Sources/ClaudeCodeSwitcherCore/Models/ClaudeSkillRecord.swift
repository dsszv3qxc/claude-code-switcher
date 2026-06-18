import Foundation

public enum ClaudeSkillScope: String, CaseIterable, Codable, Sendable {
    case personal
    case plugin

    public var displayName: String {
        switch self {
        case .personal:
            "Claude 个人"
        case .plugin:
            "Claude 插件"
        }
    }
}

public struct SkillMetadata: Equatable, Sendable {
    public let name: String?
    public let description: String
    public let allowedTools: String?
    public let disallowedTools: String?
    public let disableModelInvocation: Bool

    public init(
        name: String?,
        description: String,
        allowedTools: String?,
        disallowedTools: String?,
        disableModelInvocation: Bool
    ) {
        self.name = name
        self.description = description
        self.allowedTools = allowedTools
        self.disallowedTools = disallowedTools
        self.disableModelInvocation = disableModelInvocation
    }
}

public struct ClaudeSkillRecord: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let commandName: String
    public let description: String
    public let category: String
    public let scope: ClaudeSkillScope
    public let skillDirectory: URL
    public let skillFile: URL
    public let pluginName: String?
    public let pluginVersion: String?
    public let installedAt: String?
    public let lastUpdated: String?
    public let modifiedAt: Date?
    public let supportingFileCount: Int
    public let allowedTools: String?
    public let disallowedTools: String?
    public let disableModelInvocation: Bool
    public let isPaused: Bool

    public var isUninstallable: Bool {
        scope == .personal
    }

    public init(
        id: String,
        name: String,
        commandName: String,
        description: String,
        category: String,
        scope: ClaudeSkillScope,
        skillDirectory: URL,
        skillFile: URL,
        pluginName: String?,
        pluginVersion: String?,
        installedAt: String?,
        lastUpdated: String?,
        modifiedAt: Date?,
        supportingFileCount: Int,
        allowedTools: String?,
        disallowedTools: String?,
        disableModelInvocation: Bool,
        isPaused: Bool
    ) {
        self.id = id
        self.name = name
        self.commandName = commandName
        self.description = description
        self.category = category
        self.scope = scope
        self.skillDirectory = skillDirectory
        self.skillFile = skillFile
        self.pluginName = pluginName
        self.pluginVersion = pluginVersion
        self.installedAt = installedAt
        self.lastUpdated = lastUpdated
        self.modifiedAt = modifiedAt
        self.supportingFileCount = supportingFileCount
        self.allowedTools = allowedTools
        self.disallowedTools = disallowedTools
        self.disableModelInvocation = disableModelInvocation
        self.isPaused = isPaused
    }
}
