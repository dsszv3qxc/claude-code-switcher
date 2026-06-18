import Foundation
import ClaudeCodeSwitcherCore

struct ClaudeVersionInfo: Equatable, Sendable {
    let currentVersion: String?
    let latestVersion: String?
    let claudePath: String?
    let npmPath: String?

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
            return "请先确认终端里可以运行 claude，再重新检查版本。"
        }

        if hasUpdate {
            return "可在终端运行：npm update -g @anthropic-ai/claude-code。也可以先运行 claude doctor 查看自动更新状态。"
        }

        if latestVersion == nil {
            return "已找到本机 claude；网络或 npm 查询失败时，可以在终端运行 npm view @anthropic-ai/claude-code version。"
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

        let latestVersion: String?
        if npmPath != nil {
            let latestOutput = shell("npm view @anthropic-ai/claude-code version --silent", timeout: 12)
            latestVersion = VersionComparator.firstVersion(in: latestOutput)
        } else {
            latestVersion = nil
        }

        return ClaudeVersionInfo(
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            claudePath: claudePath,
            npmPath: npmPath
        )
    }

    func update() async -> ClaudeVersionUpdateResult {
        let npmPath = shell("command -v npm", timeout: 4).trimmedNilIfEmpty
        guard npmPath != nil else {
            return ClaudeVersionUpdateResult(
                succeeded: false,
                message: "未找到 npm，无法自动更新 Claude Code。"
            )
        }

        let result = shellResult("npm update -g @anthropic-ai/claude-code", timeout: 180)
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

    private func shell(_ command: String, timeout: TimeInterval) -> String {
        shellResult(command, timeout: timeout).output
    }

    private func shellResult(_ command: String, timeout: TimeInterval) -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]

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
