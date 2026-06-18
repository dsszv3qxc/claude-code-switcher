import Foundation

public enum SkillCategoryClassifier {
    public static func category(
        name: String,
        commandName: String,
        description: String,
        scope: ClaudeSkillScope,
        pluginName: String?
    ) -> String {
        let haystack = [name, commandName, description, pluginName ?? ""]
            .joined(separator: " ")
            .lowercased()

        if pluginName == "superpowers" || commandName.hasPrefix("superpowers:") {
            return "Superpowers"
        }

        if haystack.contains("macos") || haystack.contains("swiftui") || haystack.contains("appkit") || haystack.contains("xcode") {
            return "macOS 应用开发"
        }

        if haystack.contains("frontend") || haystack.contains("design") || haystack.contains("taste") || haystack.contains(" ui ") {
            return "界面优化"
        }

        if haystack.contains("github") || haystack.contains("pull request") || haystack.contains("ci") || haystack.contains("git ") {
            return "GitHub 与代码协作"
        }

        if haystack.contains("test") || haystack.contains("debug") || haystack.contains("review") || haystack.contains("tdd") {
            return "工程质量"
        }

        if haystack.contains("document") || haystack.contains("docx") || haystack.contains("presentation") || haystack.contains("spreadsheet") || haystack.contains("xlsx") {
            return "文档与数据"
        }

        if haystack.contains("browser") || haystack.contains("chrome") || haystack.contains("playwright") {
            return "浏览器自动化"
        }

        if haystack.contains("image") || haystack.contains("photo") || haystack.contains("visual") {
            return "图像与多媒体"
        }

        if haystack.contains("mcp") || haystack.contains("plugin") || haystack.contains("skill") {
            return "Skill / Plugin 开发"
        }

        if haystack.contains("telegram") || haystack.contains("discord") || haystack.contains("imessage") || haystack.contains("slack") {
            return "通信连接器"
        }

        switch scope {
        case .personal, .plugin:
            return "Claude Code"
        }
    }
}
