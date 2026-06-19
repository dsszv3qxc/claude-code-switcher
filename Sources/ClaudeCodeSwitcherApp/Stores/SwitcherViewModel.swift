import Foundation
import ClaudeCodeSwitcherCore

@MainActor
final class SwitcherViewModel: ObservableObject {
    @Published var backendProfiles: [BackendProfile] = BackendProfile.builtIns
    @Published var currentProfile: BackendProfile = .claudeSubscription
    @Published var selectedProfileID: BackendProfile.ID = BackendProfile.claudeSubscription.id
    @Published var isAddingCustomBackend = false
    @Published var customBackendDraft = CustomBackendDraft.example
    @Published var selectedSummaryProfileID: String = SwitcherViewModel.summaryDisabledID {
        didSet {
            guard oldValue != selectedSummaryProfileID else { return }
            UserDefaults.standard.set(selectedSummaryProfileID, forKey: Self.summaryProfileDefaultsKey)
            loadCachedSkillSummaries(for: skills, languageID: currentLanguageID)
            skillStatusMessage = .summaryProviderChanged(summaryProviderName(languageID: currentLanguageID))
        }
    }
    @Published var apiKey: String = ""
    @Published var statusMessage: AppMessage = .empty
    @Published var versionSummary: AppMessage = .versionNotChecked
    @Published var versionDetail: AppMessage = .versionCheckDoesNotModify
    @Published var selectedSection: AppSection = .backend
    @Published var skills: [ClaudeSkillRecord] = []
    @Published var selectedSkillID: ClaudeSkillRecord.ID?
    @Published var selectedSkillCategory: String = "全部分类" {
        didSet {
            guard oldValue != selectedSkillCategory else { return }
            normalizeSelectedSkill()
        }
    }
    @Published var skillStatusMessage: AppMessage = .skillNotScanned
    @Published var skillUpdateStates: [ClaudeSkillRecord.ID: SkillUpdateState] = [:]
    @Published var skillSummaries: [String: String] = [:]
    @Published var isSummarizingSkills = false
    @Published var isBusy = false
    @Published var isCheckingVersion = false
    @Published var isUpdatingVersion = false
    @Published var canUpdateClaudeCode = false
    @Published var isInstallingVersion = false
    @Published var canInstallClaudeCode = false
    @Published var isRefreshingSkills = false
    @Published var isCheckingSkillUpdates = false
    @Published var isMutatingSkill = false
    @Published var generatedSummaryKeys: Set<String> = []

    private let settingsStore: ClaudeSettingsStore
    private let keychainStore: KeychainStore
    private let versionChecker: ClaudeVersionChecker
    private let skillManager: ClaudeSkillManager
    private let skillSummaryService: SkillSummaryService
    private let backendProfileStore: BackendProfileStore

    init(
        settingsStore: ClaudeSettingsStore = ClaudeSettingsStore(),
        keychainStore: KeychainStore = KeychainStore(),
        versionChecker: ClaudeVersionChecker = ClaudeVersionChecker(),
        skillManager: ClaudeSkillManager = ClaudeSkillManager(),
        skillSummaryService: SkillSummaryService = SkillSummaryService(),
        backendProfileStore: BackendProfileStore = BackendProfileStore()
    ) {
        self.settingsStore = settingsStore
        self.keychainStore = keychainStore
        self.versionChecker = versionChecker
        self.skillManager = skillManager
        self.skillSummaryService = skillSummaryService
        self.backendProfileStore = backendProfileStore
        self.selectedSummaryProfileID = UserDefaults.standard.string(forKey: Self.summaryProfileDefaultsKey) ?? Self.summaryDisabledID
        loadBackendProfiles()
        refresh()
        refreshSkills()
    }

    var selectedSkill: ClaudeSkillRecord? {
        guard let selectedSkillID else {
            return nil
        }
        return filteredSkills.first { $0.id == selectedSkillID }
    }

    var personalSkillCount: Int {
        skills.filter { $0.scope == .personal }.count
    }

    var pluginSkillCount: Int {
        skills.filter { $0.scope == .plugin }.count
    }

    var pausedSkillCount: Int {
        skills.filter(\.isPaused).count
    }

    var skillCategories: [String] {
        [Self.allSkillCategoriesLabel] + sortedCategories(in: skills)
    }

    var filteredSkills: [ClaudeSkillRecord] {
        guard selectedSkillCategory != Self.allSkillCategoriesLabel else {
            return skills
        }
        return skills.filter { $0.category == selectedSkillCategory }
    }

