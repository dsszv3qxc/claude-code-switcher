import Foundation
import ClaudeCodeSwitcherCore

enum AppMessage: Equatable, Sendable {
    case empty
    case raw(String)
    case currentMode(BackendProfile)
    case selectedMode(BackendProfile)
    case switchedMode(BackendProfile)
    case customBackendPrompt
    case customBackendLoadFailed(String)
    case profileDoesNotNeedKey(BackendProfile)
    case noSavedKey(BackendProfile)
    case loadedKey(BackendProfile)
    case savedKey(BackendProfile)

    case versionNotChecked
    case versionCheckDoesNotModify
    case checkingVersion
    case checkingVersionDetail
    case updatingVersion
    case updatingVersionDetail
    case versionSummary(ClaudeVersionInfo)
    case versionDetail(ClaudeVersionInfo)
    case updateResult(ClaudeVersionUpdateResult)

    case skillNotScanned
    case scannedSkills(total: Int, personal: Int, plugin: Int, paused: Int)
    case summaryProviderChanged(String)
    case autoSummaryOff
    case autoSummaryOffNeedProvider
    case selectSummaryProvider
    case summaryNeedsKey(BackendProfile)
    case summaryDone(BackendProfile)
    case summaryPartiallyFailed(BackendProfile, failedCount: Int)
    case checkingSkillUpdates
    case skillUpdateCheckFinished(availableCount: Int)
    case skillUninstalled(String)
    case skillResumed(String)
    case skillPaused(String)
    case skillUpdating(String)
    case skillMutationResult(SkillMutationResult)

