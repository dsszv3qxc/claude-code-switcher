import Foundation
import ClaudeCodeSwitcherCore

@main
struct SettingsDocumentTestRunner {
    static func main() throws {
        try appliesDeepSeekPro()
        try appliesDeepSeekFlash()
        try appliesCustomAnthropicProfile()
        try appliesOllamaProfileWithoutUserKey()
        try appliesClaudeSubscription()
        try appliesClaudeSubscriptionRemovesTopLevelDeepSeekModel()
        try detectsTopLevelDeepSeekModel()
        try detectsAndAppliesPersistentEffort()
        try appliesMaxAndClearsEffort()
        try comparesVersions()
        try parsesSkillMetadata()
        try scansPersonalAndPluginSkills()
        print("SettingsDocumentTestRunner: 12 tests passed")
    }

    private static func appliesDeepSeekPro() throws {
        var document = try SettingsDocument(data: Data("""
        {
          "model": "claude-fable-5[1m]",
          "theme": "light",
          "env": {
            "API_TIMEOUT_MS": "1200000",
            "ANTHROPIC_API_KEY": "old-api-key"
          }
        }
        """.utf8))

        try document.apply(mode: .deepSeekPro, apiKey: "  ds-test-key  ")

        let env = try require(document.object["env"] as? [String: Any], "env should exist")
        try expectEqual(document.object["model"] as? String, "deepseek-v4-pro[1m]", "top-level model")
        try expectEqual(document.object["theme"] as? String, "light", "theme should be preserved")
        try expectEqual(env["API_TIMEOUT_MS"] as? String, "1200000", "unrelated env should be preserved")
        try expectNil(env["ANTHROPIC_API_KEY"], "ANTHROPIC_API_KEY should be removed")
        try expectEqual(env["ANTHROPIC_AUTH_TOKEN"] as? String, "ds-test-key", "auth token should be trimmed")
        try expectEqual(env["ANTHROPIC_BASE_URL"] as? String, "https://api.deepseek.com/anthropic", "base URL")
        try expectEqual(env["ANTHROPIC_MODEL"] as? String, "deepseek-v4-pro[1m]", "primary model")
        try expectEqual(env["ANTHROPIC_DEFAULT_OPUS_MODEL"] as? String, "deepseek-v4-pro[1m]", "opus default")
        try expectEqual(env["ANTHROPIC_DEFAULT_SONNET_MODEL"] as? String, "deepseek-v4-pro[1m]", "sonnet default")
        try expectEqual(env["ANTHROPIC_DEFAULT_HAIKU_MODEL"] as? String, "deepseek-v4-flash", "haiku default")
        try expectEqual(env["ANTHROPIC_SMALL_FAST_MODEL"] as? String, "deepseek-v4-flash", "small fast model")
        try expectEqual(env["CLAUDE_CODE_SUBAGENT_MODEL"] as? String, "deepseek-v4-flash", "subagent model")
        try expectEqual(document.detectedMode, .deepSeekPro, "detected mode")
    }

    private static func appliesDeepSeekFlash() throws {
        var document = SettingsDocument(object: [:])

        try document.apply(mode: .deepSeekFlash, apiKey: "ds-test-key")

        let env = try require(document.object["env"] as? [String: Any], "env should exist")
        try expectEqual(env["ANTHROPIC_MODEL"] as? String, "deepseek-v4-flash", "primary model")
        try expectEqual(env["ANTHROPIC_DEFAULT_OPUS_MODEL"] as? String, "deepseek-v4-flash", "opus default")
        try expectEqual(env["ANTHROPIC_DEFAULT_SONNET_MODEL"] as? String, "deepseek-v4-flash", "sonnet default")
        try expectEqual(document.object["model"] as? String, "deepseek-v4-flash", "top-level model")
        try expectEqual(document.detectedMode, .deepSeekFlash, "detected mode")
    }