    var filteredSkillCount: Int {
        filteredSkills.count
    }

    var groupedSkills: [(category: String, skills: [ClaudeSkillRecord])] {
        let grouped = Dictionary(grouping: filteredSkills, by: \.category)
        return grouped.keys.sorted { left, right in
            categoryRank(left) < categoryRank(right)
        }.map { category in
            (
                category,
                grouped[category, default: []].sorted {
                    $0.commandName.localizedStandardCompare($1.commandName) == .orderedAscending
                }
            )
        }
    }

    var visibleBackendProfiles: [BackendProfile] {
        if backendProfiles.contains(where: { $0.id == currentProfile.id }) {
            return backendProfiles
        }
        return backendProfiles + [currentProfile]
    }

    var selectedProfile: BackendProfile {
        visibleBackendProfiles.first { $0.id == selectedProfileID } ?? .claudeSubscription
    }

    var isCurrentSelection: Bool {
        currentProfile.id == selectedProfile.id
    }

    var selectableSummaryProfiles: [BackendProfile] {
        backendProfiles.filter(\.needsAPIKey)
    }

    func summaryProviderName(languageID: String) -> String {
        guard selectedSummaryProfileID != Self.summaryDisabledID else {
            return AppStrings.text("关闭自动摘要", languageID: languageID)
        }
        guard let profile = backendProfiles.first(where: { $0.id == selectedSummaryProfileID }) else {
            return AppStrings.text("未选择", languageID: languageID)
        }
        return AppStrings.profileName(profile, languageID: languageID)
    }

    func statusText(languageID: String) -> String {
        if statusMessage == .empty {
            return AppMessage.currentMode(currentProfile).text(languageID: languageID)
        }
        return statusMessage.text(languageID: languageID)
    }

    func skillStatusText(languageID: String) -> String {
        skillStatusMessage.text(languageID: languageID)
    }

    func versionSummaryText(languageID: String) -> String {
        versionSummary.text(languageID: languageID)
    }

    func versionDetailText(languageID: String) -> String {
        versionDetail.text(languageID: languageID)
    }

    func refresh() {
        do {
            let document = try settingsStore.load()
            currentProfile = document.detectedProfile(in: backendProfiles)
            selectedProfileID = currentProfile.id
            isAddingCustomBackend = false
            loadKeyForSelectedProfileIfAvailable()
            statusMessage = .currentMode(currentProfile)
        } catch {
            statusMessage = .raw(error.localizedDescription)
        }
    }

    func refreshSkills() {
        guard !isRefreshingSkills else { return }
        isRefreshingSkills = true
        defer { isRefreshingSkills = false }

        do {
            let existingSkillIDs = Set(skills.map(\.id))
            let scanned = try skillManager.scan()
            skills = scanned
            skillUpdateStates = Dictionary(
                uniqueKeysWithValues: scanned.map { skill in
                    (skill.id, skillUpdateStates[skill.id] ?? .notChecked)
                }
            )

            if let selectedSkillID, scanned.contains(where: { $0.id == selectedSkillID }) {
                self.selectedSkillID = selectedSkillID
            } else {
                selectedSkillID = scanned.first?.id
            }
            normalizeSelectedSkill()

            skillStatusMessage = .scannedSkills(
                total: scanned.count,
                personal: personalSkillCount,
                plugin: pluginSkillCount,
                paused: pausedSkillCount
            )
            loadCachedSkillSummaries(for: scanned, languageID: currentLanguageID)

            let newSkills = existingSkillIDs.isEmpty ? [] : scanned.filter { !existingSkillIDs.contains($0.id) }
            generateSummaries(for: newSkills, languageID: currentLanguageID)
        } catch {
            skillStatusMessage = .raw(error.localizedDescription)
        }
    }

    func summaryText(for skill: ClaudeSkillRecord, languageID: String) -> String {
        if let summary = skillSummaries[summaryKey(for: skill, languageID: languageID)] {
            return summary
        }
        return skill.description.isEmpty ? AppStrings.text("未生成摘要", languageID: languageID) : skill.description
    }

    func hasGeneratedSummary(for skill: ClaudeSkillRecord, languageID: String) -> Bool {
        generatedSummaryKeys.contains(summaryKey(for: skill, languageID: languageID))
    }

