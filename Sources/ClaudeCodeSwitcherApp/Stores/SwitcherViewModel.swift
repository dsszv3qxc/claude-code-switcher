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
            skillSummaries.removeAll()
            refreshSkills()
        }
    }
    @Published var apiKey: String = ""
    @Published var statusMessage: String = ""
    @Published var versionSummary: String = "Claude Code 版本：未检查"
    @Published var versionDetail: String = "检查不会更新或修改 Claude Code。"
    @Published var selectedSection: AppSection = .backend
    @Published var skills: [ClaudeSkillRecord] = []
    @Published var selectedSkillID: ClaudeSkillRecord.ID?
    @Published var selectedSkillCategory: String = "全部分类" {
        didSet {
            guard oldValue != selectedSkillCategory else { return }
            normalizeSelectedSkill()
        }
    }
    @Published var skillStatusMessage: String = "Skill：未扫描"
    @Published var skillUpdateStates: [ClaudeSkillRecord.ID: SkillUpdateState] = [:]
    @Published var skillSummaries: [ClaudeSkillRecord.ID: String] = [:]
    @Published var isSummarizingSkills = false
    @Published var isBusy = false
    @Published var isCheckingVersion = false
    @Published var isUpdatingVersion = false
    @Published var canUpdateClaudeCode = false
    @Published var isRefreshingSkills = false
    @Published var isCheckingSkillUpdates = false
    @Published var isMutatingSkill = false

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

    var summaryProviderName: String {
        guard selectedSummaryProfileID != Self.summaryDisabledID else {
            return "关闭自动摘要"
        }
        return backendProfiles.first { $0.id == selectedSummaryProfileID }?.displayName ?? "未选择"
    }

    func refresh() {
        do {
            let document = try settingsStore.load()
            currentProfile = document.detectedProfile(in: backendProfiles)
            selectedProfileID = currentProfile.id
            isAddingCustomBackend = false
            loadKeyForSelectedProfileIfAvailable()
            statusMessage = "当前模式：\(currentProfile.displayName)"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func refreshSkills() {
        guard !isRefreshingSkills else { return }
        isRefreshingSkills = true
        defer { isRefreshingSkills = false }

        do {
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

            let pausedSuffix = pausedSkillCount > 0 ? "，已暂停 \(pausedSkillCount)" : ""
            skillStatusMessage = "已扫描 \(scanned.count) 个 Claude Code Skill：个人 \(personalSkillCount)，插件 \(pluginSkillCount)\(pausedSuffix)。"
            summarizeMissingSkills(scanned)
        } catch {
            skillStatusMessage = error.localizedDescription
        }
    }

    func summaryText(for skill: ClaudeSkillRecord) -> String {
        if let summary = skillSummaries[skill.id] {
            return summary
        }
        if selectedSummaryProfileID == Self.summaryDisabledID {
            return skill.description.isEmpty ? "未生成摘要" : skill.description
        }
        return "正在生成中文摘要..."
    }

    func usageText(for skill: ClaudeSkillRecord) -> String {
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

    func regenerateSelectedSkillSummary() {
        guard let selectedSkill else { return }
        guard selectedSummaryProfileID != Self.summaryDisabledID else {
            skillStatusMessage = "自动摘要已关闭。请选择一个摘要模型后再重写摘要。"
            return
        }
        skillSummaries[selectedSkill.id] = "正在重新生成中文摘要..."
        summarizeMissingSkills([selectedSkill], force: true)
    }

    func loadSavedKey() {
        do {
            guard selectedProfile.needsAPIKey else {
                statusMessage = "\(selectedProfile.displayName) 不需要 API Key。"
                return
            }
            guard let saved = try keychainStore.readAPIKey(for: selectedProfile), !saved.isEmpty else {
                statusMessage = "钥匙串里还没有保存 \(selectedProfile.displayName) 的 API Key。"
                return
            }
            apiKey = saved
            statusMessage = "已从钥匙串读取 \(selectedProfile.displayName) 的 API Key。"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func saveKey() {
        do {
            guard selectedProfile.needsAPIKey else {
                statusMessage = "\(selectedProfile.displayName) 不需要 API Key。"
                return
            }
            let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw SwitcherError.missingAPIKey
            }
            try keychainStore.saveAPIKey(trimmed, for: selectedProfile)
            statusMessage = "\(selectedProfile.displayName) API Key 已保存到钥匙串。"
        } catch {
            statusMessage = error.localizedDescription
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
            statusMessage = "已切换到 \(currentProfile.displayName)。新启动的 Claude Code 会使用这个模式。"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func selectProfile(_ profile: BackendProfile) {
        isAddingCustomBackend = false
        selectedProfileID = profile.id
        apiKey = ""
        loadKeyForSelectedProfileIfAvailable()
        statusMessage = profile.id == currentProfile.id
            ? "当前模式：\(profile.displayName)"
            : "已选择 \(profile.displayName)，点击应用后对新的 Claude Code 会话生效。"
    }

    func beginAddingCustomBackend() {
        isAddingCustomBackend = true
        selectedProfileID = Self.newCustomProfileID
        customBackendDraft = .example
        apiKey = ""
        statusMessage = "填写自定义 Anthropic 兼容后端，保存后即可应用。"
    }

    func cancelAddingCustomBackend() {
        isAddingCustomBackend = false
        selectedProfileID = currentProfile.id
        loadKeyForSelectedProfileIfAvailable()
    }

    func checkClaudeVersion() {
        guard !isCheckingVersion else { return }
        isCheckingVersion = true
        canUpdateClaudeCode = false
        versionSummary = "正在检查 Claude Code 版本..."
        versionDetail = "正在读取本机版本并查询 npm 最新版本。"

        Task {
            let info = await versionChecker.check()
            await MainActor.run {
                versionSummary = info.summary
                versionDetail = info.detail
                canUpdateClaudeCode = info.hasUpdate
                isCheckingVersion = false
            }
        }
    }

    func updateClaudeCodeVersion() {
        guard canUpdateClaudeCode, !isUpdatingVersion else { return }
        isUpdatingVersion = true
        canUpdateClaudeCode = false
        versionSummary = "正在更新 Claude Code..."
        versionDetail = "后台执行 npm update，不会打开终端窗口。"

        Task {
            let updateResult = await versionChecker.update()
            let info = await versionChecker.check()
            await MainActor.run {
                versionSummary = info.summary
                versionDetail = updateResult.succeeded ? updateResult.message : updateResult.message
                canUpdateClaudeCode = info.hasUpdate
                isUpdatingVersion = false
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
            skillStatusMessage = "已卸载 \(selectedSkill.commandName)。"
            refreshSkills()
        } catch {
            skillStatusMessage = error.localizedDescription
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
                skillStatusMessage = "已恢复使用 \(selectedName)。"
            } else {
                try skillManager.pause(selectedSkill)
                refreshSkills()
                selectedSkillID = selectedID
                skillStatusMessage = "已暂停 \(selectedName)。恢复前 Claude Code 不会再调用它。"
            }
        } catch {
            skillStatusMessage = error.localizedDescription
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
        skillStatusMessage = "正在更新 \(selectedSkill.commandName)..."

        Task {
            let result = await skillManager.update(selectedSkill)
            await MainActor.run {
                skillStatusMessage = result.message
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
            statusMessage = "无法读取自定义后端配置：\(error.localizedDescription)"
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
        skillStatusMessage = "正在检查 Skill 更新..."
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
                skillStatusMessage = availableCount == 0
                    ? "Skill 更新检查完成，没有可自动更新的个人 Skill。"
                    : "Skill 更新检查完成，\(availableCount) 个个人 Skill 可更新。"
                isCheckingSkillUpdates = false
            }
        }
    }

    private func summarizeMissingSkills(_ records: [ClaudeSkillRecord], force: Bool = false) {
        guard !records.isEmpty else { return }
        let targets = records.filter { force || skillSummaries[$0.id] == nil }
        guard !targets.isEmpty else { return }

        guard selectedSummaryProfileID != Self.summaryDisabledID else {
            isSummarizingSkills = false
            skillStatusMessage = "自动摘要已关闭；列表显示 Skill 原始描述。"
            return
        }

        guard let summaryProfile = backendProfiles.first(where: { $0.id == selectedSummaryProfileID && $0.needsAPIKey }) else {
            isSummarizingSkills = false
            skillStatusMessage = "请选择一个可用的摘要模型。"
            return
        }

        isSummarizingSkills = true
        let keyFromField = summaryProfile.id == selectedProfile.id ? apiKey.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let summaryAPIKey = !keyFromField.isEmpty ? keyFromField : (try? keychainStore.readAPIKey(for: summaryProfile))

        Task {
            var needsKey = false
            for record in targets {
                let result = await skillSummaryService.summary(for: record, provider: summaryProfile, apiKey: summaryAPIKey)
                await MainActor.run {
                    skillSummaries[record.id] = result.text
                    if case .needsAPIKey = result {
                        needsKey = true
                    }
                }
                if needsKey {
                    break
                }
            }

            await MainActor.run {
                if needsKey {
                    for record in targets where skillSummaries[record.id] == nil {
                        skillSummaries[record.id] = record.description.isEmpty ? "需要先保存摘要模型 API Key。" : record.description
                    }
                    skillStatusMessage = "需要先保存 \(summaryProfile.displayName) 的 API Key 才能生成中文摘要。"
                } else {
                    skillStatusMessage = "中文 Skill 摘要已通过 \(summaryProfile.displayName) 生成或读取缓存。"
                }
                isSummarizingSkills = false
            }
        }
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
    private static let summaryProfileDefaultsKey = "SkillSummaryProfileID"
}