    private static func appliesCustomAnthropicProfile() throws {
        let profile = BackendProfile.custom(
            id: "test-custom",
            displayName: "Example Anthropic",
            baseURL: "https://api.example.com/anthropic",
            primaryModel: "example-main",
            fastModel: "example-fast"
        )
        var document = SettingsDocument(object: [:])

        try document.apply(profile: profile, apiKey: "example-key")

        let env = try require(document.object["env"] as? [String: Any], "env should exist")
        try expectEqual(env["ANTHROPIC_BASE_URL"] as? String, "https://api.example.com/anthropic", "custom base URL")
        try expectEqual(env["ANTHROPIC_AUTH_TOKEN"] as? String, "example-key", "custom auth token")
        try expectEqual(env["ANTHROPIC_MODEL"] as? String, "example-main", "custom primary model")
        try expectEqual(env["ANTHROPIC_DEFAULT_HAIKU_MODEL"] as? String, "example-fast", "custom fast haiku")
        try expectEqual(env["ANTHROPIC_SMALL_FAST_MODEL"] as? String, "example-fast", "custom small fast")
        try expectEqual(document.object["model"] as? String, "example-main", "custom top-level model")
        try expectEqual(document.detectedProfile(in: BackendProfile.builtIns + [profile]), profile, "custom profile detection")

        try document.apply(profile: .claudeSubscription, apiKey: nil)
        try expectNil(document.object["model"], "custom top-level model should be removed on Claude mode")
        try expectNil((document.object["env"] as? [String: Any])?["ANTHROPIC_BASE_URL"], "custom route should be removed")
    }

    private static func appliesOllamaProfileWithoutUserKey() throws {
        let profile = BackendProfile.ollama(modelName: "qwen3_6_27b_codex:latest")
        var document = SettingsDocument(object: [:])

        try document.apply(profile: profile, apiKey: nil)

        let env = try require(document.object["env"] as? [String: Any], "env should exist")
        try expectEqual(profile.needsAPIKey, false, "ollama profile should not need user api key")
        try expectEqual(env["ANTHROPIC_BASE_URL"] as? String, "http://localhost:11434", "ollama base URL")
        try expectEqual(env["ANTHROPIC_AUTH_TOKEN"] as? String, "ollama", "ollama fixed token")
        try expectEqual(env["ANTHROPIC_MODEL"] as? String, "qwen3_6_27b_codex:latest", "ollama primary model")
        try expectEqual(env["ANTHROPIC_SMALL_FAST_MODEL"] as? String, "qwen3_6_27b_codex:latest", "ollama fast model")
        try expectEqual(document.object["model"] as? String, "qwen3_6_27b_codex:latest", "ollama top-level model")
        try expectEqual(document.detectedProfile(in: BackendProfile.builtIns + [profile]), profile, "ollama profile detection")
    }

    private static func appliesClaudeSubscription() throws {
        var document = try SettingsDocument(data: Data("""
        {
          "skipWorkflowUsageWarning": true,
          "env": {
            "API_TIMEOUT_MS": "1200000",
            "ANTHROPIC_BASE_URL": "https://api.deepseek.com/anthropic",
            "ANTHROPIC_AUTH_TOKEN": "ds-test-key",
            "ANTHROPIC_MODEL": "deepseek-v4-pro[1m]",
            "ANTHROPIC_DEFAULT_OPUS_MODEL": "deepseek-v4-pro[1m]",
            "ANTHROPIC_DEFAULT_SONNET_MODEL": "deepseek-v4-pro[1m]",
            "ANTHROPIC_DEFAULT_HAIKU_MODEL": "deepseek-v4-flash",
            "ANTHROPIC_SMALL_FAST_MODEL": "deepseek-v4-flash",
            "CLAUDE_CODE_SUBAGENT_MODEL": "deepseek-v4-flash"
          }
        }
        """.utf8))

        try document.apply(mode: .claudeSubscription, apiKey: nil)

        let env = try require(document.object["env"] as? [String: Any], "env should still exist")
        try expectEqual(document.object["skipWorkflowUsageWarning"] as? Bool, true, "existing setting")
        try expectEqual(env["API_TIMEOUT_MS"] as? String, "1200000", "unrelated env")
        for key in SettingsDocument.routedEnvironmentKeys {
            try expectNil(env[key], "\(key) should be removed")
        }
        try expectEqual(document.detectedMode, .claudeSubscription, "detected mode")
    }

