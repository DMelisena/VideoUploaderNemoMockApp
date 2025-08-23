import ProjectDescription

let project = Project(
    name: "videoUploaderApp",
    targets: [
        .target(
            name: "videoUploaderApp",
            destinations: .iOS,
            product: .app,
            bundleId: "dev.tuist.videoUploaderApp",
            infoPlist: .extendingDefault(
                with: [
                    "UILaunchScreen": [
                        "UIColorName": "",
                        "UIImageName": "",
                    ],
                    "NSPhotoLibraryUsageDescription": "This app needs access to your photo library to select videos for upload.",
                    "NSAppTransportSecurity": [
                        "NSAllowsArbitraryLoads": true // For localhost, consider more specific exceptions for production
                    ]
                ]
            ),
            sources: ["videoUploaderApp/Sources/**"],
            resources: ["videoUploaderApp/Resources/**"],
            dependencies: []
        ),
        .target(
            name: "videoUploaderAppTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "dev.tuist.videoUploaderAppTests",
            infoPlist: .default,
            sources: ["videoUploaderApp/Tests/**"],
            resources: [],
            dependencies: [.target(name: "videoUploaderApp")]
        ),
    ]
)
