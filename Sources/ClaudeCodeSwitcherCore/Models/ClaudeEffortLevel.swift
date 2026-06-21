import Foundation

public enum ClaudeEffortLevel: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case auto
    case low
    case medium
    case high
    case xhigh
    case max

    public var id: String { rawValue }

    public var isPersistentSettingsLevel: Bool {
        switch self {
        case .low, .medium, .high, .xhigh:
            true
        case .auto, .max:
            false
        }
    }
}
