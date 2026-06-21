import SwiftUI
import ClaudeCodeSwitcherCore

struct ContentView: View {
    @ObservedObject var viewModel: SwitcherViewModel
    @Binding var languageID: String
    @State private var showingUninstallConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header

            contentArea
                .frame(height: 620, alignment: .top)
        }
        .padding(.horizontal, 34)
        .padding(.top, 30)
        .padding(.bottom, 28)
        .background(Color(nsColor: .windowBackgroundColor))
        .background(WindowTitleUpdater(title: windowTitle))
        .environment(\.locale, Locale(identifier: languageID))
        .onChange(of: languageID) { _, _ in
            viewModel.languageDidChange(to: languageID)
        }
        .animation(.easeInOut(duration: 0.18), value: viewModel.selectedProfileID)
        .animation(.easeInOut(duration: 0.18), value: viewModel.isAddingCustomBackend)
        .confirmationDialog(t("确认卸载这个个人 Skill？"), isPresented: $showingUninstallConfirmation) {
            Button(t("卸载"), role: .destructive) {
                viewModel.uninstallSelectedSkill()
            }
            Button(t("取消"), role: .cancel) { }
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        switch viewModel.selectedSection {
        case .backend:
            backendContent
        case .skills:
            skillsContent
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.08, green: 0.12, blue: 0.14),
                                Color(red: 0.15, green: 0.18, blue: 0.20)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(alignment: .topLeading) {
                        Circle()
                            .fill(Color.cyan.opacity(0.75))
                            .frame(width: 17, height: 17)
                            .offset(x: 8, y: 8)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Circle()
                            .fill(Color.orange.opacity(0.85))
                            .frame(width: 18, height: 18)
                            .offset(x: -8, y: -8)
                    }

                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)
            .shadow(color: .black.opacity(0.14), radius: 12, y: 5)

            VStack(alignment: .leading, spacing: 5) {
                Text(t("后端与 Skill 中枢"))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                Text(t("Claude Code 的模型路由、版本更新与技能目录"))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("", selection: $viewModel.selectedSection) {
                ForEach(AppSection.allCases) { section in
                    Text(t(section.displayName)).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 250)

            Picker("", selection: $languageID) {
                Text("中文").tag("zh-Hans")
                Text("EN").tag("en")
            }
            .pickerStyle(.segmented)
            .frame(width: 112)
        }
    }

    private var backendContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            currentStatus
            modeGrid
            credentialPanel
            footer
        }
    }

    private var currentStatus: some View {
        HStack(spacing: 12) {
            StatusDot(color: viewModel.currentProfile.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(t("当前生效"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(AppStrings.profileName(viewModel.currentProfile, languageID: languageID))
                    .font(.title3.weight(.semibold))
            }

            Spacer(minLength: 18)

            effortControl

            if !viewModel.isCurrentSelection || viewModel.isAddingCustomBackend {
                Text(t("尚未应用"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background {
                        Capsule()
                            .fill(Color.accentColor)
                    }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                }
        }
    }

    private var effortControl: some View {
        VStack(alignment: .trailing, spacing: 5) {
            HStack(spacing: 8) {
                Text(t("全局 Effort"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Picker("", selection: Binding(
                    get: { viewModel.selectedEffortLevel },
                    set: { viewModel.setEffortLevel($0) }
                )) {
                    ForEach(ClaudeEffortLevel.allCases) { level in
                        Text(AppStrings.effortLabel(level, languageID: languageID))
                            .tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 330)
            }

            Text(AppStrings.effortHelp(viewModel.selectedEffortLevel, languageID: languageID))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .help(AppStrings.effortHelp(viewModel.selectedEffortLevel, languageID: languageID))
    }

    private var modeGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(t("选择模式"))
                .font(.headline)

            LazyVGrid(columns: modeColumns, alignment: .leading, spacing: 14) {
                ForEach(viewModel.visibleBackendProfiles) { profile in
                    ModeCard(
                        profile: profile,
                        isSelected: viewModel.selectedProfileID == profile.id && !viewModel.isAddingCustomBackend,
                        isCurrent: viewModel.currentProfile.id == profile.id,
                        languageID: languageID
                    ) {
                        viewModel.selectProfile(profile)
                    }
                }

                AddCustomBackendCard(isSelected: viewModel.isAddingCustomBackend, languageID: languageID) {
                    viewModel.beginAddingCustomBackend()
                }
            }
        }
    }

    private var modeColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14)
        ]
    }

    private var credentialPanel: some View {
        ZStack {
            if viewModel.isAddingCustomBackend {
                customBackendSection
                    .transition(.opacity)
            } else if viewModel.selectedProfile.needsAPIKey {
                keySection
                    .transition(.opacity)
            } else {
                claudeCredentialSection
                    .transition(.opacity)
            }
        }
        .frame(height: viewModel.isAddingCustomBackend ? 220 : 120)
        .animation(.easeInOut(duration: 0.16), value: viewModel.selectedProfileID)
        .animation(.easeInOut(duration: 0.16), value: viewModel.isAddingCustomBackend)
    }

    private var keySection: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Label(AppStrings.apiKeyTitle(viewModel.selectedProfile, languageID: languageID), systemImage: "key.fill")
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.loadSavedKey()
                } label: {
                    Label(t("读取密钥"), systemImage: "key.viewfinder")
                }
                .buttonStyle(.borderless)

                Text(t("钥匙串"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.10), in: Capsule())
            }

            SecureField("sk-...", text: $viewModel.apiKey)
                .textFieldStyle(.roundedBorder)

            Text(t("密钥只保存到本机钥匙串，不会写入项目文件或 GitHub 仓库。"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(viewModel.selectedProfile.accentColor.opacity(0.28), lineWidth: 1)
                }
        }
    }

    private var customBackendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(t("新增自定义后端"), systemImage: "slider.horizontal.3")
                    .font(.headline)
                Spacer()
                Text(t("Anthropic 兼容"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.teal)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.teal.opacity(0.10), in: Capsule())
            }

            HStack(spacing: 10) {
                TextField(t("显示名称，例如 OpenRouter Claude"), text: $viewModel.customBackendDraft.displayName)
                TextField(t("Base URL，例如 https://api.example.com/anthropic"), text: $viewModel.customBackendDraft.baseURL)
            }
            .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                TextField(t("主模型，例如 claude-sonnet-4-20250514"), text: $viewModel.customBackendDraft.primaryModel)
                TextField(t("快速模型，可和主模型相同"), text: $viewModel.customBackendDraft.fastModel)
            }
            .textFieldStyle(.roundedBorder)

            SecureField("API Key", text: $viewModel.customBackendDraft.apiKey)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text(t("第一版只支持 Anthropic 兼容接口，不做 OpenAI/Gemini 协议转换。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(t("取消")) {
                    viewModel.cancelAddingCustomBackend()
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.teal.opacity(0.28), lineWidth: 1)
                }
        }
    }

    private var claudeCredentialSection: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(t("Claude 订阅无需 API Key"))
                    .font(.headline)
                Text(t("切回 Claude 时会移除 DeepSeek 路由配置，后续 `claude` 使用你的登录订阅。"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 17) {
            Divider()

            HStack(alignment: .center, spacing: 12) {
                Button {
                    viewModel.refresh()
                } label: {
                    Label(t("刷新"), systemImage: "arrow.clockwise")
                }

                if viewModel.selectedProfile.needsAPIKey && !viewModel.isAddingCustomBackend {
                    Button {
                        viewModel.saveKey()
                    } label: {
                        Label(t("保存密钥"), systemImage: "key")
                    }
                }

                Button {
                    viewModel.checkClaudeVersion()
                } label: {
                    Label(t("检查版本"), systemImage: "arrow.down.circle")
                }
                .disabled(viewModel.isCheckingVersion || viewModel.isUpdatingVersion || viewModel.isInstallingVersion)

                if viewModel.canInstallClaudeCode || viewModel.isInstallingVersion {
                    Button {
                        viewModel.installClaudeCodeVersion()
                    } label: {
                        Label(t(viewModel.isInstallingVersion ? "安装中" : "安装 Claude Code"), systemImage: "tray.and.arrow.down")
                    }
                    .disabled(viewModel.isInstallingVersion || viewModel.isCheckingVersion || viewModel.isUpdatingVersion)
                }

                if viewModel.canUpdateClaudeCode || viewModel.isUpdatingVersion {
                    Button {
                        viewModel.updateClaudeCodeVersion()
                    } label: {
                        Label(t(viewModel.isUpdatingVersion ? "更新中" : "更新 Claude Code"), systemImage: "square.and.arrow.down")
                    }
                    .disabled(viewModel.isUpdatingVersion || viewModel.isCheckingVersion || viewModel.isInstallingVersion)
                }

                Spacer()

                Button {
                    viewModel.applySelectedMode()
                } label: {
                    Label(t(viewModel.isAddingCustomBackend ? "保存并应用" : (viewModel.isCurrentSelection ? "重新应用" : "应用模式")), systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isBusy)
            }

            versionLine
            statusLine
        }
    }

    private var versionLine: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: versionIcon)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.versionSummaryText(languageID: languageID))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
                Text(viewModel.versionDetailText(languageID: languageID))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }

    private var versionIcon: String {
        if viewModel.isUpdatingVersion {
            return "arrow.triangle.2.circlepath"
        }
        if viewModel.isInstallingVersion {
            return "tray.and.arrow.down"
        }
        if viewModel.isCheckingVersion {
            return "clock"
        }
        return "arrow.down.circle"
    }

    private var statusLine: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
            Text(viewModel.statusText(languageID: languageID))
                .lineLimit(2)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.bottom, 2)
    }

    private var statusIcon: String {
        viewModel.currentProfile.isClaudeSubscription ? "person.crop.circle" : "bolt.horizontal.circle"
    }

    private var statusColor: Color {
        viewModel.currentProfile.accentColor
    }

    private var skillCountText: String {
        AppStrings.skillCount(filtered: viewModel.filteredSkillCount, total: viewModel.skills.count, languageID: languageID)
    }

    private var summaryProviderHelpText: String {
        AppStrings.summaryProviderHelp(viewModel.summaryProviderName(languageID: languageID), languageID: languageID)
    }

    private func t(_ key: String) -> String {
        AppStrings.text(key, languageID: languageID)
    }

    private var windowTitle: String {
        AppStrings.isEnglish(languageID) ? "Claude Code Switcher" : "Claude Code 切换器"
    }

    private var skillsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                skillList
                skillDetail
            }
            .frame(height: 574)

            skillStatusLine
        }
    }

    private var skillList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("技能库"))
                        .font(.subheadline.weight(.semibold))
                    Text(skillCountText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Menu {
                    Picker(t("摘要模型"), selection: $viewModel.selectedSummaryProfileID) {
                        Text(t("关闭自动摘要")).tag(SwitcherViewModel.summaryDisabledID)
                        ForEach(viewModel.selectableSummaryProfiles) { profile in
                            Text(AppStrings.profileName(profile, languageID: languageID)).tag(profile.id)
                        }
                    }
                } label: {
                    Image(systemName: "text.bubble")
                        .frame(width: 24, height: 24)
                        .help(summaryProviderHelpText)
                }
                .menuStyle(.borderlessButton)

                Menu {
                    Picker(t("分类"), selection: $viewModel.selectedSkillCategory) {
                        ForEach(viewModel.skillCategories, id: \.self) { category in
                            Text(t(category)).tag(category)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(t(viewModel.selectedSkillCategory))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .font(.caption.weight(.medium))
                    .frame(width: 94)
                }
                .menuStyle(.borderlessButton)
                .disabled(viewModel.skills.isEmpty)

                Menu {
                    Button {
                        viewModel.refreshSkills()
                    } label: {
                        Label(t("刷新技能库"), systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.isRefreshingSkills || viewModel.isCheckingSkillUpdates)

                    Button {
                        viewModel.checkAllSkillUpdates()
                    } label: {
                        Label(t("检查当前分类更新"), systemImage: "arrow.down.circle")
                    }
                    .disabled(viewModel.skills.isEmpty || viewModel.isCheckingSkillUpdates)

                    Button {
                        viewModel.generateFilteredSkillSummaries(languageID: languageID)
                    } label: {
                        Label(t("批量生成摘要"), systemImage: "text.bubble")
                    }
                    .disabled(viewModel.filteredSkills.isEmpty || viewModel.isSummarizingSkills)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            if viewModel.skills.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary)
                    Text(t("没有扫描到 Skill"))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredSkills.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary)
                    Text(t("这个分类下没有 Skill"))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(viewModel.groupedSkills, id: \.category) { group in
                            VStack(alignment: .leading, spacing: 7) {
                                HStack {
                                    Text(t(group.category))
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(group.skills.count)")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 12)

                                VStack(spacing: 2) {
                                    ForEach(group.skills) { skill in
                                        Button {
                                            viewModel.selectedSkillID = skill.id
                                        } label: {
                                            SkillRow(
                                                skill: skill,
                                                summary: viewModel.summaryText(for: skill, languageID: languageID),
                                                updateState: viewModel.skillUpdateStates[skill.id] ?? .notChecked,
                                                isSelected: viewModel.selectedSkillID == skill.id,
                                                languageID: languageID
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 12)
                }
            }
        }
        .frame(width: 340)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                }
        }
    }

    private var skillDetail: some View {
        Group {
            if let skill = viewModel.selectedSkill {
                SkillDetailView(
                    skill: skill,
                    summary: viewModel.summaryText(for: skill, languageID: languageID),
                    usageText: viewModel.usageText(for: skill, languageID: languageID),
                    updateState: viewModel.skillUpdateStates[skill.id] ?? .notChecked,
                    isBusy: viewModel.isCheckingSkillUpdates || viewModel.isMutatingSkill,
                    languageID: languageID,
                    hasSummary: viewModel.hasGeneratedSummary(for: skill, languageID: languageID),
                    reveal: viewModel.revealSelectedSkill,
                    togglePaused: viewModel.toggleSelectedSkillPaused,
                    checkUpdate: viewModel.checkSelectedSkillUpdate,
                    update: viewModel.updateSelectedSkill,
                    regenerateSummary: {
                        viewModel.regenerateSelectedSkillSummary(languageID: languageID)
                    },
                    requestUninstall: {
                        showingUninstallConfirmation = true
                    }
                )
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "cursorarrow.click")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary)
                    Text(t("选择一个 Skill"))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                        }
                }
            }
        }
    }

    private var skillStatusLine: some View {
        HStack(spacing: 8) {
            Image(systemName: "wand.and.stars")
                .foregroundStyle(.teal)
            Text(viewModel.skillStatusText(languageID: languageID))
                .lineLimit(2)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

private struct SkillRow: View {
    let skill: ClaudeSkillRecord
    let summary: String
    let updateState: SkillUpdateState
    let isSelected: Bool
    let languageID: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(isSelected ? rowColor : Color.clear)
                .frame(width: 3)
                .padding(.vertical, 2)

            Image(systemName: scopeIcon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(rowColor)
                .frame(width: 22, height: 22)
                .background(rowColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(skill.commandName)
                    .font(.system(.callout, design: .rounded).weight(.semibold))
                    .foregroundStyle(skill.isPaused ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 7) {
                    Text(AppStrings.text(skill.scope.displayName, languageID: languageID))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(scopeColor)
                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(AppStrings.text(skill.isPaused ? "已暂停" : updateState.label, languageID: languageID))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(skill.isPaused ? .orange : .secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? rowColor.opacity(0.10) : Color.clear)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var scopeColor: Color {
        switch skill.scope {
        case .personal:
            .blue
        case .plugin:
            .teal
        }
    }

    private var rowColor: Color {
        skill.isPaused ? .orange : scopeColor
    }

    private var scopeIcon: String {
        if skill.isPaused {
            return "pause.circle"
        }
        return switch skill.scope {
        case .personal:
            "person.crop.circle"
        case .plugin:
            "shippingbox"
        }
    }

}

private struct SkillDetailView: View {
    let skill: ClaudeSkillRecord
    let summary: String
    let usageText: String
    let updateState: SkillUpdateState
    let isBusy: Bool
    let languageID: String
    let hasSummary: Bool
    let reveal: () -> Void
    let togglePaused: () -> Void
    let checkUpdate: () -> Void
    let update: () -> Void
    let regenerateSummary: () -> Void
    let requestUninstall: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: scopeIcon)
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(scopeColor)
                            .frame(width: 42, height: 42)
                            .background(scopeColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 8) {
                            Text(skill.commandName)
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .lineLimit(2)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                            Text(summary)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineSpacing(2)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()
                    }

                    Divider()

                    LazyVGrid(columns: detailColumns, alignment: .leading, spacing: 13) {
                        DetailField(title: "分类", value: skill.category, icon: "tag", languageID: languageID)
                        DetailField(title: "状态", value: skill.isPaused ? "已暂停" : "启用中", icon: skill.isPaused ? "pause.circle" : "checkmark.circle", languageID: languageID)
                        DetailField(title: "来源", value: skill.scope.displayName, icon: scopeIcon, languageID: languageID)
                        DetailField(title: "版本", value: skill.pluginVersion ?? "不适用", icon: "number", languageID: languageID)
                        DetailField(title: "支持文件", value: supportingFileText, icon: "doc", languageID: languageID)
                        DetailField(title: "名称", value: skill.name, icon: "textformat", languageID: languageID)
                        DetailField(title: "插件", value: pluginText, icon: "shippingbox", languageID: languageID)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 14) {
                        DetailTextBlock(title: "摘要", value: summary, languageID: languageID)
                        DetailTextBlock(title: "如何使用", value: usageText, languageID: languageID)
                        DetailTextBlock(title: "原始描述", value: skill.description.isEmpty ? "没有描述" : skill.description, languageID: languageID)
                        DetailTextBlock(title: "工具权限", value: toolsText, languageID: languageID)
                        DetailTextBlock(title: "路径", value: skill.skillDirectory.path, isMonospaced: true, languageID: languageID)
                        DetailField(title: "修改时间", value: modifiedText, icon: "calendar", languageID: languageID)
                    }

                    Divider()

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: updateIcon)
                            .foregroundStyle(updateColor)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(AppStrings.text(updateState.label, languageID: languageID))
                                .font(.callout.weight(.medium))
                            Text(AppStrings.text(updateState.detail, languageID: languageID))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)

            Divider()

            HStack(spacing: 10) {
                Button {
                    reveal()
                } label: {
                    Label(AppStrings.text("显示文件", languageID: languageID), systemImage: "folder")
                        .frame(minWidth: 92)
                }

                Button {
                    togglePaused()
                } label: {
                    Label {
                        Text(AppStrings.text(skill.isPaused ? "恢复使用" : "暂停使用", languageID: languageID))
                            .frame(minWidth: 96)
                    } icon: {
                        Image(systemName: skill.isPaused ? "play.circle" : "pause.circle")
                    }
                }
                .disabled(isBusy)

                Spacer()

                Menu {
                    Button {
                        checkUpdate()
                    } label: {
                        Label(AppStrings.text("检查更新", languageID: languageID), systemImage: "arrow.down.circle")
                    }
                    .disabled(isBusy)

                    Button {
                        regenerateSummary()
                    } label: {
                        Label(AppStrings.text(hasSummary ? "重写摘要" : "生成摘要", languageID: languageID), systemImage: "text.bubble")
                    }
                    .disabled(isBusy)

                    Divider()

                    Button {
                        update()
                    } label: {
                        Label(AppStrings.text("更新", languageID: languageID), systemImage: "square.and.arrow.down")
                    }
                    .disabled(isBusy || !updateState.canUpdate)

                    Button(role: .destructive) {
                        requestUninstall()
                    } label: {
                        Label(AppStrings.text("卸载", languageID: languageID), systemImage: "trash")
                    }
                    .disabled(isBusy || !skill.isUninstallable)
                } label: {
                    Label(AppStrings.text("更多", languageID: languageID), systemImage: "ellipsis.circle")
                        .frame(minWidth: 74)
                }
            }
            .padding(14)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                }
        }
    }

    private var detailColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14)
        ]
    }

    private var scopeColor: Color {
        switch skill.scope {
        case .personal:
            .blue
        case .plugin:
            .teal
        }
    }

    private var scopeIcon: String {
        switch skill.scope {
        case .personal:
            "person.crop.circle"
        case .plugin:
            "shippingbox"
        }
    }

    private var pluginText: String {
        guard let pluginName = skill.pluginName else {
            return "不适用"
        }
        return pluginName
    }

    private var supportingFileText: String {
        AppStrings.supportingFileCount(skill.supportingFileCount, languageID: languageID)
    }

    private var modifiedText: String {
        guard let modifiedAt = skill.modifiedAt else {
            return "未知"
        }
        return modifiedAt.formatted(date: .abbreviated, time: .shortened)
    }

    private var toolsText: String {
        var parts: [String] = []
        if let allowedTools = skill.allowedTools, !allowedTools.isEmpty {
            parts.append("\(AppStrings.text("允许", languageID: languageID))：\(allowedTools)")
        }
        if let disallowedTools = skill.disallowedTools, !disallowedTools.isEmpty {
            parts.append("\(AppStrings.text("禁止", languageID: languageID))：\(disallowedTools)")
        }
        if skill.disableModelInvocation {
            parts.append(AppStrings.text("禁用模型调用", languageID: languageID))
        }
        return parts.isEmpty ? AppStrings.text("未声明", languageID: languageID) : parts.joined(separator: AppStrings.isEnglish(languageID) ? "; " : "；")
    }

    private var updateIcon: String {
        switch updateState {
        case .updateAvailable:
            "exclamationmark.circle"
        case .current:
            "checkmark.circle"
        case .checking:
            "clock"
        case .failed:
            "xmark.circle"
        case .unavailable:
            "info.circle"
        case .notChecked:
            "circle"
        }
    }

    private var updateColor: Color {
        switch updateState {
        case .updateAvailable:
            .orange
        case .current:
            .green
        case .checking:
            .blue
        case .failed:
            .red
        case .unavailable:
            .secondary
        case .notChecked:
            .secondary.opacity(0.55)
        }
    }
}

