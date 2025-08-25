import ProjectDescription

let project = Project(
    name: "VideoUploaderNemoMockApp",
    targets: [
        .target(
            name: "VideoUploaderNemoMockApp",
            destinations: .iOS,
            product: .app,
            bundleId: "dev.tuist.VideoUploaderNemoiMockApp",
            infoPlist: .extendingDefault(
                with: [
                    "UILaunchScreen": [
                        "UIColorName": "",
                        "UIImageName": "",
                    ],
                ]
            ),
            sources: ["videoUploaderNemoMockApp/Sources/**"],
            resources: ["videoUploaderNemoMockApp/Resources/**"],
            dependencies: [
                .external(name: "ZipArchive"),
                .external(name: "HotSwiftUI"),
            ],
            settings: .settings(
                base: [
                    "OTHER_LDFLAGS": [
                        "$(inherited)", // Always include this to preserve default linker flags
                        "-Xlinker", // Passes the next argument directly to the linker
                        "-interposable", // The actual linker flag for HotSwiftUI
                    ],
                    // User defined build setting for HotSwiftUI
                    "EMIT_FRONTEND_COMMAND_LINES": "YES",
                ]
            )
        ),
        .target(
            name: "VideoUploaderNemoMockAppTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "dev.tuist.VideoUploaderNemoMockAppTests",
            infoPlist: .default,
            sources: ["videoUploaderNemoMockApp/Tests/**"],
            dependencies: [.target(name: "VideoUploaderNemoMockApp")]
        ),
    ]
)
