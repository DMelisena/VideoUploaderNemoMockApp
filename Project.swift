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
            sources: ["VideoUploaderNemoMockApp/Sources/**"],
            resources: ["VideoUploaderNemoMockApp/Resources/**"],
            dependencies: [
                .external(name: "ZipArchive"),
            ]
        ),
        .target(
            name: "VideoUploaderNemoMockAppTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "dev.tuist.VideoUploaderNemoMockAppTests",
            infoPlist: .default,
            sources: ["VideoUploaderNemoMockApp/Tests/**"],
            dependencies: [.target(name: "VideoUploaderNemoMockApp")]
        ),
    ]
)