private struct DetailField: View {
    let title: String
    let value: String
    let icon: String
    let languageID: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.teal)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(AppStrings.text(title, languageID: languageID))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(AppStrings.text(value, languageID: languageID))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DetailTextBlock: View {
    let title: String
    let value: String
    var isMonospaced = false
    let languageID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(AppStrings.text(title, languageID: languageID))
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(isMonospaced ? .system(.caption, design: .monospaced) : .caption)
                .foregroundStyle(.primary)
                .lineSpacing(2)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ModeCard: View {
    let profile: BackendProfile
    let isSelected: Bool
    let isCurrent: Bool
    let languageID: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: profile.symbolName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isSelected ? profile.accentColor : .secondary)
                        .frame(width: 28, height: 28)
                        .background(profile.accentColor.opacity(isSelected ? 0.14 : 0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                    Spacer()

                    if isCurrent {
                    Text(AppStrings.text("当前", languageID: languageID))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(profile.accentColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(profile.accentColor.opacity(0.12), in: Capsule())
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(AppStrings.profileName(profile, languageID: languageID))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(AppStrings.text(profile.shortDescription, languageID: languageID))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .padding(15)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? profile.accentColor.opacity(0.10) : Color(nsColor: .controlBackgroundColor))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isSelected ? profile.accentColor.opacity(0.72) : Color.secondary.opacity(0.12), lineWidth: isSelected ? 1.4 : 1)
                    }
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AppStrings.profileName(profile, languageID: languageID))
    }
}