    func text(languageID: String) -> String {
        switch self {
        case .empty:
            return ""
        case .raw(let message):
            return AppStrings.text(message, languageID: languageID)
        case .currentMode(let profile):
            return AppStrings.isEnglish(languageID)
                ? "Current mode: \(AppStrings.profileName(profile, languageID: languageID))"
                : "当前模式：\(AppStrings.profileName(profile, languageID: languageID))"
        case .selectedMode(let profile):
            return AppStrings.isEnglish(languageID)
                ? "Selected \(AppStrings.profileName(profile, languageID: languageID)). Click Apply to affect new Claude Code sessions."
                : "已选择 \(AppStrings.profileName(profile, languageID: languageID))，点击应用后对新的 Claude Code 会话生效。"
        case .switchedMode(let profile):
            return AppStrings.isEnglish(languageID)
                ? "Switched to \(AppStrings.profileName(profile, languageID: languageID)). New Claude Code sessions will use this mode."
                : "已切换到 \(AppStrings.profileName(profile, languageID: languageID))。新启动的 Claude Code 会使用这个模式。"
        case .customBackendPrompt:
            return AppStrings.text("填写自定义 Anthropic 兼容后端，保存后即可应用。", languageID: languageID)
        case .customBackendLoadFailed(let detail):
            return AppStrings.isEnglish(languageID)
                ? "Could not read custom backend profiles: \(detail)"
                : "无法读取自定义后端配置：\(detail)"
        case .profileDoesNotNeedKey(let profile):
            return AppStrings.isEnglish(languageID)
                ? "\(AppStrings.profileName(profile, languageID: languageID)) does not need an API key."
                : "\(AppStrings.profileName(profile, languageID: languageID)) 不需要 API Key。"
        case .noSavedKey(let profile):
            return AppStrings.isEnglish(languageID)
                ? "No saved API key for \(AppStrings.profileName(profile, languageID: languageID)) in Keychain."
                : "钥匙串里还没有保存 \(AppStrings.profileName(profile, languageID: languageID)) 的 API Key。"
        case .loadedKey(let profile):
            return AppStrings.isEnglish(languageID)
                ? "Loaded \(AppStrings.profileName(profile, languageID: languageID)) API key from Keychain."
                : "已从钥匙串读取 \(AppStrings.profileName(profile, languageID: languageID)) 的 API Key。"
        case .savedKey(let profile):
            return AppStrings.isEnglish(languageID)
                ? "Saved \(AppStrings.profileName(profile, languageID: languageID)) API key to Keychain."
                : "\(AppStrings.profileName(profile, languageID: languageID)) API Key 已保存到钥匙串。"

        case .versionNotChecked:
            return AppStrings.text("Claude Code 版本：未检查", languageID: languageID)
        case .versionCheckDoesNotModify:
            return AppStrings.text("检查不会更新或修改 Claude Code。", languageID: languageID)
        case .checkingVersion:
            return AppStrings.text("正在检查 Claude Code 版本...", languageID: languageID)
        case .checkingVersionDetail:
            return AppStrings.text("正在读取本机版本并查询 npm 最新版本。", languageID: languageID)
        case .updatingVersion:
            return AppStrings.text("正在更新 Claude Code...", languageID: languageID)
        case .updatingVersionDetail:
            return AppStrings.text("后台执行 npm update，不会打开终端窗口。", languageID: languageID)
        case .versionSummary(let info):
            return versionSummaryText(info, languageID: languageID)
        case .versionDetail(let info):
            return versionDetailText(info, languageID: languageID)
        case .updateResult(let result):
            return updateResultText(result, languageID: languageID)

        case .skillNotScanned:
            return AppStrings.isEnglish(languageID) ? "Skills: Not Scanned" : "Skill：未扫描"
        case .scannedSkills(let total, let personal, let plugin, let paused):
            if AppStrings.isEnglish(languageID) {
                let pausedText = paused > 0 ? ", paused \(paused)" : ""
                return "Scanned \(total) Claude Code Skills: personal \(personal), plugin \(plugin)\(pausedText)."
            }
            let pausedText = paused > 0 ? "，已暂停 \(paused)" : ""
            return "已扫描 \(total) 个 Claude Code Skill：个人 \(personal)，插件 \(plugin)\(pausedText)。"
        case .summaryProviderChanged(let providerName):
            let localizedProviderName = AppStrings.text(providerName, languageID: languageID)
            return AppStrings.isEnglish(languageID)
                ? "Summary model changed to \(localizedProviderName). Existing summaries were not regenerated."
                : "摘要模型已切换为 \(localizedProviderName)。现有摘要不会自动重写。"
        case .autoSummaryOff:
            return AppStrings.isEnglish(languageID)
                ? "Auto summaries are off; the list shows original Skill descriptions."
                : "自动摘要已关闭；列表显示 Skill 原始描述。"
        case .autoSummaryOffNeedProvider:
            return AppStrings.isEnglish(languageID)
                ? "Auto summaries are off. Select a summary model before generating a summary."
                : "自动摘要已关闭。请选择一个摘要模型后再生成摘要。"
        case .selectSummaryProvider:
            return AppStrings.isEnglish(languageID)
                ? "Select an available summary model."
                : "请选择一个可用的摘要模型。"
        case .summaryNeedsKey(let profile):
            return AppStrings.isEnglish(languageID)
                ? "Save the \(AppStrings.profileName(profile, languageID: languageID)) API key before generating summaries."
                : "需要先保存 \(AppStrings.profileName(profile, languageID: languageID)) 的 API Key 才能生成摘要。"
        case .summaryDone(let profile):
            return AppStrings.isEnglish(languageID)
                ? "Skill summaries were generated or loaded from cache using \(AppStrings.profileName(profile, languageID: languageID))."
                : "Skill 摘要已通过 \(AppStrings.profileName(profile, languageID: languageID)) 生成或读取缓存。"
        case .summaryPartiallyFailed(let profile, let failedCount):
            return AppStrings.isEnglish(languageID)
                ? "Finished using \(AppStrings.profileName(profile, languageID: languageID)); \(failedCount) summaries failed. Open the failed Skill for details."
                : "已使用 \(AppStrings.profileName(profile, languageID: languageID)) 处理完成；\(failedCount) 条摘要失败，可打开对应 Skill 查看原因。"
        case .checkingSkillUpdates:
            return AppStrings.isEnglish(languageID) ? "Checking Skill updates..." : "正在检查 Skill 更新..."
        case .skillUpdateCheckFinished(let availableCount):
            if AppStrings.isEnglish(languageID) {
                return availableCount == 0
                    ? "Skill update check finished. No personal Skills can be auto-updated."
                    : "Skill update check finished. \(availableCount) personal Skills can be updated."
            }
            return availableCount == 0
                ? "Skill 更新检查完成，没有可自动更新的个人 Skill。"
                : "Skill 更新检查完成，\(availableCount) 个个人 Skill 可更新。"
        case .skillUninstalled(let name):
            return AppStrings.isEnglish(languageID) ? "Uninstalled \(name)." : "已卸载 \(name)。"
        case .skillResumed(let name):
            return AppStrings.isEnglish(languageID) ? "Resumed \(name)." : "已恢复使用 \(name)。"
        case .skillPaused(let name):
            return AppStrings.isEnglish(languageID)
                ? "Paused \(name). Claude Code will not invoke it until you resume it."
                : "已暂停 \(name)。恢复前 Claude Code 不会再调用它。"
        case .skillUpdating(let name):
            return AppStrings.isEnglish(languageID) ? "Updating \(name)..." : "正在更新 \(name)..."
        case .skillMutationResult(let result):
            return skillMutationText(result, languageID: languageID)
        }
    }

