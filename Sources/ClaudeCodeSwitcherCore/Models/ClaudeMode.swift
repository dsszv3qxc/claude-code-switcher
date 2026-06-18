import Foundation

public enum ClaudeMode: String, CaseIterable, Identifiable, Equatable {
    case claudeSubscription
    case deepSeekPro
    case deepSeekFlash

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .claudeSubscription:
            "Claude 订阅"
        case .deepSeekPro:
            "DeepSeek V4 Pro"
        case .deepSeekFlash:
            "DeepSeek V4 Flash"
        }
    }

    public var detail: String {
        switch self {
        case .claudeSubscription:
            "使用当前已登录的 Claude Code 订阅，不走 DeepSeek API。"
        case .deepSeekPro:
            "后续新启动的 Claude Code 会走 DeepSeek V4 Pro。"
        case .deepSeekFlash:
            "后续新启动的 Claude Code 会走 DeepSeek V4 Flash。"
        }
    }

    public var needsAPIKey: Bool {
        self != .claudeSubscription
    }

    public var deepSeekModel: String? {
        switch self {
        case .claudeSubscription:
            nil
        case .deepSeekPro:
            "deepseek-v4-pro[1m]"
        case .deepSeekFlash:
            "deepseek-v4-flash"
        }
    }
}