    func usageText(for skill: ClaudeSkillRecord, languageID: String) -> String {
        if languageID.hasPrefix("en") {
            return englishUsageText(for: skill)
        }

        let slashCommand = "/\(skill.commandName)"
        var parts: [String] = []

        if skill.isPaused {
            parts.append("已暂停：Claude Code 目前不会发现或调用它。恢复使用后，新的 Claude Code 会话会重新看到这个 Skill；已打开的会话通常也会通过文件监听感知变化。")
        }

        if skill.disableModelInvocation {
            parts.append("手动调用型：这个 Skill 禁用了模型自动调用，需要在输入框里使用 \(slashCommand)，或在需求里明确点名 \(skill.commandName)。")
        } else if skill.commandName.lowercased().hasPrefix("superpowers:") {
            parts.append("自动触发型：Superpowers 这类 Skill 通常由 Claude Code 按任务场景自动选择；如果你想确保使用，可以直接输入 \(slashCommand)，或在需求里明确说使用 \(skill.commandName)。")
        } else if skill.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("建议手动点名：这个 Skill 没有清晰描述，Claude Code 很难自动判断何时使用。可以直接输入 \(slashCommand)，或在需求里明确提到它的名字。")
        } else {
            parts.append("按需触发型：Claude Code 会根据 description/when_to_use 判断是否自动加载。想确保使用时，可以直接输入 \(slashCommand)，或在需求里明确提到 \(skill.commandName)。")
        }

