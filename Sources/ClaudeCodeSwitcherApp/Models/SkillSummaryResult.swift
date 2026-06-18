import Foundation

enum SkillSummaryResult: Equatable, Sendable {
    case ready(String)
    case needsAPIKey(String)
    case failed(String)

    var text: String {
        switch self {
        case .ready(let value),
             .needsAPIKey(let value),
             .failed(let value):
            value
        }
    }
}
