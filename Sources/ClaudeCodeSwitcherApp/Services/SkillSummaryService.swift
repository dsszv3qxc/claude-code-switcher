import CryptoKit
import Foundation
import ClaudeCodeSwitcherCore

struct SkillSummaryService: Sendable {
    private let cacheURL: URL
    private static let summaryPromptVersion = "skill-summary-v2-2026-06-19"

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.cacheURL = appSupport
            .appendingPathComponent("ClaudeCodeSwitcher", isDirectory: true)
            .appendingPathComponent("skill-summaries.json")
    }

    func summary(for skill: ClaudeSkillRecord, provider: BackendProfile?, apiKey: String?, languageID: String) async -> SkillSummaryResult {
        guard let provider else {
            return .ready(skill.description.isEmpty ? AppStrings.text("未生成摘要", languageID: languageID) : skill.description)
        }

        let skillText: String
        do {
            skillText = try String(contentsOf: skill.skillFile, encoding: .utf8)
        } catch {
            return .failed(AppStrings.isEnglish(languageID)
                ? "Could not read this Skill file, so a summary cannot be generated."
                : "无法读取 Skill 内容，暂时不能生成摘要。")
        }

        let fingerprint = Self.fingerprint(for: "\(Self.summaryPromptVersion)\n\(languageID)\n\(provider.id)\n\(skillText)")
        if let cached = cachedSummary(for: fingerprint) {
            return .ready(cached)
        }

        guard let apiKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines),
              !apiKey.isEmpty else {
            return .needsAPIKey(AppStrings.isEnglish(languageID)
                ? "Save the \(AppStrings.profileName(provider, languageID: languageID)) API key before generating summaries."
                : "需要先保存 \(AppStrings.profileName(provider, languageID: languageID)) 的 API Key，才能生成摘要。")
        }

        do {
            let summary = try await requestSummary(skill: skill, skillText: skillText, provider: provider, apiKey: apiKey, languageID: languageID)
            try saveCachedSummary(summary, fingerprint: fingerprint)
            return .ready(summary)
        } catch {
            return .failed(summaryFailureMessage(error, languageID: languageID))
        }
    }

    func cachedSummary(for skill: ClaudeSkillRecord, provider: BackendProfile?, languageID: String) -> String? {
        guard let provider,
              let skillText = try? String(contentsOf: skill.skillFile, encoding: .utf8) else {
            return nil
        }
        let fingerprint = Self.fingerprint(for: "\(Self.summaryPromptVersion)\n\(languageID)\n\(provider.id)\n\(skillText)")
        return cachedSummary(for: fingerprint)
    }

    private func requestSummary(skill: ClaudeSkillRecord, skillText: String, provider: BackendProfile, apiKey: String, languageID: String) async throws -> String {
        do {
            return try await performSummaryRequest(
                skill: skill,
                skillText: skillText,
                provider: provider,
                apiKey: apiKey,
                languageID: languageID,
                maxTokens: 320,
                skillTextLimit: 7_000
            )
        } catch SummaryError.truncatedResponse {
            return try await performSummaryRequest(
                skill: skill,
                skillText: skillText,
                provider: provider,
                apiKey: apiKey,
                languageID: languageID,
                maxTokens: 640,
                skillTextLimit: 5_000
            )
        }
    }

    private func performSummaryRequest(
        skill: ClaudeSkillRecord,
        skillText: String,
        provider: BackendProfile,
        apiKey: String,
        languageID: String,
        maxTokens: Int,
        skillTextLimit: Int
    ) async throws -> String {
        guard let url = messagesURL(for: provider),
              let model = provider.primaryModel?.trimmingCharacters(in: .whitespacesAndNewlines),
              !model.isEmpty else {
            throw SummaryError.invalidProvider
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let clippedSkillText = String(skillText.prefix(skillTextLimit))
        let wantsEnglish = languageID.hasPrefix("en")
        let payload = AnthropicSummaryRequest(
            model: model,
            system: wantsEnglish
                ? "You summarize Claude Code Skills for a macOS utility. Output concise English only. Do not use Markdown or bullet points. Always return a complete sentence."
                : "你是一个 macOS 工具里的 Skill 管理摘要器。只输出中文，不要 Markdown，不要项目符号。必须输出完整句子，不要在句尾截断。",
            messages: [
                AnthropicMessage(
                    role: "user",
                    content: wantsEnglish
                        ? """
                        Summarize what this Skill helps the user do in one plain-English sentence, under 45 words.
                        Do not mention file paths. Do not start with "This Skill".

                        Name: \(skill.commandName)
                        Category: \(skill.category)
                        Original description: \(skill.description)

                        SKILL.md:
                        \(clippedSkillText)
                        """
                        : """
                        请把下面这个 Skill 的用途总结成一小段通俗中文，控制在 80 到 120 个汉字之间。
                        需要说明它主要帮用户完成什么，不要翻译文件路径，不要提“这个 Skill”。

                        名称：\(skill.commandName)
                        分类：\(skill.category)
                        原始描述：\(skill.description)

                        SKILL.md：
                        \(clippedSkillText)
                        """
                )
            ],
            temperature: 0.2,
            max_tokens: maxTokens
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            let body = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(260)
            throw SummaryError.httpStatus(httpResponse.statusCode, body.map(String.init))
        }

        let decoded: AnthropicSummaryResponse
        do {
            decoded = try JSONDecoder().decode(AnthropicSummaryResponse.self, from: data)
        } catch {
            let body = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(260)
            throw SummaryError.decodeFailed(body.map(String.init))
        }
        let text = decoded.content.compactMap(\.text).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw SummaryError.emptyResponse
        }
        if decoded.stopReason == "max_tokens" {
            throw SummaryError.truncatedResponse
        }

        return text.replacingOccurrences(of: "\n", with: " ")
    }

    private func messagesURL(for provider: BackendProfile) -> URL? {
        guard let baseURL = provider.baseURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              var components = URLComponents(string: baseURL) else {
            return nil
        }

        var path = components.path
        while path.hasSuffix("/") {
            path.removeLast()
        }
        if path.hasSuffix("/messages") {
            components.path = path
        } else if path.hasSuffix("/v1") {
            components.path = "\(path)/messages"
        } else {
            components.path = "\(path)/v1/messages"
        }
        return components.url
    }

    private func cachedSummary(for fingerprint: String) -> String? {
        guard let data = try? Data(contentsOf: cacheURL),
              let cache = try? JSONDecoder().decode(SummaryCache.self, from: data) else {
            return nil
        }
        return cache.entries[fingerprint]?.summary
    }

    private func saveCachedSummary(_ summary: String, fingerprint: String) throws {
        var cache = SummaryCache(entries: [:])
        if let data = try? Data(contentsOf: cacheURL),
           let decoded = try? JSONDecoder().decode(SummaryCache.self, from: data) {
            cache = decoded
        }

        cache.entries[fingerprint] = SummaryEntry(
            summary: summary,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )

        try FileManager.default.createDirectory(
            at: cacheURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(cache)
        try data.write(to: cacheURL, options: [.atomic])
    }

    private static func fingerprint(for text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

private struct SummaryCache: Codable {
    var entries: [String: SummaryEntry]
}

private struct SummaryEntry: Codable {
    let summary: String
    let updatedAt: String
}

private struct AnthropicSummaryRequest: Encodable {
    let model: String
    let system: String
    let messages: [AnthropicMessage]
    let temperature: Double
    let max_tokens: Int
}

private struct AnthropicMessage: Codable {
    let role: String
    let content: String
}

private struct AnthropicSummaryResponse: Decodable {
    let content: [AnthropicContent]
    let stopReason: String?

    enum CodingKeys: String, CodingKey {
        case content
        case stopReason = "stop_reason"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let blocks = try? container.decode([AnthropicContent].self, forKey: .content) {
            content = blocks
        } else if let text = try? container.decode(String.self, forKey: .content) {
            content = [AnthropicContent(type: "text", text: text)]
        } else {
            content = []
        }
        stopReason = try? container.decode(String.self, forKey: .stopReason)
    }
}

private struct AnthropicContent: Decodable {
    let type: String?
    let text: String?
}

private enum SummaryError: LocalizedError {
    case httpStatus(Int, String?)
    case emptyResponse
    case invalidProvider
    case truncatedResponse
    case decodeFailed(String?)

    var errorDescription: String? {
        switch self {
        case .httpStatus(let status, let body):
            if let body, !body.isEmpty {
                "摘要模型返回 HTTP \(status)：\(body)"
            } else {
                "摘要模型返回 HTTP \(status)"
            }
        case .emptyResponse:
            "摘要模型没有返回摘要内容"
        case .invalidProvider:
            "摘要模型配置不完整"
        case .truncatedResponse:
            "摘要模型返回内容被截断"
        case .decodeFailed(let body):
            if let body, !body.isEmpty {
                "无法解析摘要模型返回内容：\(body)"
            } else {
                "无法解析摘要模型返回内容"
            }
        }
    }
}

private func summaryFailureMessage(_ error: Error, languageID: String) -> String {
    let detail = error.localizedDescription
    let prefix = AppStrings.isEnglish(languageID) ? "Summary generation failed" : "摘要生成失败"

    if let summaryError = error as? SummaryError {
        switch summaryError {
        case .httpStatus(let status, let body):
            let hint: String
            if AppStrings.isEnglish(languageID) {
                switch status {
                case 400:
                    hint = "Check whether the model name and Anthropic-compatible request format are accepted by this provider."
                case 401, 403:
                    hint = "Check whether the API key is valid and saved for this backend."
                case 404:
                    hint = "Check whether the Base URL ends at the provider's Anthropic-compatible endpoint."
                case 429:
                    hint = "The provider may be rate-limiting this key. Try again later."
                default:
                    hint = "The provider rejected the request."
                }
                let bodyText = body.map { " Response: \($0)" } ?? ""
                return "\(prefix): HTTP \(status). \(hint)\(bodyText)"
            }

            switch status {
            case 400:
                hint = "请检查模型名，以及这个服务是否真的兼容 Anthropic Messages 格式。"
            case 401, 403:
                hint = "请检查这个后端的 API Key 是否正确保存。"
            case 404:
                hint = "请检查 Base URL 是否指向服务商的 Anthropic 兼容接口。"
            case 429:
                hint = "服务商可能正在限流，稍后再试。"
            default:
                hint = "服务商拒绝了这次请求。"
            }
            let bodyText = body.map { " 返回内容：\($0)" } ?? ""
            return "\(prefix)：HTTP \(status)。\(hint)\(bodyText)"
        case .emptyResponse, .invalidProvider, .truncatedResponse, .decodeFailed:
            break
        }
    }

    return AppStrings.isEnglish(languageID)
        ? "\(prefix): \(detail)"
        : "\(prefix)：\(detail)"
}
