import Foundation

public struct SettingsDocument: Equatable {
    public private(set) var object: [String: Any]

    public init(data: Data) throws {
        if data.isEmpty {
            object = [:]
            return
        }

        let decoded = try JSONSerialization.jsonObject(with: data, options: [])
        object = decoded as? [String: Any] ?? [:]
    }

    public init(object: [String: Any] = [:]) {
        self.object = object
    }

    public static let routedEnvironmentKeys: Set<String> = [
        "ANTHROPIC_API_KEY",
        "ANTHROPIC_AUTH_TOKEN",
        "ANTHROPIC_BASE_URL",
        "ANTHROPIC_MODEL",
        "ANTHROPIC_DEFAULT_OPUS_MODEL",
        "ANTHROPIC_DEFAULT_SONNET_MODEL",
        "ANTHROPIC_DEFAULT_HAIKU_MODEL",
        "ANTHROPIC_SMALL_FAST_MODEL",
        "CLAUDE_CODE_SUBAGENT_MODEL"
    ]

    public var detectedMode: ClaudeMode {
        let profile = detectedProfile(in: BackendProfile.builtIns)
        switch profile.id {
        case BackendProfile.deepSeekPro.id:
            return .deepSeekPro
        case BackendProfile.deepSeekFlash.id:
            return .deepSeekFlash
        default:
            return .claudeSubscription
        }
    }

    public func detectedProfile(in profiles: [BackendProfile]) -> BackendProfile {
        let env = object["env"] as? [String: Any]
        let baseURL = env?["ANTHROPIC_BASE_URL"] as? String
        let environmentModel = env?["ANTHROPIC_MODEL"] as? String
        let topLevelModel = object["model"] as? String
        let fastModel = env?["ANTHROPIC_SMALL_FAST_MODEL"] as? String
        let model = environmentModel ?? topLevelModel

        guard let baseURL, !baseURL.isEmpty else {
            if SettingsDocument.isDeepSeekModel(topLevelModel) {
                return topLevelModel?.hasPrefix("deepseek-v4-pro") == true ? .deepSeekPro : .deepSeekFlash
            }
            return .claudeSubscription
        }

        if let exact = profiles.first(where: { profile in
            profile.kind == .anthropicCompatible
                && profile.baseURL == baseURL
                && profile.primaryModel == model
        }) {
            return exact
        }

        if baseURL == BackendProfile.deepSeekPro.baseURL {
            if model?.hasPrefix("deepseek-v4-pro") == true {
                return .deepSeekPro
            }
            if model?.hasPrefix("deepseek-v4-flash") == true {
                return .deepSeekFlash
            }
        }

        return .detectedExternal(baseURL: baseURL, primaryModel: model, fastModel: fastModel)
    }

    public var deepSeekAPIKey: String? {
        guard let env = object["env"] as? [String: Any],
              env["ANTHROPIC_BASE_URL"] as? String == BackendProfile.deepSeekPro.baseURL else {
            return nil
        }

        return (env["ANTHROPIC_AUTH_TOKEN"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public mutating func apply(mode: ClaudeMode, apiKey: String?) throws {
        try apply(profile: mode.backendProfile, apiKey: apiKey)
    }

    public mutating func apply(profile: BackendProfile, apiKey: String?) throws {
        switch profile.kind {
        case .claudeSubscription:
            clearRoutingEnvironment()
        case .anthropicCompatible:
            guard let apiKey, !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SwitcherError.missingAPIKey
            }
            try setAnthropicCompatibleEnvironment(profile: profile, apiKey: apiKey)
        }
    }

    public func encoded() throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    }

    private mutating func setAnthropicCompatibleEnvironment(profile: BackendProfile, apiKey: String) throws {
        guard let baseURL = profile.baseURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              let model = profile.primaryModel?.trimmingCharacters(in: .whitespacesAndNewlines),
              let fastModel = profile.effectiveFastModel?.trimmingCharacters(in: .whitespacesAndNewlines),
              !baseURL.isEmpty,
              !model.isEmpty,
              !fastModel.isEmpty else {
            throw SwitcherError.invalidBackendProfile
        }

        var env = object["env"] as? [String: Any] ?? [:]
        env["ANTHROPIC_BASE_URL"] = baseURL
        env["ANTHROPIC_AUTH_TOKEN"] = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        env["ANTHROPIC_MODEL"] = model
        env["ANTHROPIC_DEFAULT_OPUS_MODEL"] = model
        env["ANTHROPIC_DEFAULT_SONNET_MODEL"] = model
        env["ANTHROPIC_DEFAULT_HAIKU_MODEL"] = fastModel
        env["ANTHROPIC_SMALL_FAST_MODEL"] = fastModel
        env["CLAUDE_CODE_SUBAGENT_MODEL"] = fastModel
        env.removeValue(forKey: "ANTHROPIC_API_KEY")
        object["env"] = env
        object["model"] = model
    }

    private mutating func clearRoutingEnvironment() {
        let env = object["env"] as? [String: Any]
        let topLevelModel = object["model"] as? String
        let environmentModel = env?["ANTHROPIC_MODEL"] as? String
        let hasRoutedBaseURL = env?["ANTHROPIC_BASE_URL"] != nil
        if SettingsDocument.isDeepSeekModel(topLevelModel)
            || hasRoutedBaseURL
            || (topLevelModel != nil && topLevelModel == environmentModel) {
            object.removeValue(forKey: "model")
        }

        guard var env = env else { return }

        for key in SettingsDocument.routedEnvironmentKeys {
            env.removeValue(forKey: key)
        }

        if env.isEmpty {
            object.removeValue(forKey: "env")
        } else {
            object["env"] = env
        }
    }

    private static func isDeepSeekModel(_ model: String?) -> Bool {
        model?.hasPrefix("deepseek-") == true
    }

    public static func == (lhs: SettingsDocument, rhs: SettingsDocument) -> Bool {
        NSDictionary(dictionary: lhs.object).isEqual(to: rhs.object)
    }
}

public enum SwitcherError: LocalizedError, Equatable {
    case missingAPIKey
    case unreadableSettings(URL)
    case unwritableSettings(URL)
    case keychainReadFailed(OSStatus)
    case keychainSaveFailed(OSStatus)
    case invalidBackendProfile

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "请先填写 API Key，再应用这个 API 后端。"
        case .unreadableSettings(let url):
            "无法读取 Claude Code 配置：\(url.path)。"
        case .unwritableSettings(let url):
            "无法写入 Claude Code 配置：\(url.path)。"
        case .keychainReadFailed(let status):
            "无法从钥匙串读取 API Key。OSStatus \(status)。"
        case .keychainSaveFailed(let status):
            "无法把 API Key 保存到钥匙串。OSStatus \(status)。"
        case .invalidBackendProfile:
            "自定义后端配置不完整，请填写 Base URL、主模型和快速模型。"
        }
    }
}
