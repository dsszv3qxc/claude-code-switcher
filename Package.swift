// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ClaudeCodeSwitcher",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Claude Code Switcher",
            targets: ["ClaudeCodeSwitcherApp"]
        ),
        .executable(
            name: "SettingsDocumentTestRunner",
            targets: ["SettingsDocumentTestRunner"]
        )
    ],
    targets: [
        .target(
            name: "ClaudeCodeSwitcherCore"
        ),
        .executableTarget(
            name: "ClaudeCodeSwitcherApp",
            dependencies: ["ClaudeCodeSwitcherCore"],
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("Security")
            ]
        ),
        .executableTarget(
            name: "SettingsDocumentTestRunner",
            dependencies: ["ClaudeCodeSwitcherCore"],
            path: "Tests/SettingsDocumentTestRunner"
        )
    ]
)
