import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case backend
    case skills

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .backend:
            "后端切换"
        case .skills:
            "Skill 管理"
        }
    }
}
