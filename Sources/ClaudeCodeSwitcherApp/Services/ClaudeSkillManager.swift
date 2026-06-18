import AppKit
import Foundation
import ClaudeCodeSwitcherCore

struct SkillUpdateCheckResult: Equatable, Sendable {
    let state: SkillUpdateState
}

struct SkillMutationResult: Equatable, Sendable {
    let succeeded: Bool
    let message: String
}

struct ClaudeSkillManager: @unchecked Sendable {
    private let scanner: ClaudeSkillScanner

    init(scanner: ClaudeSkillScanner = ClaudeSkillScanner()) {
        self.scanner = scanner
    }

    func scan() throws -> [ClaudeSkillRecord] {
        try scanner.scan()
    }

    func reveal(_ skill: ClaudeSkillRecord) {
        NSWorkspace.shared.activateFileViewerSelecting([skill.skillFile])
    }

    func uninstall(_ skill: ClaudeSkillRecord) throws {
        guard skill.isUninstallable else {
            throw SkillManagerError.pluginSkillReadOnly
        }
        try FileManager.default.removeItem(at: skill.skillDirectory)
    }

    func pause(_ skill: ClaudeSkillRecord) throws {
        guard !skill.isPaused else {
            throw SkillManagerError.skillAlreadyPaused
        }

        let activeFile = activeSkillFile(for: skill)
        let pausedFile = pausedSkillFile(for: skill)
        guard FileManager.default.fileExists(atPath: activeFile.path) else {
            throw SkillManagerError.skillFileMissing
        }
        guard !FileManager.default.fileExists(atPath: pausedFile.path) else {
            throw SkillManagerError.pausedSkillFileConflict
        }

        try FileManager.default.moveItem(at: activeFile, to: pausedFile)
    }

    func resume(_ skill: ClaudeSkillRecord) throws {
        guard skill.isPaused else {
            throw SkillManagerError.skillAlreadyActive
        }

        let activeFile = activeSkillFile(for: skill)
        let pausedFile = pausedSkillFile(for: skill)
        guard FileManager.default.fileExists(atPath: pausedFile.path) else {
            throw SkillManagerError.pausedSkillFileMissing
        }
        guard !FileManager.default.fileExists(atPath: activeFile.path) else {
            throw SkillManagerError.activeSkillFileConflict
        }

        try FileManager.default.moveItem(at: pausedFile, to: activeFile)
    }

    func checkUpdate(for skill: ClaudeSkillRecord) async -> SkillUpdateCheckResult {
        guard !skill.isPaused else {
            return SkillUpdateCheckResult(
                state: .unavailable("这个 Skill 已暂停，恢复使用后再检查更新。")
            )
        }

        guard skill.isUninstallable else {
            return SkillUpdateCheckResult(
                state: .unavailable("插件或系统 Skill 由对应客户端管理。")
            )
        }

        guard let gitRoot = gitRoot(for: skill.skillDirectory) else {
            return SkillUpdateCheckResult(
                state: .unavailable("这个个人 Skill 不是 git 安装，无法判断远端更新。")
            )
        }

        let fetch = shell("git -C \(gitRoot.shellQuotedPath) fetch --quiet", timeout: 60)
        guard fetch.exitCode == 0 else {
            return SkillUpdateCheckResult(state: .failed(fetch.output.trimmedSingleLine))
        }

        let upstream = shell("git -C \(gitRoot.shellQuotedPath) rev-parse --abbrev-ref --symbolic-full-name @{u}", timeout: 10)
        guard upstream.exitCode == 0, !upstream.output.trimmedText.isEmpty else {
            return SkillUpdateCheckResult(
                state: .unavailable("git 仓库没有 upstream 分支，无法自动更新。")
            )
        }

        let local = shell("git -C \(gitRoot.shellQuotedPath) rev-parse HEAD", timeout: 10)
        let remote = shell("git -C \(gitRoot.shellQuotedPath) rev-parse @{u}", timeout: 10)
        guard local.exitCode == 0, remote.exitCode == 0 else {
            return SkillUpdateCheckResult(state: .failed("无法读取本地或远端提交。"))
        }

        let localSHA = local.output.trimmedText
        let remoteSHA = remote.output.trimmedText
        if localSHA == remoteSHA {
            return SkillUpdateCheckResult(state: .current("本地提交已经等于 upstream。"))
        }

        let ancestor = shell("git -C \(gitRoot.shellQuotedPath) merge-base --is-ancestor HEAD @{u}", timeout: 10)
        if ancestor.exitCode == 0 {
            return SkillUpdateCheckResult(
                state: .updateAvailable("upstream 有新提交，可执行 fast-forward 更新。")
            )
        }

        return SkillUpdateCheckResult(
            state: .unavailable("本地和 upstream 已分叉，请手动处理后再更新。")
        )
    }

