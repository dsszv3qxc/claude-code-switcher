import Foundation
import ClaudeCodeSwitcherCore

struct OllamaProfileScanner: Sendable {
    private let tagsURL = URL(string: "http://localhost:11434/api/tags")!

    func scanQwenProfiles() async -> [BackendProfile] {
        var request = URLRequest(url: tagsURL)
        request.timeoutInterval = 2

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return []
            }

            let decoded = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
            return decoded.models
                .map(\.name)
                .filter { $0.localizedCaseInsensitiveContains("qwen") }
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
                .map(BackendProfile.ollama(modelName:))
        } catch {
            return []
        }
    }
}

private struct OllamaTagsResponse: Decodable {
    let models: [OllamaModel]
}

private struct OllamaModel: Decodable {
    let name: String
}