    private func versionSummaryText(_ info: ClaudeVersionInfo, languageID: String) -> String {
        guard let currentVersion = info.currentVersion else {
            return AppStrings.text("未找到 Claude Code", languageID: languageID)
        }

        if let latestVersion = info.latestVersion {
            if info.hasUpdate {
                return AppStrings.isEnglish(languageID)
                    ? "Claude Code \(currentVersion) -> \(latestVersion) update available"
                    : "Claude Code \(currentVersion) -> \(latestVersion) 可更新"
            }
            return AppStrings.isEnglish(languageID)
                ? "Claude Code \(currentVersion) is current"
                : "Claude Code \(currentVersion) 已是最新"
        }

        return AppStrings.isEnglish(languageID)
            ? "Claude Code \(currentVersion), latest version unavailable"
            : "Claude Code \(currentVersion)，未能获取最新版本"
    }

    private func versionDetailText(_ info: ClaudeVersionInfo, languageID: String) -> String {
        guard info.currentVersion != nil else {
            return AppStrings.text("请先确认终端里可以运行 claude，再重新检查版本。", languageID: languageID)
        }

        if info.hasUpdate {
            return AppStrings.isEnglish(languageID)
                ? "You can run: npm update -g @anthropic-ai/claude-code. You can also run claude doctor first."
                : "可在终端运行：npm update -g @anthropic-ai/claude-code。也可以先运行 claude doctor 查看自动更新状态。"
        }

        if info.latestVersion == nil {
            return AppStrings.isEnglish(languageID)
                ? "Local claude was found. If npm lookup failed, run npm view @anthropic-ai/claude-code version in Terminal."
                : "已找到本机 claude；网络或 npm 查询失败时，可以在终端运行 npm view @anthropic-ai/claude-code version。"
        }

        return AppStrings.isEnglish(languageID)
            ? "Install path: \(info.claudePath ?? "Unknown")"
            : "安装路径：\(info.claudePath ?? "未识别")"
    }

    private func updateResultText(_ result: ClaudeVersionUpdateResult, languageID: String) -> String {
        if result.succeeded {
            return AppStrings.isEnglish(languageID)
                ? "Claude Code update finished. Version was checked again."
                : "Claude Code 更新完成，已重新检查版本。"
        }

        let message = AppStrings.text(result.message, languageID: languageID)
        if AppStrings.isEnglish(languageID), message == result.message, result.message.hasPrefix("更新失败：") {
            return "Update failed: \(result.message.dropFirst("更新失败：".count))"
        }
        return message
    }

    private func skillMutationText(_ result: SkillMutationResult, languageID: String) -> String {
        let message = AppStrings.text(result.message, languageID: languageID)
        if AppStrings.isEnglish(languageID), message == result.message, result.message.hasPrefix("更新失败：") {
            return "Update failed: \(result.message.dropFirst("更新失败：".count))"
        }
        return message
    }
}
