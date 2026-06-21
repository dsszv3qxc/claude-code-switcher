import Foundation
import ClaudeCodeSwitcherCore

enum AppStrings {
    static func isEnglish(_ languageID: String) -> Bool {
        languageID.hasPrefix("en")
    }

    static func text(_ key: String, languageID: String) -> String {
        guard isEnglish(languageID) else {
            return key
        }
        if let dynamic = dynamicEnglishText(key) {
            return dynamic
        }
        return english[key] ?? key
    }

    static func profileName(_ profile: BackendProfile, languageID: String) -> String {
        text(profile.displayName, languageID: languageID)
    }

    static func profileName(_ name: String, languageID: String) -> String {
        text(name, languageID: languageID)
    }

    static func skillCount(filtered: Int, total: Int, languageID: String) -> String {
        let count = "\(filtered) / \(total)"
        return isEnglish(languageID) ? count : "\(count) 个"
    }

    static func supportingFileCount(_ count: Int, languageID: String) -> String {
        isEnglish(languageID) ? "\(count)" : "\(count) 个"
    }

    static func summaryProviderHelp(_ providerName: String, languageID: String) -> String {
        if isEnglish(languageID) {
            return "Summary model: \(providerName)"
        }
        return "摘要模型：\(providerName)"
    }

    static func apiKeyTitle(_ profile: BackendProfile, languageID: String) -> String {
        "\(profileName(profile, languageID: languageID)) API Key"
    }

    static func effortLabel(_ level: ClaudeEffortLevel, languageID: String) -> String {
        switch level {
        case .auto:
            return isEnglish(languageID) ? "Auto" : "自动"
        case .low:
            return isEnglish(languageID) ? "Low" : "低"
        case .medium:
            return isEnglish(languageID) ? "Medium" : "中"
        case .high:
            return isEnglish(languageID) ? "High" : "高"
        case .xhigh:
            return isEnglish(languageID) ? "XHigh" : "更高"
        case .max:
            return isEnglish(languageID) ? "Max" : "Max"
        }
    }

    static func effortHelp(_ level: ClaudeEffortLevel, languageID: String) -> String {
        if isEnglish(languageID) {
            return switch level {
            case .auto:
                "Use Claude Code's model default."
            case .low:
                "Fastest; best for small scoped tasks."
            case .medium:
                "Lower token use with reasonable reasoning."
            case .high:
                "Balanced default for most coding tasks."
            case .xhigh:
                "Deeper reasoning with higher token use."
            case .max:
                "Deepest reasoning; set through environment override."
            }
        }

        return switch level {
        case .auto:
            "跟随 Claude Code 的模型默认值。"
        case .low:
            "最快，适合小而明确的任务。"
        case .medium:
            "更省 token，保留基础推理。"
        case .high:
            "较均衡，适合多数编码任务。"
        case .xhigh:
            "更深推理，token 消耗更高。"
        case .max:
            "最深推理，通过环境变量覆盖。"
        }
    }

    private static func dynamicEnglishText(_ key: String) -> String? {
        let patterns: [(prefix: String, replacement: String)] = [
            ("无法读取 Claude Code 配置：", "Could not read Claude Code settings: "),
            ("无法写入 Claude Code 配置：", "Could not write Claude Code settings: "),
            ("无法从钥匙串读取 API Key。OSStatus ", "Could not read the API key from Keychain. OSStatus "),
            ("无法把 API Key 保存到钥匙串。OSStatus ", "Could not save the API key to Keychain. OSStatus "),
            ("更新失败：", "Update failed: "),
            ("安装失败：", "Installation failed: ")
        ]

        for pattern in patterns where key.hasPrefix(pattern.prefix) {
            return pattern.replacement + key.dropFirst(pattern.prefix.count)
        }

        return nil
    }