    private static func appliesClaudeSubscriptionRemovesTopLevelDeepSeekModel() throws {
        var document = try SettingsDocument(data: Data("""
        {
          "model": "deepseek-v4-flash",
          "theme": "light"
        }
        """.utf8))

        try document.apply(mode: .claudeSubscription, apiKey: nil)

        try expectNil(document.object["model"], "top-level DeepSeek model should be removed")
        try expectEqual(document.object["theme"] as? String, "light", "unrelated top-level setting")
        try expectEqual(document.detectedMode, .claudeSubscription, "detected mode")
    }

    private static func detectsTopLevelDeepSeekModel() throws {
        let document = try SettingsDocument(data: Data("""
        {
          "model": "deepseek-v4-flash",
          "theme": "light"
        }
        """.utf8))

        try expectEqual(document.detectedMode, .deepSeekFlash, "top-level model detected mode")
    }

    private static func detectsAndAppliesPersistentEffort() throws {
        var document = try SettingsDocument(data: Data("""
        {
          "effortLevel": "medium",
          "env": {
            "API_TIMEOUT_MS": "1200000"
          }
        }
        """.utf8))

        try expectEqual(document.detectedEffortLevel, .medium, "detect persistent effort")
        document.applyEffortLevel(.xhigh)

        let env = try require(document.object["env"] as? [String: Any], "env should remain")
        try expectEqual(document.object["effortLevel"] as? String, "xhigh", "persistent effort")
        try expectEqual(env["API_TIMEOUT_MS"] as? String, "1200000", "unrelated env")
        try expectNil(env[SettingsDocument.effortEnvironmentKey], "env effort should not be set for xhigh")
        try expectEqual(document.detectedEffortLevel, .xhigh, "detect xhigh effort")
    }

    private static func appliesMaxAndClearsEffort() throws {
        var document = try SettingsDocument(data: Data("""
        {
          "effortLevel": "high",
          "env": {
            "API_TIMEOUT_MS": "1200000"
          }
        }
        """.utf8))

        document.applyEffortLevel(.max)

        var env = try require(document.object["env"] as? [String: Any], "env should exist for max")
        try expectNil(document.object["effortLevel"], "max should not use effortLevel")
        try expectEqual(env[SettingsDocument.effortEnvironmentKey] as? String, "max", "max effort env")
        try expectEqual(document.detectedEffortLevel, .max, "detect max effort")

        document.applyEffortLevel(.auto)
        env = try require(document.object["env"] as? [String: Any], "unrelated env should remain")
        try expectNil(document.object["effortLevel"], "auto should remove effortLevel")
        try expectNil(env[SettingsDocument.effortEnvironmentKey], "auto should remove env effort")
        try expectEqual(env["API_TIMEOUT_MS"] as? String, "1200000", "unrelated env preserved")
        try expectEqual(document.detectedEffortLevel, .auto, "detect auto effort")
    }

