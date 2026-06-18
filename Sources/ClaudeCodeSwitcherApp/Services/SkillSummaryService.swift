import CryptoKit
import Foundation
import ClaudeCodeSwitcherCore

struct SkillSummaryService: Sendable {
    private let cacheURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.cacheURL = appSupport
            .appendingPathComponent("ClaudeCodeSwitcher", isDirectory: true)
            .appendingPathComponent("skill-summaries.json")
    }

    func summary(for skill: ClaudeSkillRecord, provider: BackendProfile?, apiKey: String?) async -> SkillSummaryResult {
        guard let provider else {
            return .ready(skill.description.isEmpty ? "未生成摘要" : skill.description)
        }

        let skillText: String
        do {
            skillText = try String(contentsOf: skill.skillFile, encoding: .utf8)
        } catch {
            return .failed("无法读取 Skill 内容，暂时不能生成中文摘要。")
        }

        let fingerprint = Self.fingerprint(for: "\(provider.id)\n\(skillText)")
        if let cached = cachedSummary(for: fingerprint) {
            return .ready(cached)
        }

        guard let apiKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines),
              !apiKey.isEmpty else {
            return .needsAPIKey("需要先保存 \(provider.displayName) 的 API Key，才能生成中文摘要。")
        }

        do {
            let summary = try await requestSummary(skill: skill, skillText: skillText, provider: provider, apiKey: apiKey)
            try saveCachedSummary(summary, fingerprint: fingerprint)
            return .ready(summary)
        } catch {
            return .failed("中文摘要生成失败：\(error.localizedDescription)")
        }
    }

    private func requestSummary(skill: ClaudeSkillRecord, skillText: String, provider: BackendProfile, apiKey: String) async throws -> String {
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

        let clippedSkillText = String(skillText.prefix(4_500))
        let payload = AnthropicSummaryRequest(
            model: model,
            system: "你是一个 macOS 工具里的 Skill 管理摘要器。只输出中文，不要 Markdown，不要项目符号。",
            messages: [
                AnthropicMessage(
                    role: "user",
                    content: """
                    请把下面这个 Skill 的用途总结成一小段通俗中文，最多 80 个汉字。
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
            max_tokens: 120
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw SummaryError.httpStatus(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(AnthropicSummaryResponse.self, from: data)
        let text = decoded.content.compactMap(\.text).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw SummaryError.emptyResponse
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
}

private struct AnthropicContent: Decodable {
    let type: String
    let text: String?
}

private enum SummaryError: LocalizedError {
    case httpStatus(Int)
    case emptyResponse
    case invalidProvider

    var errorDescription: String? {
        switch self {
        case .httpStatus(let status):
            "摘要模型返回 HTTP \(status)"
        case .emptyResponse:
            "摘要模型没有返回摘要内容"
        case .invalidProvider:
            "摘要模型配置不完整"
        }
    }
}