    private static let english: [String: String] = [
        "确认卸载这个个人 Skill？": "Uninstall this personal Skill?",
        "卸载": "Uninstall",
        "取消": "Cancel",

        "后端与 Skill 中枢": "Backend & Skill Hub",
        "Claude Code 的模型路由、版本更新与技能目录": "Model routing, version updates, and Skill library for Claude Code",
        "后端切换": "Backend",
        "Skill 管理": "Skills",
        "当前生效": "Active",
        "全局 Effort": "Global Effort",
        "尚未应用": "Pending",
        "选择模式": "Mode",
        "当前": "Current",

        "Claude 订阅": "Claude Subscription",
        "DeepSeek V4 Pro": "DeepSeek V4 Pro",
        "DeepSeek V4 Flash": "DeepSeek V4 Flash",
        "自定义后端": "Custom Backend",
        "外部配置": "External Config",
        "我的模型": "My Model",
        "订阅账户，不走 API": "Subscription account, no API",
        "强能力，适合复杂任务": "Stronger model for complex work",
        "更快更省，适合日常": "Faster and cheaper for daily work",
        "使用已登录的 Claude Code 订阅，不走 API。": "Use the signed-in Claude Code subscription, no API routing.",
        "强能力模式，适合复杂任务。": "Stronger mode for complex tasks.",
        "更快更省，适合日常任务。": "Faster and cheaper for daily work.",
        "填写兼容地址和模型名": "Enter endpoint and model names",
        "自定义 Anthropic 兼容后端。": "Custom Anthropic-compatible backend.",
        "当前 Claude Code 配置里已有一个未保存在本应用中的 API 后端。": "Claude Code currently has an API backend that is not saved in this app.",

        "读取密钥": "Load Key",
        "钥匙串": "Keychain",
        "密钥只保存到本机钥匙串，不会写入项目文件或 GitHub 仓库。": "The key is stored only in local Keychain, not in project files or GitHub.",
        "新增自定义后端": "New Custom Backend",
        "Anthropic 兼容": "Anthropic Compatible",
        "显示名称，例如 OpenRouter Claude": "Display name, e.g. OpenRouter Claude",
        "Base URL，例如 https://api.example.com/anthropic": "Base URL, e.g. https://api.example.com/anthropic",
        "主模型，例如 claude-sonnet-4-20250514": "Primary model, e.g. claude-sonnet-4-20250514",
        "快速模型，可和主模型相同": "Fast model, can match primary model",
        "第一版只支持 Anthropic 兼容接口，不做 OpenAI/Gemini 协议转换。": "v1 only supports Anthropic-compatible APIs. It does not convert OpenAI/Gemini protocols.",
        "Claude 订阅无需 API Key": "Claude Subscription does not need an API key",
        "切回 Claude 时会移除 DeepSeek 路由配置，后续 `claude` 使用你的登录订阅。": "Switching back to Claude removes API routing, so future `claude` sessions use your signed-in subscription.",
        "刷新": "Refresh",
        "保存密钥": "Save Key",
        "检查版本": "Check Version",
        "更新中": "Updating",
        "更新 Claude Code": "Update Claude Code",
        "安装中": "Installing",
        "安装 Claude Code": "Install Claude Code",
        "重新应用": "Reapply",
        "应用模式": "Apply Mode",
        "保存并应用": "Save & Apply",

        "技能库": "Skill Library",
        "全部分类": "All Categories",
        "摘要模型": "Summary Model",
        "关闭自动摘要": "Turn Off Summaries",
        "刷新技能库": "Refresh Skill Library",
        "检查当前分类更新": "Check Current Category",
        "批量生成摘要": "Generate Summaries",
        "没有扫描到 Skill": "No Skills Found",
        "这个分类下没有 Skill": "No Skills In This Category",
        "选择一个 Skill": "Select a Skill",
        "未生成摘要": "No summary generated",
        "正在生成摘要...": "Generating summary...",
        "正在重新生成摘要...": "Regenerating summary...",
        "需要先保存摘要模型 API Key。": "Save the summary model API key first.",

        "Claude 个人": "Claude Personal",
        "Claude 插件": "Claude Plugin",
        "界面优化": "Interface Design",
        "工程质量": "Engineering Quality",
        "macOS 应用开发": "macOS App Development",
        "GitHub 与代码协作": "GitHub & Collaboration",
        "文档与数据": "Documents & Data",
        "浏览器自动化": "Browser Automation",
        "图像与多媒体": "Images & Media",
        "Skill / Plugin 开发": "Skill / Plugin Development",
        "通信连接器": "Connectors",

        "未检查": "Not Checked",
        "检查中": "Checking",
        "已是最新": "Current",
        "可更新": "Update Available",
        "不可检查": "Unavailable",
        "检查失败": "Check Failed",
        "已暂停": "Paused",
        "尚未检查更新。": "Updates have not been checked.",
        "正在检查更新。": "Checking for updates.",
        "启用中": "Enabled",
        "分类": "Category",
        "状态": "Status",
        "来源": "Source",
        "版本": "Version",
        "摘要": "Summary",
        "支持文件": "Support Files",
        "名称": "Name",
        "插件": "Plugin",
        "如何使用": "How To Use",
        "原始描述": "Original Description",
        "工具权限": "Tool Permissions",
        "路径": "Path",
        "修改时间": "Modified",
        "不适用": "N/A",
        "未知": "Unknown",
        "未声明": "Not Declared",
        "没有描述": "No Description",
        "显示文件": "Reveal File",
        "暂停使用": "Pause",
        "恢复使用": "Resume",
        "检查更新": "Check Update",
        "生成摘要": "Generate Summary",
        "重写摘要": "Regenerate Summary",
        "更新": "Update",
        "更多": "More",
        "允许": "Allowed",
        "禁止": "Blocked",
        "禁用模型调用": "Model invocation disabled",

        "Claude Code 版本：未检查": "Claude Code Version: Not Checked",
        "检查不会更新或修改 Claude Code。": "Checking does not update or modify Claude Code.",
        "正在检查 Claude Code 版本...": "Checking Claude Code version...",
        "正在读取本机版本并查询官方最新版本。": "Reading local version and querying the official latest version.",
        "正在更新 Claude Code...": "Updating Claude Code...",
        "后台执行 claude update，不会打开终端窗口。": "Running claude update in the background without opening Terminal.",
        "正在安装 Claude Code...": "Installing Claude Code...",
        "后台执行 Claude 官方原生安装脚本，不会打开终端窗口。": "Running Claude's official native installer in the background without opening Terminal.",
        "未找到 Claude Code": "Claude Code Not Found",
        "Claude Code：无法读取版本": "Claude Code: Could Not Read Version",
        "未找到本机 claude。可以点击安装按钮安装 Claude Code CLI。": "Local `claude` was not found. Click Install Claude Code to install the CLI.",
        "未选择": "Not Selected",
        "没有错误输出。": "No error output.",
        "未找到 Claude Code，无法自动更新。": "Claude Code was not found, so it cannot be updated automatically.",
        "Claude Code 安装完成，已重新检查版本。": "Claude Code installation finished. Version was checked again.",
        "这个 Skill 已暂停，恢复使用后再检查更新。": "This Skill is paused. Resume it before checking for updates.",
        "插件或系统 Skill 由对应客户端管理。": "Plugin or system Skills are managed by their owning client.",
        "这个个人 Skill 不是 git 安装，无法判断远端更新。": "This personal Skill was not installed from git, so remote updates cannot be detected.",
        "git 仓库没有 upstream 分支，无法自动更新。": "This git repository has no upstream branch, so it cannot be auto-updated.",
        "无法读取本地或远端提交。": "Could not read local or remote commits.",
        "本地提交已经等于 upstream。": "Local commit already matches upstream.",
        "upstream 有新提交，可执行 fast-forward 更新。": "Upstream has new commits and can be fast-forwarded.",
        "本地和 upstream 已分叉，请手动处理后再更新。": "Local and upstream have diverged. Resolve it manually before updating.",
        "这个 Skill 已暂停，恢复使用后再更新。": "This Skill is paused. Resume it before updating.",
        "Skill 更新完成。": "Skill update finished.",
        "刚刚完成更新。": "Updated just now.",
        "插件或系统 Skill 由对应客户端管理，不能在这里直接卸载。": "Plugin or system Skills are managed by their owning client and cannot be uninstalled here.",
        "这个 Skill 已经是暂停状态。": "This Skill is already paused.",
        "这个 Skill 已经在使用中。": "This Skill is already active.",
        "没有找到 SKILL.md，无法暂停。": "SKILL.md was not found, so this Skill cannot be paused.",
        "没有找到暂停文件，无法恢复。": "The paused Skill file was not found, so this Skill cannot be resumed.",
        "目录里已经存在暂停文件，为避免覆盖，请先手动检查。": "A paused Skill file already exists in this folder. Check it manually to avoid overwriting.",
        "目录里已经存在 SKILL.md，为避免覆盖，请先手动检查。": "SKILL.md already exists in this folder. Check it manually to avoid overwriting.",
        "请先填写 API Key，再应用这个 API 后端。": "Enter an API key before applying this API backend.",
        "无法从钥匙串读取 API Key。": "Could not read the API key from Keychain.",
        "无法把 API Key 保存到钥匙串。": "Could not save the API key to Keychain.",
        "自定义后端配置不完整，请填写 Base URL、主模型和快速模型。": "Custom backend configuration is incomplete. Fill in Base URL, primary model, and fast model."
    ]
}