private struct AddCustomBackendCard: View {
    let isSelected: Bool
    let languageID: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isSelected ? .teal : .secondary)
                    .frame(width: 28, height: 28)
                    .background(Color.teal.opacity(isSelected ? 0.14 : 0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(AppStrings.text("自定义后端", languageID: languageID))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(AppStrings.text("填写兼容地址和模型名", languageID: languageID))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .padding(15)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.teal.opacity(0.10) : Color(nsColor: .controlBackgroundColor))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isSelected ? Color.teal.opacity(0.72) : Color.secondary.opacity(0.12), lineWidth: isSelected ? 1.4 : 1)
                    }
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AppStrings.text("新增自定义后端", languageID: languageID))
    }
}

private struct StatusDot: View {
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.16))
                .frame(width: 34, height: 34)
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
        }
    }
}

private struct WindowTitleUpdater: NSViewRepresentable {
    let title: String

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.title = title
            NSApplication.shared.mainMenu?.items.first?.title = title
        }
    }
}

private extension BackendProfile {
    var symbolName: String {
        if id == BackendProfile.claudeSubscription.id {
            return "person.crop.circle"
        }
        if id == BackendProfile.deepSeekPro.id {
            return "sparkles"
        }
        if id == BackendProfile.deepSeekFlash.id {
            return "bolt.fill"
        }
        return isBuiltIn ? "server.rack" : "slider.horizontal.3"
    }

    var accentColor: Color {
        if id == BackendProfile.claudeSubscription.id {
            return .blue
        }
        if id == BackendProfile.deepSeekPro.id {
            return .teal
        }
        if id == BackendProfile.deepSeekFlash.id {
            return .orange
        }
        return .purple
    }

    var shortDescription: String {
        if id == BackendProfile.claudeSubscription.id {
            return "订阅账户，不走 API"
        }
        if id == BackendProfile.deepSeekPro.id {
            return "强能力，适合复杂任务"
        }
        if id == BackendProfile.deepSeekFlash.id {
            return "更快更省，适合日常"
        }
        return detail
    }
}
