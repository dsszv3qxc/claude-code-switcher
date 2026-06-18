import Foundation

enum SkillUpdateState: Equatable, Sendable {
    case notChecked
    case checking
    case current(String)
    case updateAvailable(String)
    case unavailable(String)
    case failed(String)

    var label: String {
        switch self {
        case .notChecked:
            "未检查"
        case .checking:
            "检查中"
        case .current:
            "已是最新"
        case .updateAvailable:
            "可更新"
        case .unavailable:
            "不可检查"
        case .failed:
            "检查失败"
        }
    }

    var detail: String {
        switch self {
        case .notChecked:
            "尚未检查更新。"
        case .checking:
            "正在检查更新。"
        case .current(let message),
             .updateAvailable(let message),
             .unavailable(let message),
             .failed(let message):
            message
        }
    }

    var canUpdate: Bool {
        if case .updateAvailable = self {
            return true
        }
        return false
    }
}
