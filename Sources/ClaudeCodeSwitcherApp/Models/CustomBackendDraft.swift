import Foundation
import ClaudeCodeSwitcherCore

struct CustomBackendDraft: Equatable {
    var displayName = ""
    var baseURL = ""
    var primaryModel = ""
    var fastModel = ""
    var apiKey = ""

    static let example = CustomBackendDraft(
        displayName: "我的模型",
        baseURL: "https://api.example.com/anthropic",
        primaryModel: "model-name",
        fastModel: "model-name-fast",
        apiKey: ""
    )

    func makeProfile() throws -> BackendProfile {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlText = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let primary = primaryModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let fast = fastModel.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty,
              !urlText.isEmpty,
              !primary.isEmpty,
              !fast.isEmpty,
              let url = URL(string: urlText),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host?.isEmpty == false else {
            throw SwitcherError.invalidBackendProfile
        }

        return .custom(
            displayName: name,
            baseURL: urlText,
            primaryModel: primary,
            fastModel: fast
        )
    }
}