    func update(_ skill: ClaudeSkillRecord) async -> SkillMutationResult {
        guard !skill.isPaused else {
            return SkillMutationResult(
                succeeded: false,
                message: "这个 Skill 已暂停，恢复使用后再更新。"
            )
        }

        guard skill.isUninstallable else {
            return SkillMutationResult(
                succeeded: false,
                message: "插件或系统 Skill 由对应客户端管理。"
            )
        }

        guard let gitRoot = gitRoot(for: skill.skillDirectory) else {
            return SkillMutationResult(
                succeeded: false,
                message: "这个个人 Skill 不是 git 安装，无法自动更新。"
            )
        }

        let result = shell("git -C \(gitRoot.shellQuotedPath) pull --ff-only", timeout: 120)
        if result.exitCode == 0 {
            return SkillMutationResult(succeeded: true, message: "Skill 更新完成。")
        }

        return SkillMutationResult(succeeded: false, message: "更新失败：\(result.output.trimmedSingleLine)")
    }

    private func gitRoot(for directory: URL) -> URL? {
        let result = shell("git -C \(directory.shellQuotedPath) rev-parse --show-toplevel", timeout: 10)
        guard result.exitCode == 0 else {
            return nil
        }

        let path = result.output.trimmedText
        guard !path.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }

    private func activeSkillFile(for skill: ClaudeSkillRecord) -> URL {
        skill.skillDirectory.appendingPathComponent(ClaudeSkillScanner.skillFileName)
    }

    private func pausedSkillFile(for skill: ClaudeSkillRecord) -> URL {
        skill.skillDirectory.appendingPathComponent(ClaudeSkillScanner.pausedSkillFileName)
    }

    private func shell(_ command: String, timeout: TimeInterval) -> ShellResult {
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

enum SkillManagerError: LocalizedError {
    case pluginSkillReadOnly
    case skillAlreadyPaused
    case skillAlreadyActive
    case skillFileMissing
    case pausedSkillFileMissing
    case pausedSkillFileConflict
    case activeSkillFileConflict

    var errorDescription: String? {
        switch self {
        case .pluginSkillReadOnly:
            "插件或系统 Skill 由对应客户端管理，不能在这里直接卸载。"
        case .skillAlreadyPaused:
            "这个 Skill 已经是暂停状态。"
        case .skillAlreadyActive:
            "这个 Skill 已经在使用中。"
        case .skillFileMissing:
            "没有找到 SKILL.md，无法暂停。"
        case .pausedSkillFileMissing:
            "没有找到暂停文件，无法恢复。"
        case .pausedSkillFileConflict:
            "目录里已经存在暂停文件，为避免覆盖，请先手动检查。"
        case .activeSkillFileConflict:
            "目录里已经存在 SKILL.md，为避免覆盖，请先手动检查。"
        }
    }
}

private extension URL {
    var shellQuotedPath: String {
        path.replacingOccurrences(of: "'", with: "'\\''")
            .withSingleQuotes
    }
}

private extension String {
    var withSingleQuotes: String {
        "'\(self)'"
    }

    var trimmedText: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedSingleLine: String {
        let trimmed = trimmedText
        if trimmed.isEmpty {
            return "没有错误输出。"
        }

        return trimmed
            .split(separator: "\n")
            .prefix(3)
            .joined(separator: " ")
    }
}
