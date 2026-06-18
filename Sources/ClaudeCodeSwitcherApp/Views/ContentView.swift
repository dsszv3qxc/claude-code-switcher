import SwiftUI
import ClaudeCodeSwitcherCore

struct ContentView: View {
    @ObservedObject var viewModel: SwitcherViewModel
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
        .animation(.easeInOut(duration: 0.18), value: viewModel.selectedProfileID)
        .animation(.easeInOut(duration: 0.18), value: viewModel.isAddingCustomBackend)
        .confirmationDialog("确认卸载这个个人 Skill？", isPresented: $showingUninstallConfirmation) {
            Button("卸载", role: .destructive) {
                viewModel.uninstallSelectedSkill()
            }
            Button("取消", role: .cancel) { }
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
                Text("后端与 Skill 中枢")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                Text("Claude Code 的模型路由、版本更新与技能目录")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("", selection: $viewModel.selectedSection) {
                ForEach(AppSection.allCases) { section in
                    Text(section.displayName).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 250)
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
                Text("当前生效")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(viewModel.currentProfile.displayName)
                    .font(.title3.weight(.semibold))
            }

            Spacer()

            if !viewModel.isCurrentSelection || viewModel.isAddingCustomBackend {
                Text("尚未应用")
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

    private var modeGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("选择模式")
                .font(.headline)

            LazyVGrid(columns: modeColumns, alignment: .leading, spacing: 14) {
                ForEach(viewModel.visibleBackendProfiles) { profile in
                    ModeCard(
                        profile: profile,
                        isSelected: viewModel.selectedProfileID == profile.id && !viewModel.isAddingCustomBackend,
                        isCurrent: viewModel.currentProfile.id == profile.id
                    ) {
                        viewModel.selectProfile(profile)
                    }
                }

                AddCustomBackendCard(isSelected: viewModel.isAddingCustomBackend) {
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
                Label("\(viewModel.selectedProfile.displayName) API Key", systemImage: "key.fill")
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.loadSavedKey()
                } label: {
                    Label("读取密钥", systemImage: "key.viewfinder")
                }
                .buttonStyle(.borderless)

                Text("钥匙串")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.10), in: Capsule())
            }

            SecureField("sk-...", text: $viewModel.apiKey)
                .textFieldStyle(.roundedBorder)

