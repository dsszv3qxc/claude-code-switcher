import Foundation

public enum BackendProfileKind: String, Codable, Sendable {
    case claudeSubscription
    case anthropicCompatible
}

public struct BackendProfile: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public var displayName: String
    public var detail: String
    public var kind: BackendProfileKind
    public var baseURL: String?
    public var primaryModel: String?
    public var fastModel: String?
    public var isBuiltIn: Bool

    public var needsAPIKey: Bool {
        kind == .anthropicCompatible
    }

    public var isClaudeSubscription: Bool {
        kind == .claudeSubscription
    }

    public var effectiveFastModel: String? {
        let trimmedFast = fastModel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedFast.isEmpty {
            return trimmedFast
        }
        return primaryModel
    }

    public init(
        id: String,
        displayName: String,
        detail: String,
        kind: BackendProfileKind,
        baseURL: String?,
        primaryModel: String?,
        fastModel: String?,
        isBuiltIn: Bool
    ) {
        self.id = id
        self.displayName = displayName
        self.detail = detail
        self.kind = kind
        self.baseURL = baseURL
        self.primaryModel = primaryModel
        self.fastModel = fastModel
        self.isBuiltIn = isBuiltIn
    }

    public static let claudeSubscription = BackendProfile(
        id: "builtin.claude.subscription",
        displayName: "Claude 订阅",
        detail: "使用已登录的 Claude Code 订阅，不走 API。",
        kind: .claudeSubscription,
        baseURL: nil,
        primaryModel: nil,
        fastModel: nil,
        isBuiltIn: true
    )

    public static let deepSeekPro = BackendProfile(
        id: "builtin.deepseek.v4-pro",
        displayName: "DeepSeek V4 Pro",
        detail: "强能力模式，适合复杂任务。",
        kind: .anthropicCompatible,
        baseURL: "https://api.deepseek.com/anthropic",
        primaryModel: "deepseek-v4-pro[1m]",
        fastModel: "deepseek-v4-flash",
        isBuiltIn: true
    )

    public static let deepSeekFlash = BackendProfile(
        id: "builtin.deepseek.v4-flash",
        displayName: "DeepSeek V4 Flash",
        detail: "更快更省，适合日常任务。",
        kind: .anthropicCompatible,
        baseURL: "https://api.deepseek.com/anthropic",
        primaryModel: "deepseek-v4-flash",
        fastModel: "deepseek-v4-flash",
        isBuiltIn: true
    )

    public static let builtIns: [BackendProfile] = [
        .claudeSubscription,
        .deepSeekPro,
        .deepSeekFlash
    ]

    public static func custom(
        id: String = UUID().uuidString,
        displayName: String,
        baseURL: String,
        primaryModel: String,
        fastModel: String
    ) -> BackendProfile {
        BackendProfile(
            id: "custom.\(id)",
            displayName: displayName,
            detail: "自定义 Anthropic 兼容后端。",
            kind: .anthropicCompatible,
            baseURL: baseURL,
            primaryModel: primaryModel,
            fastModel: fastModel,
            isBuiltIn: false
        )
    }

    public static func detectedExternal(baseURL: String, primaryModel: String?, fastModel: String?) -> BackendProfile {
        BackendProfile(
            id: "detected.external.\(baseURL).\(primaryModel ?? "unknown")",
            displayName: "外部配置",
            detail: "当前 Claude Code 配置里已有一个未保存在本应用中的 API 后端。",
            kind: .anthropicCompatible,
            baseURL: baseURL,
            primaryModel: primaryModel,
            fastModel: fastModel,
            isBuiltIn: true
        )
    }
}

public extension ClaudeMode {
    var backendProfile: BackendProfile {
        switch self {
        case .claudeSubscription:
            .claudeSubscription
        case .deepSeekPro:
            .deepSeekPro
        case .deepSeekFlash:
            .deepSeekFlash
        }
    }
}