    private static func require<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else {
            throw TestFailure(message)
        }
        return value
    }

    private static func expectEqual<T: Equatable>(_ actual: T?, _ expected: T, _ message: String) throws {
        guard actual == expected else {
            throw TestFailure("\(message): expected \(expected), got \(String(describing: actual))")
        }
    }

    private static func expectNil(_ actual: Any?, _ message: String) throws {
        guard actual == nil else {
            throw TestFailure("\(message): got \(String(describing: actual))")
        }
    }

    private static func comparesVersions() throws {
        try expectEqual(VersionComparator.firstVersion(in: "2.1.172 (Claude Code)"), "2.1.172", "extract current version")
        try expectEqual(VersionComparator.firstVersion(in: "latest: 2.1.173"), "2.1.173", "extract latest version")
        try expectEqual(VersionComparator.isVersion("2.1.172", olderThan: "2.1.173"), true, "detect update")
        try expectEqual(VersionComparator.isVersion("2.2.0", olderThan: "2.1.173"), false, "detect no update")
        try expectEqual(VersionComparator.compare("2.1.173", "2.1.173"), .orderedSame, "same version")
    }

    private static func parsesSkillMetadata() throws {
        let metadata = SkillMetadataParser.parse("""
        ---
        name: code-review
        description: Reviews pull requests and flags correctness risks.
        allowed-tools: Bash(git diff *), Read
        disable-model-invocation: true
        ---

        # Code Review
        """)

        try expectEqual(metadata.name, "code-review", "skill name")
        try expectEqual(metadata.description, "Reviews pull requests and flags correctness risks.", "skill description")
        try expectEqual(metadata.allowedTools, "Bash(git diff *), Read", "allowed tools")
        try expectEqual(metadata.disableModelInvocation, true, "disable model invocation")
    }

    private static func scansPersonalAndPluginSkills() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("claude-switcher-skill-scan-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let personalSkill = root
            .appendingPathComponent("skills")
            .appendingPathComponent("summarize")
        let pausedPersonalSkill = root
            .appendingPathComponent("skills")
            .appendingPathComponent("paused-review")
        let pluginRoot = root
            .appendingPathComponent("plugins/cache/official/superpowers/5.1.0")
        let pluginSkill = pluginRoot
            .appendingPathComponent("skills")
            .appendingPathComponent("brainstorming")

        try FileManager.default.createDirectory(at: personalSkill, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: pausedPersonalSkill, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: pluginSkill, withIntermediateDirectories: true)

        try """
        ---
        description: Summarizes local changes.
        ---

        # Summarize
        """.write(to: personalSkill.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        try """
        ---
        description: Reviews notes only when manually restored.
        ---

        # Paused Review
        """.write(
            to: pausedPersonalSkill.appendingPathComponent(ClaudeSkillScanner.pausedSkillFileName),
            atomically: true,
            encoding: .utf8
        )

        try """
        ---
        name: brainstorming
        description: Explores ideas before implementation.
        ---
        """.write(to: pluginSkill.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let installedPlugins = root.appendingPathComponent("plugins/installed_plugins.json")
        try FileManager.default.createDirectory(at: installedPlugins.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        {
          "version": 2,
          "plugins": {
            "superpowers@official": [
              {
                "scope": "user",
                "installPath": "\(pluginRoot.path)",
                "version": "5.1.0",
                "installedAt": "2026-05-24T14:22:24.001Z",
                "lastUpdated": "2026-05-25T10:24:23.717Z"
              }
            ]
          }
        }
        """.write(to: installedPlugins, atomically: true, encoding: .utf8)

        let records = try ClaudeSkillScanner(claudeHome: root).scan()
        try expectEqual(records.count, 3, "skill count")

        let personal = try require(records.first { $0.commandName == "summarize" }, "personal skill")
        try expectEqual(personal.commandName, "summarize", "personal command uses directory name")
        try expectEqual(personal.description, "Summarizes local changes.", "personal description")
        try expectEqual(personal.isUninstallable, true, "personal skill uninstallable")
        try expectEqual(personal.isPaused, false, "personal skill active")

        let paused = try require(records.first { $0.commandName == "paused-review" }, "paused skill")
        try expectEqual(paused.description, "Reviews notes only when manually restored.", "paused description")
        try expectEqual(paused.skillFile.lastPathComponent, ClaudeSkillScanner.pausedSkillFileName, "paused file path")
        try expectEqual(paused.isPaused, true, "paused skill state")

        let plugin = try require(records.first { $0.scope == .plugin }, "plugin skill")
        try expectEqual(plugin.commandName, "superpowers:brainstorming", "plugin skill is namespaced")
        try expectEqual(plugin.pluginName, "superpowers", "plugin name")
        try expectEqual(plugin.pluginVersion, "5.1.0", "plugin version")
        try expectEqual(plugin.isUninstallable, false, "plugin skill is read-only")
        try expectEqual(plugin.isPaused, false, "plugin skill active")
    }

    private struct TestFailure: Error, CustomStringConvertible {
        let description: String

        init(_ description: String) {
            self.description = description
        }
    }
}