        return parts.joined(separator: "\n\n")
    }

    func languageDidChange(to languageID: String) {
        loadCachedSkillSummaries(for: skills, languageID: languageID)
    }

    func regenerateSelectedSkillSummary(languageID: String) {
        guard let selectedSkill else { return }
        guard selectedSummaryProfileID != Self.summaryDisabledID else {
            skillStatusMessage = .autoSummaryOffNeedProvider
            return
        }
        let key = summaryKey(for: selectedSkill, languageID: languageID)
        generatedSummaryKeys.remove(key)
        skillSummaries[key] = AppStrings.text("正在重新生成摘要...", languageID: languageID)
        generateSummaries(for: [selectedSkill], languageID: languageID, force: true)
    }

    func loadSavedKey() {
        do {
            guard selectedProfile.needsAPIKey else {
                statusMessage = .profileDoesNotNeedKey(selectedProfile)
                return
            }
            guard let saved = try keychainStore.readAPIKey(for: selectedProfile), !saved.isEmpty else {
                statusMessage = .noSavedKey(selectedProfile)
                return
            }
            apiKey = saved
            statusMessage = .loadedKey(selectedProfile)
        } catch {
            statusMessage = .raw(error.localizedDescription)
        }
    }

    func saveKey() {
        do {
            guard selectedProfile.needsAPIKey else {
                statusMessage = .profileDoesNotNeedKey(selectedProfile)
                return
            }
            let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw SwitcherError.missingAPIKey
            }
            try keychainStore.saveAPIKey(trimmed, for: selectedProfile)
            statusMessage = .savedKey(selectedProfile)
        } catch {
            statusMessage = .raw(error.localizedDescription)
        }
    }

    func applySelectedMode() {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        do {
            let profileToApply = try prepareSelectedProfileForApply()
            let keyForMode: String?
            if !profileToApply.needsAPIKey {
                keyForMode = nil
            } else {
                let trimmed = (isAddingCustomBackend ? customBackendDraft.apiKey : apiKey)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    keyForMode = trimmed
                    try keychainStore.saveAPIKey(trimmed, for: profileToApply)
                } else if let saved = try keychainStore.readAPIKey(for: profileToApply), !saved.isEmpty {
                    keyForMode = saved
                    apiKey = saved
                } else {
                    throw SwitcherError.missingAPIKey
                }
            }

            var document = try settingsStore.load()
            try document.apply(profile: profileToApply, apiKey: keyForMode)
            try settingsStore.save(document)
            currentProfile = document.detectedProfile(in: backendProfiles)
            selectedProfileID = currentProfile.id
            isAddingCustomBackend = false
            statusMessage = .switchedMode(currentProfile)
        } catch {
            statusMessage = .raw(error.localizedDescription)
        }
    }

    func selectProfile(_ profile: BackendProfile) {
        isAddingCustomBackend = false
        selectedProfileID = profile.id
        apiKey = ""
        loadKeyForSelectedProfileIfAvailable()
        statusMessage = profile.id == currentProfile.id
            ? .currentMode(profile)
            : .selectedMode(profile)
    }

    func beginAddingCustomBackend() {
        isAddingCustomBackend = true
        selectedProfileID = Self.newCustomProfileID
        customBackendDraft = .example
        apiKey = ""
        statusMessage = .customBackendPrompt
    }

    func cancelAddingCustomBackend() {
        isAddingCustomBackend = false
        selectedProfileID = currentProfile.id
        loadKeyForSelectedProfileIfAvailable()
    }

    func checkClaudeVersion() {
        guard !isCheckingVersion, !isUpdatingVersion, !isInstallingVersion else { return }
        isCheckingVersion = true
        canUpdateClaudeCode = false
        canInstallClaudeCode = false
        versionSummary = .checkingVersion
        versionDetail = .checkingVersionDetail

        Task {
            let info = await versionChecker.check()
            await MainActor.run {
                versionSummary = .versionSummary(info)
                versionDetail = .versionDetail(info)
                canUpdateClaudeCode = info.hasUpdate
                canInstallClaudeCode = info.canInstall
                isCheckingVersion = false
            }
        }
    }

    func updateClaudeCodeVersion() {
        guard canUpdateClaudeCode, !isUpdatingVersion else { return }
        isUpdatingVersion = true
        canUpdateClaudeCode = false
        canInstallClaudeCode = false
        versionSummary = .updatingVersion
        versionDetail = .updatingVersionDetail

        Task {
            let updateResult = await versionChecker.update()
            let info = await versionChecker.check()
            await MainActor.run {
                versionSummary = .versionSummary(info)
                versionDetail = updateResult.succeeded ? .versionDetail(info) : .updateResult(updateResult)
                canUpdateClaudeCode = info.hasUpdate
                canInstallClaudeCode = info.canInstall
                isUpdatingVersion = false
            }
        }
    }

    func installClaudeCodeVersion() {
        guard canInstallClaudeCode, !isInstallingVersion, !isCheckingVersion, !isUpdatingVersion else { return }
        isInstallingVersion = true
        canInstallClaudeCode = false
        canUpdateClaudeCode = false
        versionSummary = .installingVersion
        versionDetail = .installingVersionDetail

        Task {
            let installResult = await versionChecker.install()
            let info = await versionChecker.check()
            await MainActor.run {
                versionSummary = .versionSummary(info)
                versionDetail = installResult.succeeded ? .versionDetail(info) : .installResult(installResult)
                canUpdateClaudeCode = info.hasUpdate
                canInstallClaudeCode = info.canInstall
                isInstallingVersion = false
            }
        }
    }

    func revealSelectedSkill() {
        guard let selectedSkill else { return }
        skillManager.reveal(selectedSkill)
    }

    func uninstallSelectedSkill() {
        guard let selectedSkill, selectedSkill.isUninstallable, !isMutatingSkill else { return }
        isMutatingSkill = true
        defer { isMutatingSkill = false }

        do {
            try skillManager.uninstall(selectedSkill)
            skillStatusMessage = .skillUninstalled(selectedSkill.commandName)
            refreshSkills()
        } catch {
            skillStatusMessage = .raw(error.localizedDescription)
        }
    }

    func toggleSelectedSkillPaused() {
        guard let selectedSkill, !isMutatingSkill else { return }
        isMutatingSkill = true
        defer { isMutatingSkill = false }

        let selectedID = selectedSkill.id
        let selectedName = selectedSkill.commandName

        do {
            if selectedSkill.isPaused {
                try skillManager.resume(selectedSkill)
                refreshSkills()
                selectedSkillID = selectedID
                skillStatusMessage = .skillResumed(selectedName)
            } else {
                try skillManager.pause(selectedSkill)
                refreshSkills()
                selectedSkillID = selectedID
                skillStatusMessage = .skillPaused(selectedName)
            }
        } catch {
            skillStatusMessage = .raw(error.localizedDescription)
        }
    }

    func checkSelectedSkillUpdate() {
        guard let selectedSkill, !isCheckingSkillUpdates else { return }
        checkSkillUpdates([selectedSkill])
    }

    func checkAllSkillUpdates() {
        guard !isCheckingSkillUpdates else { return }
        checkSkillUpdates(filteredSkills)
    }

    func updateSelectedSkill() {
        guard let selectedSkill, !isMutatingSkill else { return }
        guard skillUpdateStates[selectedSkill.id]?.canUpdate == true else { return }

        isMutatingSkill = true
        skillStatusMessage = .skillUpdating(selectedSkill.commandName)

        Task {
            let result = await skillManager.update(selectedSkill)
            await MainActor.run {
                skillStatusMessage = .skillMutationResult(result)
                isMutatingSkill = false
                refreshSkills()
                if result.succeeded {
                    skillUpdateStates[selectedSkill.id] = .current("刚刚完成更新。")
                }
            }
        }
    }

    private func loadBackendProfiles() {
        do {
            let customProfiles = try backendProfileStore.loadCustomProfiles()
            backendProfiles = BackendProfile.builtIns + customProfiles
            if selectedSummaryProfileID != Self.summaryDisabledID,
               !backendProfiles.contains(where: { $0.id == selectedSummaryProfileID && $0.needsAPIKey }) {
                selectedSummaryProfileID = Self.summaryDisabledID
            }
        } catch {
            backendProfiles = BackendProfile.builtIns
            statusMessage = .customBackendLoadFailed(error.localizedDescription)
        }
    }

    private func loadKeyForSelectedProfileIfAvailable() {
        guard selectedProfile.needsAPIKey else {
            apiKey = ""
            return
        }
        apiKey = (try? keychainStore.readAPIKey(for: selectedProfile)) ?? ""
    }

    private func prepareSelectedProfileForApply() throws -> BackendProfile {
        guard isAddingCustomBackend else {
            return selectedProfile
        }

        let profile = try customBackendDraft.makeProfile()
        var customProfiles = backendProfiles.filter { !$0.isBuiltIn }
        customProfiles.append(profile)
        try backendProfileStore.saveCustomProfiles(customProfiles)
        backendProfiles = BackendProfile.builtIns + customProfiles
        selectedProfileID = profile.id
        apiKey = customBackendDraft.apiKey
        return profile
    }

    private func checkSkillUpdates(_ records: [ClaudeSkillRecord]) {
        isCheckingSkillUpdates = true
        skillStatusMessage = .checkingSkillUpdates
        for record in records {
            skillUpdateStates[record.id] = .checking
        }

        Task {
            var results: [ClaudeSkillRecord.ID: SkillUpdateState] = [:]
            for record in records {
                let result = await skillManager.checkUpdate(for: record)
                results[record.id] = result.state
            }

            await MainActor.run {
                for (id, state) in results {
                    skillUpdateStates[id] = state
                }
                let availableCount = results.values.filter(\.canUpdate).count
                skillStatusMessage = .skillUpdateCheckFinished(availableCount: availableCount)
                isCheckingSkillUpdates = false
            }
        }
    }

    private func generateSummaries(for records: [ClaudeSkillRecord], languageID: String, force: Bool = false) {
        guard !records.isEmpty else { return }
        let providerID = selectedSummaryProfileID
        let targets = records.filter { record in
            let key = summaryKey(for: record, providerID: providerID, languageID: languageID)
            return force || (!generatedSummaryKeys.contains(key) && skillSummaries[key] == nil)
        }
        guard !targets.isEmpty else { return }

        guard providerID != Self.summaryDisabledID else {
            isSummarizingSkills = false
            if force {
                skillStatusMessage = .autoSummaryOffNeedProvider
            }
            return
        }

        guard let summaryProfile = backendProfiles.first(where: { $0.id == providerID && $0.needsAPIKey }) else {
            isSummarizingSkills = false
            skillStatusMessage = .selectSummaryProvider
            return
        }

        isSummarizingSkills = true
        let keyFromField = summaryProfile.id == selectedProfile.id ? apiKey.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let summaryAPIKey = !keyFromField.isEmpty ? keyFromField : (try? keychainStore.readAPIKey(for: summaryProfile))

        Task {
            var needsKey = false
            var failureCount = 0
            for record in targets {
                let summaryKey = summaryKey(for: record, providerID: providerID, languageID: languageID)
                let result = await skillSummaryService.summary(
                    for: record,
                    provider: summaryProfile,
                    apiKey: summaryAPIKey,
                    languageID: languageID
                )
                await MainActor.run {
                    skillSummaries[summaryKey] = result.text
                    switch result {
                    case .ready:
                        generatedSummaryKeys.insert(summaryKey)
                    case .needsAPIKey:
                        generatedSummaryKeys.remove(summaryKey)
                        needsKey = true
                    case .failed:
                        generatedSummaryKeys.remove(summaryKey)
                        failureCount += 1
                    }
                }
                if needsKey {
                    break
                }
            }

            await MainActor.run {
                if needsKey {
                    for record in targets where skillSummaries[summaryKey(for: record, providerID: providerID, languageID: languageID)] == nil {
                        let missingKey = summaryKey(for: record, providerID: providerID, languageID: languageID)
                        skillSummaries[missingKey] = record.description.isEmpty
                            ? AppStrings.text("需要先保存摘要模型 API Key。", languageID: languageID)
                            : record.description
                        generatedSummaryKeys.remove(missingKey)
                    }
                    skillStatusMessage = .summaryNeedsKey(summaryProfile)
                } else {
                    skillStatusMessage = failureCount > 0
                        ? .summaryPartiallyFailed(summaryProfile, failedCount: failureCount)
                        : .summaryDone(summaryProfile)
                }
                isSummarizingSkills = false
            }
        }
    }

    private func loadCachedSkillSummaries(for records: [ClaudeSkillRecord], languageID: String) {
        guard selectedSummaryProfileID != Self.summaryDisabledID,
              let summaryProfile = backendProfiles.first(where: { $0.id == selectedSummaryProfileID && $0.needsAPIKey }) else {
            return
        }

        for record in records {
            guard let cached = skillSummaryService.cachedSummary(
                for: record,
                provider: summaryProfile,
                languageID: languageID
            ) else {
                continue
            }
            let key = summaryKey(for: record, providerID: summaryProfile.id, languageID: languageID)
            skillSummaries[key] = cached
            generatedSummaryKeys.insert(key)
        }
    }

    private func summaryKey(for skill: ClaudeSkillRecord, languageID: String) -> String {
        summaryKey(for: skill, providerID: selectedSummaryProfileID, languageID: languageID)
    }

    private func summaryKey(for skill: ClaudeSkillRecord, providerID: String, languageID: String) -> String {
        "\(languageID)|\(providerID)|\(skill.id)"
    }

    private var currentLanguageID: String {
        UserDefaults.standard.string(forKey: Self.languageDefaultsKey) ?? Self.defaultLanguageID
    }

    private func categoryRank(_ category: String) -> String {
        let order = [
            "界面优化",
            "Superpowers",
            "工程质量",
            "macOS 应用开发",
            "GitHub 与代码协作",
            "文档与数据",
            "浏览器自动化",
            "图像与多媒体",
            "Skill / Plugin 开发",
            "通信连接器",
            "Claude Code"
        ]
        let index = order.firstIndex(of: category) ?? order.count
        return "\(String(format: "%03d", index))-\(category)"
    }

    private func sortedCategories(in records: [ClaudeSkillRecord]) -> [String] {
        Array(Set(records.map(\.category))).sorted { left, right in
            categoryRank(left) < categoryRank(right)
        }
    }

    private func normalizeSelectedSkill() {
        if !skillCategories.contains(selectedSkillCategory) {
            selectedSkillCategory = Self.allSkillCategoriesLabel
            return
        }

        guard !filteredSkills.isEmpty else {
            selectedSkillID = nil
            return
        }

        if let selectedSkillID, filteredSkills.contains(where: { $0.id == selectedSkillID }) {
            return
        }

        selectedSkillID = filteredSkills.first?.id
    }

    static let allSkillCategoriesLabel = "全部分类"
    static let newCustomProfileID = "new.custom.backend"
    static let summaryDisabledID = "summary.disabled"
    static let defaultLanguageID = "zh-Hans"
    static let languageDefaultsKey = "AppLanguageID"
    private static let summaryProfileDefaultsKey = "SkillSummaryProfileID"

    private func englishUsageText(for skill: ClaudeSkillRecord) -> String {
        let slashCommand = "/\(skill.commandName)"
        var parts: [String] = []

        if skill.isPaused {
            parts.append("Paused: Claude Code will not discover or invoke this Skill right now. Resume it and new Claude Code sessions will see it again.")
        }

        if skill.disableModelInvocation {
            parts.append("Manual use: this Skill disables model invocation. Use \(slashCommand), or explicitly mention \(skill.commandName) in your request.")
        } else if skill.commandName.lowercased().hasPrefix("superpowers:") {
            parts.append("Auto-triggered: Superpowers Skills are usually selected by Claude Code based on the task. To force it, use \(slashCommand) or explicitly mention \(skill.commandName).")
        } else if skill.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("Manual mention recommended: this Skill has no clear description, so Claude Code may not know when to load it. Use \(slashCommand) or mention its name.")
        } else {
            parts.append("On-demand: Claude Code uses description/when_to_use to decide whether to load this Skill. To make sure it is used, enter \(slashCommand) or mention \(skill.commandName).")
        }

        return parts.joined(separator: "\n\n")
    }
}