            Text("密钥只保存到本机钥匙串，不会写入项目文件或 GitHub 仓库。")
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
                Label("新增自定义后端", systemImage: "slider.horizontal.3")
                    .font(.headline)
                Spacer()
                Text("Anthropic 兼容")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.teal)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.teal.opacity(0.10), in: Capsule())
            }

            HStack(spacing: 10) {
                TextField("显示名称，例如 OpenRouter Claude", text: $viewModel.customBackendDraft.displayName)
                TextField("Base URL，例如 https://api.example.com/anthropic", text: $viewModel.customBackendDraft.baseURL)
            }
            .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                TextField("主模型，例如 claude-sonnet-4-20250514", text: $viewModel.customBackendDraft.primaryModel)
                TextField("快速模型，可和主模型相同", text: $viewModel.customBackendDraft.fastModel)
            }
            .textFieldStyle(.roundedBorder)

            SecureField("API Key", text: $viewModel.customBackendDraft.apiKey)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text("第一版只支持 Anthropic 兼容接口，不做 OpenAI/Gemini 协议转换。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("取消") {
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
                Text("Claude 订阅无需 API Key")
                    .font(.headline)
                Text("切回 Claude 时会移除 DeepSeek 路由配置，后续 `claude` 使用你的登录订阅。")
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
                    Label("刷新", systemImage: "arrow.clockwise")
                }

                if viewModel.selectedProfile.needsAPIKey && !viewModel.isAddingCustomBackend {
                    Button {
                        viewModel.saveKey()
                    } label: {
                        Label("保存密钥", systemImage: "key")
                    }
                }

                Button {
                    viewModel.checkClaudeVersion()
                } label: {
                    Label("检查版本", systemImage: "arrow.down.circle")
                }
                .disabled(viewModel.isCheckingVersion || viewModel.isUpdatingVersion)

                if viewModel.canUpdateClaudeCode || viewModel.isUpdatingVersion {
                    Button {
                        viewModel.updateClaudeCodeVersion()
                    } label: {
                        Label(viewModel.isUpdatingVersion ? "更新中" : "更新 Claude Code", systemImage: "square.and.arrow.down")
                    }
                    .disabled(viewModel.isUpdatingVersion || viewModel.isCheckingVersion)
                }

                Spacer()

                Button {
                    viewModel.applySelectedMode()
                } label: {
                    Label(viewModel.isAddingCustomBackend ? "保存并应用" : (viewModel.isCurrentSelection ? "重新应用" : "应用模式"), systemImage: "checkmark.circle")
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
                Text(viewModel.versionSummary)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
                Text(viewModel.versionDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }

    private var versionIcon: String {
        if viewModel.isUpdatingVersion {
            return "arrow.triangle.2.circlepath"
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
            Text(viewModel.statusMessage.isEmpty ? "当前模式：\(viewModel.currentProfile.displayName)" : viewModel.statusMessage)
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
                    Text("技能库")
                        .font(.subheadline.weight(.semibold))
                    Text("\(viewModel.filteredSkillCount) / \(viewModel.skills.count) 个")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Menu {
                    Picker("摘要模型", selection: $viewModel.selectedSummaryProfileID) {
                        Text("关闭自动摘要").tag(SwitcherViewModel.summaryDisabledID)
                        ForEach(viewModel.selectableSummaryProfiles) { profile in
                            Text(profile.displayName).tag(profile.id)
                        }
                    }
                } label: {
                    Image(systemName: "text.bubble")
                        .frame(width: 24, height: 24)
                        .help("摘要模型：\(viewModel.summaryProviderName)")
                }
                .menuStyle(.borderlessButton)

                Menu {
                    Picker("分类", selection: $viewModel.selectedSkillCategory) {
                        ForEach(viewModel.skillCategories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.selectedSkillCategory)
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
                        Label("刷新技能库", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.isRefreshingSkills || viewModel.isCheckingSkillUpdates)

                    Button {
                        viewModel.checkAllSkillUpdates()
                    } label: {
                        Label("检查当前分类更新", systemImage: "arrow.down.circle")
                    }
                    .disabled(viewModel.skills.isEmpty || viewModel.isCheckingSkillUpdates)
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
                    Text("没有扫描到 Skill")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredSkills.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary)
                    Text("这个分类下没有 Skill")
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
                                    Text(group.category)
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
                                                summary: viewModel.summaryText(for: skill),
                                                updateState: viewModel.skillUpdateStates[skill.id] ?? .notChecked,
                                                isSelected: viewModel.selectedSkillID == skill.id
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
                    summary: viewModel.summaryText(for: skill),
                    usageText: viewModel.usageText(for: skill),
                    updateState: viewModel.skillUpdateStates[skill.id] ?? .notChecked,
                    isBusy: viewModel.isCheckingSkillUpdates || viewModel.isMutatingSkill,
                    reveal: viewModel.revealSelectedSkill,
                    togglePaused: viewModel.toggleSelectedSkillPaused,
                    checkUpdate: viewModel.checkSelectedSkillUpdate,
                    update: viewModel.updateSelectedSkill,
                    regenerateSummary: viewModel.regenerateSelectedSkillSummary,
                    requestUninstall: {
                        showingUninstallConfirmation = true
                    }
                )
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "cursorarrow.click")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary)
                    Text("选择一个 Skill")
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
            Text(viewModel.skillStatusMessage)
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
                    Text(skill.scope.displayName)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(scopeColor)
                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(skill.isPaused ? "已暂停" : updateState.label)
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
                        DetailField(title: "分类", value: skill.category, icon: "tag")
                        DetailField(title: "状态", value: skill.isPaused ? "已暂停" : "启用中", icon: skill.isPaused ? "pause.circle" : "checkmark.circle")
                        DetailField(title: "来源", value: skill.scope.displayName, icon: scopeIcon)
                        DetailField(title: "版本", value: skill.pluginVersion ?? "不适用", icon: "number")
                        DetailField(title: "支持文件", value: "\(skill.supportingFileCount) 个", icon: "doc")
                        DetailField(title: "名称", value: skill.name, icon: "textformat")
                        DetailField(title: "插件", value: pluginText, icon: "shippingbox")
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 14) {
                        DetailTextBlock(title: "如何使用", value: usageText)
                        DetailTextBlock(title: "原始描述", value: skill.description.isEmpty ? "没有描述" : skill.description)
                        DetailTextBlock(title: "工具权限", value: toolsText)
                        DetailTextBlock(title: "路径", value: skill.skillDirectory.path, isMonospaced: true)
                        DetailField(title: "修改时间", value: modifiedText, icon: "calendar")
                    }

                    Divider()

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: updateIcon)
                            .foregroundStyle(updateColor)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(updateState.label)
                                .font(.callout.weight(.medium))
                            Text(updateState.detail)
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
                    Label("显示文件", systemImage: "folder")
                        .frame(minWidth: 92)
                }

                Button {
                    togglePaused()
                } label: {
                    Label(skill.isPaused ? "恢复使用" : "暂停使用", systemImage: skill.isPaused ? "play.circle" : "pause.circle")
                        .frame(minWidth: 96)
                }
                .disabled(isBusy)

                Spacer()

                Menu {
                    Button {
                        checkUpdate()
                    } label: {
                        Label("检查更新", systemImage: "arrow.down.circle")
                    }
                    .disabled(isBusy)

                    Button {
                        regenerateSummary()
                    } label: {
                        Label("重写摘要", systemImage: "text.bubble")
                    }
                    .disabled(isBusy)

                    Divider()

                    Button {
                        update()
                    } label: {
                        Label("更新", systemImage: "square.and.arrow.down")
                    }
                    .disabled(isBusy || !updateState.canUpdate)

                    Button(role: .destructive) {
                        requestUninstall()
                    } label: {
                        Label("卸载", systemImage: "trash")
                    }
                    .disabled(isBusy || !skill.isUninstallable)
                } label: {
                    Label("更多", systemImage: "ellipsis.circle")
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

    private var modifiedText: String {
        guard let modifiedAt = skill.modifiedAt else {
            return "未知"
        }
        return modifiedAt.formatted(date: .abbreviated, time: .shortened)
    }

    private var toolsText: String {
        var parts: [String] = []
        if let allowedTools = skill.allowedTools, !allowedTools.isEmpty {
            parts.append("允许：\(allowedTools)")
        }
        if let disallowedTools = skill.disallowedTools, !disallowedTools.isEmpty {
            parts.append("禁止：\(disallowedTools)")
        }
        if skill.disableModelInvocation {
            parts.append("禁用模型调用")
        }
        return parts.isEmpty ? "未声明" : parts.joined(separator: "；")
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

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.teal)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(value)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
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
                        Text("当前")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(profile.accentColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(profile.accentColor.opacity(0.12), in: Capsule())
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.displayName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(profile.shortDescription)
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
        .accessibilityLabel(profile.displayName)
    }
}

private struct AddCustomBackendCard: View {
    let isSelected: Bool
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
                    Text("自定义后端")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("填写兼容地址和模型名")
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
        .accessibilityLabel("新增自定义后端")
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
