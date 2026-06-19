import Foundation
import ClaudeCodeSwitcherCore

struct ClaudeVersionInfo: Equatable, Sendable {
    let currentVersion: String?
    let latestVersion: String?
    let claudePath: String?
    let npmPath: String?

    var canInstall: Bool {
        claudePath == nil
    }

    var hasUpdate: Bool {
        guard let currentVersion, let latestVersion else {
            return false
        }
        return VersionComparator.isVersion(currentVersion, olderThan: latestVersion)
    }

    var summary: String {
        guard let currentVersion else {
            return "未找到 Claude Code"
        }

        if let latestVersion {
            if hasUpdate {
                return "Claude Code \(currentVersion) -> \(latestVersion) 可更新"
            } else {
                return "Claude Code \(currentVersion) 已是最新"
            }
        } else {
            return "Claude Code \(currentVersion)，未能获取最新版本"
        }
    }

    var detail: String {
        guard currentVersion != nil else {
            return "未找到本机 claude。可以点击安装按钮安装 Claude Code CLI。"
        }

        if hasUpdate {
            return "可点击更新按钮，或在终端运行 claude update。"
        }

        if latestVersion == nil {
            return "已找到本机 claude；网络查询失败时，可以在终端运行 claude doctor 或稍后再试。"
        } else {
            return "安装路径：\(claudePath ?? "未识别")"
        }
    }
}

struct ClaudeVersionUpdateResult: Equatable, Sendable {
    let succeeded: Bool
    let message: String
}

struct ClaudeVersionChecker: Sendable {
    func check() async -> ClaudeVersionInfo {
        let claudePath = shell("command -v claude", timeout: 4).trimmedNilIfEmpty
        let npmPath = shell("command -v npm", timeout: 4).trimmedNilIfEmpty

        let currentOutput = claudePath == nil ? "" : shell("claude --version", timeout: 8)
        let currentVersion = VersionComparator.firstVersion(in: currentOutput)

        let latestVersion = latestClaudeCodeVersion(npmPath: npmPath)

        return ClaudeVersionInfo(
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            claudePath: claudePath,
            npmPath: npmPath
        )
    }

    func update() async -> ClaudeVersionUpdateResult {
        let claudePath = shell("command -v claude", timeout: 4).trimmedNilIfEmpty
        guard claudePath != nil else {
            return ClaudeVersionUpdateResult(
                succeeded: false,
                message: "未找到 Claude Code，无法自动更新。"
            )
        }

        let result = shellResult("claude update", timeout: 240)
        if result.exitCode == 0 {
            return ClaudeVersionUpdateResult(
                succeeded: true,
                message: "Claude Code 更新完成，已重新检查版本。"
            )
        }

        return ClaudeVersionUpdateResult(
            succeeded: false,
            message: "更新失败：\(result.output.trimmedSingleLine)"
        )
    }

    func install() async -> ClaudeVersionUpdateResult {
        let result = shellResult("curl -fsSL https://claude.ai/install.sh | bash", timeout: 300)
        if result.exitCode == 0 {
            return ClaudeVersionUpdateResult(
                succeeded: true,
                message: "Claude Code 安装完成，已重新检查版本。"
            )
        }

        return ClaudeVersionUpdateResult(
            succeeded: false,
            message: "安装失败：\(result.output.trimmedSingleLine)"
        )
    }

    private func latestClaudeCodeVersion(npmPath: String?) -> String? {
        let nativeLatest = shell(
            "curl -fsSL https://downloads.claude.ai/claude-code-releases/latest",
            timeout: 12
        )
        if let version = VersionComparator.firstVersion(in: nativeLatest) {
            return version
        }

        guard npmPath != nil else {
            return nil
        }

        let npmLatest = shell("npm view @anthropic-ai/claude-code version --silent", timeout: 12)
        return VersionComparator.firstVersion(in: npmLatest)
    }

    private func shell(_ command: String, timeout: TimeInterval) -> String {
        shellResult(command, timeout: timeout).output
    }

    private func shellResult(_ command: String, timeout: TimeInterval) -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        process.environment = shellEnvironment()

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return ShellResult(exitCode: -1, output: "")
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }

        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return ShellResult(exitCode: Int(process.terminationStatus), output: output)
    }

    private func shellEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let existingPath = environment["PATH"] ?? ""
        let searchPaths = [
            "\(home)/.local/bin",
            "\(home)/.claude/local",
            "\(home)/.claude/local/bin",
            "\(home)/.npm-global/bin",
            "\(home)/.npm-packages/bin",
            "\(home)/.yarn/bin",
            "\(home)/.volta/bin",
            "\(home)/.bun/bin",
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/local/sbin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ] + existingPath.split(separator: ":").map(String.init)

        var seen = Set<String>()
        environment["PATH"] = searchPaths
            .filter { path in
                guard !path.isEmpty, !seen.contains(path) else {
                    return false
                }
                seen.insert(path)
                return true
            }
            .joined(separator: ":")
        environment["HOME"] = environment["HOME"] ?? home
        environment["SHELL"] = environment["SHELL"] ?? "/bin/zsh"
        return environment
    }
}

private struct ShellResult: Sendable {
    let exitCode: Int
    let output: String
}

private extension String {
    var trimmedNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var trimmedSingleLine: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "没有错误输出。"
        }

        return trimmed
            .split(separator: "\n")
            .prefix(3)
            .joined(separator: " ")
    }
}
