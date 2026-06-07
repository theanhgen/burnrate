import ProjectDescription

let project = Project(
    name: "burnrate",
    options: .options(
        defaultKnownRegions: ["en"],
        developmentRegion: "en"
    ),
    settings: .settings(
        base: [
            "SWIFT_VERSION": "6.0",
            "MACOSX_DEPLOYMENT_TARGET": "15.0",
            "ENABLE_DEBUG_DYLIB": "YES",
        ],
        debug: [
            "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG MOCKING",
            "ENABLE_DEBUG_DYLIB": "YES",
        ],
        release: [
            "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "MOCKING",
        ]
    ),
    targets: [
        // MARK: - Domain Layer (shared: macOS + iOS)
        .target(
            name: "Domain",
            destinations: [.mac, .iPhone],
            product: .staticFramework,
            bundleId: "com.nguyentheanh.burnrate.domain",
            deploymentTargets: .multiplatform(iOS: "17.0", macOS: "15.0"),
            sources: ["Sources/Domain/**"],
            dependencies: [
                .external(name: "Mockable"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_STRICT_CONCURRENCY": "complete",
                ]
            )
        ),

        // MARK: - WidgetData Layer (shared: macOS + iOS)
        .target(
            name: "WidgetData",
            destinations: [.mac, .iPhone],
            product: .staticFramework,
            bundleId: "com.nguyentheanh.burnrate.widgetdata",
            deploymentTargets: .multiplatform(iOS: "17.0", macOS: "15.0"),
            sources: ["Sources/WidgetData/**"],
            dependencies: [
                .target(name: "Domain"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_STRICT_CONCURRENCY": "complete",
                ]
            )
        ),

        // MARK: - CloudSync Layer (shared: macOS + iOS)
        .target(
            name: "CloudSync",
            destinations: [.mac, .iPhone],
            product: .staticFramework,
            bundleId: "com.nguyentheanh.burnrate.cloudsync",
            deploymentTargets: .multiplatform(iOS: "17.0", macOS: "15.0"),
            sources: ["Sources/CloudSync/**"],
            dependencies: [
                .target(name: "Domain"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_STRICT_CONCURRENCY": "complete",
                ]
            )
        ),

        // MARK: - Infrastructure Layer
        .target(
            name: "Infrastructure",
            destinations: .macOS,
            product: .staticFramework,
            bundleId: "com.nguyentheanh.burnrate.infrastructure",
            deploymentTargets: .macOS("15.0"),
            sources: ["Sources/Infrastructure/**"],
            dependencies: [
                .target(name: "Domain"),
                .external(name: "Mockable"),
                .external(name: "SwiftTerm"),
                .external(name: "AWSCloudWatch"),
                .external(name: "AWSSTS"),
                .external(name: "AWSPricing"),
                .external(name: "AWSSDKIdentity"),
                .external(name: "AWSSSO"),
                .external(name: "AWSSSOOIDC"),
                .external(name: "SweetCookieKit"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_STRICT_CONCURRENCY": "complete",
                ]
            )
        ),

        // MARK: - Main Application
        .target(
            name: "burnrate",
            destinations: .macOS,
            product: .app,
            bundleId: "com.nguyentheanh.burnrate",
            deploymentTargets: .macOS("15.0"),
            infoPlist: .file(path: "Sources/App/Info.plist"),
            sources: ["Sources/App/**"],
            resources: [
                "Sources/App/Resources/**",
            ],
            entitlements: .file(path: "Sources/App/entitlements.plist"),
            dependencies: [
                .target(name: "Domain"),
                .target(name: "Infrastructure"),
                .target(name: "CloudSync"),
                .target(name: "WidgetData"),
                .target(name: "BurnrateWidgetExtensionMac"),
                .external(name: "Sparkle"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_STRICT_CONCURRENCY": "complete",
                    "ENABLE_DEBUG_DYLIB": "YES",
                    "ENABLE_PREVIEWS": "YES",
                    "CODE_SIGN_STYLE": "Automatic",
                    "DEVELOPMENT_TEAM": "28DMV2MR8T",
                    "CODE_SIGN_IDENTITY": "",
                    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                ],
                debug: [
                    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG ENABLE_SPARKLE ENABLE_CLOUDSYNC",
                ],
                release: [
                    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "ENABLE_SPARKLE ENABLE_CLOUDSYNC",
                ]
            )
        ),

        // MARK: - macOS Widget Extension
        .target(
            name: "BurnrateWidgetExtensionMac",
            destinations: [.mac, .iPhone],
            product: .appExtension,
            bundleId: "com.nguyentheanh.burnrate.widget",
            deploymentTargets: .multiplatform(iOS: "17.0", macOS: "15.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": .string("burnrate Widget"),
                "CFBundleShortVersionString": .string("0.1.0"),
                "CFBundleVersion": .string("1"),
                "NSExtension": .dictionary([
                    "NSExtensionPointIdentifier": .string("com.apple.widgetkit-extension"),
                ]),
            ]),
            sources: ["Sources/BurnrateWidget/**"],
            resources: [
                "Sources/BurnrateWidget/Resources/**",
            ],
            entitlements: .file(path: "Sources/BurnrateWidgetMac/entitlements.plist"),
            dependencies: [
                .target(name: "WidgetData"),
                .target(name: "Domain"),
                .target(name: "CloudSync"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_STRICT_CONCURRENCY": "complete",
                ]
            )
        ),

        // MARK: - iOS Application
        .target(
            name: "burnrate-ios",
            destinations: [.iPhone],
            product: .app,
            bundleId: "com.nguyentheanh.burnrate",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .file(path: "Sources/iOSApp/Info.plist"),
            sources: ["Sources/iOSApp/**"],
            resources: [
                "Sources/iOSApp/Resources/**",
            ],
            entitlements: .file(path: "Sources/iOSApp/entitlements.plist"),
            dependencies: [
                .target(name: "Domain"),
                .target(name: "CloudSync"),
                .target(name: "WidgetData"),
                .target(name: "BurnrateWidgetExtension"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_STRICT_CONCURRENCY": "complete",
                    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                    "CODE_SIGN_STYLE": "Automatic",
                    "DEVELOPMENT_TEAM": "28DMV2MR8T",
                    "CODE_SIGN_IDENTITY": "",
                ]
            )
        ),

        // MARK: - iOS Widget Extension
        .target(
            name: "BurnrateWidgetExtension",
            destinations: [.iPhone],
            product: .appExtension,
            bundleId: "com.nguyentheanh.burnrate.widget",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": .string("burnrate Widget"),
                "CFBundleShortVersionString": .string("0.1.0"),
                "CFBundleVersion": .string("2"),
                "NSExtension": .dictionary([
                    "NSExtensionPointIdentifier": .string("com.apple.widgetkit-extension"),
                ]),
            ]),
            sources: ["Sources/BurnrateWidget/**"],
            resources: [
                "Sources/BurnrateWidget/Resources/**",
            ],
            entitlements: .file(path: "Sources/BurnrateWidget/entitlements.plist"),
            dependencies: [
                .target(name: "WidgetData"),
                .target(name: "Domain"),
                .target(name: "CloudSync"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_STRICT_CONCURRENCY": "complete",
                    "CODE_SIGN_STYLE": "Automatic",
                    "DEVELOPMENT_TEAM": "28DMV2MR8T",
                    "CODE_SIGN_IDENTITY": "",
                ]
            )
        ),

        // MARK: - MCP Server CLI
        .target(
            name: "burnrate-mcp",
            destinations: .macOS,
            product: .commandLineTool,
            bundleId: "com.nguyentheanh.burnrate.mcp",
            deploymentTargets: .macOS("15.0"),
            sources: ["Sources/MCPServer/**"],
            settings: .settings(
                base: [
                    "SWIFT_STRICT_CONCURRENCY": "complete",
                ]
            )
        ),

        // MARK: - Infrastructure (MAS) -- sandbox-safe, no CLI dependencies
        .target(
            name: "Infrastructure-MAS",
            destinations: .macOS,
            product: .staticFramework,
            bundleId: "com.nguyentheanh.burnrate.infrastructure-mas",
            deploymentTargets: .macOS("15.0"),
            sources: ["Sources/Infrastructure/**"],
            dependencies: [
                .target(name: "Domain"),
                .external(name: "Mockable"),
                .external(name: "AWSCloudWatch"),
                .external(name: "AWSSTS"),
                .external(name: "AWSPricing"),
                .external(name: "AWSSDKIdentity"),
                .external(name: "AWSSSO"),
                .external(name: "AWSSSOOIDC"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_STRICT_CONCURRENCY": "complete",
                    "PRODUCT_NAME": "Infrastructure",
                    "PRODUCT_MODULE_NAME": "Infrastructure",
                ],
                debug: [
                    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG MOCKING MAS_BUILD",
                ],
                release: [
                    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "MOCKING MAS_BUILD",
                ]
            )
        ),

        // MARK: - Mac App Store Application
        .target(
            name: "burnrate-mas",
            destinations: .macOS,
            product: .app,
            bundleId: "com.nguyentheanh.burnrate",
            deploymentTargets: .macOS("15.0"),
            infoPlist: .file(path: "Sources/App/Info.plist"),
            sources: ["Sources/App/**"],
            resources: [
                "Sources/App/Resources/**",
            ],
            entitlements: .file(path: "Sources/App/entitlements.mas.plist"),
            dependencies: [
                .target(name: "Domain"),
                .target(name: "Infrastructure-MAS"),
                .target(name: "CloudSync"),
                .target(name: "WidgetData"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_STRICT_CONCURRENCY": "complete",
                    "ENABLE_PREVIEWS": "YES",
                    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                    "PRODUCT_NAME": "burnrate",
                    "CODE_SIGN_STYLE": "Automatic",
                    "DEVELOPMENT_TEAM": "28DMV2MR8T",
                    // Empty string clears Tuist's default CODE_SIGN_IDENTITY="-" so
                    // Automatic signing can select the identity for each configuration.
                    "CODE_SIGN_IDENTITY": "",
                ],
                debug: [
                    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG MAS_BUILD ENABLE_CLOUDSYNC",
                ],
                release: [
                    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "MAS_BUILD ENABLE_CLOUDSYNC",
                ]
            )
        ),

        // MARK: - Domain Tests
        .target(
            name: "DomainTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.nguyentheanh.burnrate.domain-tests",
            deploymentTargets: .macOS("15.0"),
            sources: ["Tests/DomainTests/**"],
            dependencies: [
                .target(name: "Domain"),
                .target(name: "Infrastructure"),
                .external(name: "Mockable"),
                .external(name: "AWSCloudWatch"),
                .external(name: "AWSSTS"),
                .external(name: "AWSPricing"),
                .external(name: "AWSSDKIdentity"),
                .external(name: "AWSSSO"),
                .external(name: "AWSSSOOIDC"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "MOCKING",
                ]
            )
        ),

        // MARK: - Infrastructure Tests
        .target(
            name: "InfrastructureTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.nguyentheanh.burnrate.infrastructure-tests",
            deploymentTargets: .macOS("15.0"),
            sources: ["Tests/InfrastructureTests/**"],
            dependencies: [
                .target(name: "Infrastructure"),
                .target(name: "Domain"),
                .external(name: "Mockable"),
                .external(name: "AWSCloudWatch"),
                .external(name: "AWSSTS"),
                .external(name: "AWSPricing"),
                .external(name: "AWSSDKIdentity"),
                .external(name: "AWSSSO"),
                .external(name: "AWSSSOOIDC"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "MOCKING",
                ]
            )
        ),

        // MARK: - CloudSync Tests
        .target(
            name: "CloudSyncTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.nguyentheanh.burnrate.cloudsync-tests",
            deploymentTargets: .macOS("15.0"),
            sources: ["Tests/CloudSyncTests/**"],
            dependencies: [
                .target(name: "CloudSync"),
                .target(name: "Domain"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "MOCKING",
                ]
            )
        ),

        // MARK: - Acceptance Tests (BDD - Outer Loop)
        .target(
            name: "AcceptanceTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.nguyentheanh.burnrate.acceptance-tests",
            deploymentTargets: .macOS("15.0"),
            sources: ["Tests/AcceptanceTests/**"],
            dependencies: [
                .target(name: "Domain"),
                .target(name: "Infrastructure"),
                .external(name: "Mockable"),
                .external(name: "AWSCloudWatch"),
                .external(name: "AWSSTS"),
                .external(name: "AWSPricing"),
                .external(name: "AWSSDKIdentity"),
                .external(name: "AWSSSO"),
                .external(name: "AWSSSOOIDC"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "MOCKING",
                ]
            )
        ),
    ],
    schemes: [
        .scheme(
            name: "burnrate-ios",
            shared: true,
            buildAction: .buildAction(targets: ["burnrate-ios"]),
            runAction: .runAction(configuration: .debug, executable: .target("burnrate-ios")),
            archiveAction: .archiveAction(configuration: .release),
            profileAction: .profileAction(configuration: .release, executable: .target("burnrate-ios")),
            analyzeAction: .analyzeAction(configuration: .debug)
        ),
        .scheme(
            name: "burnrate",
            shared: true,
            buildAction: .buildAction(targets: ["burnrate"]),
            testAction: .targets(
                [
                    .testableTarget(target: .target("AcceptanceTests")),
                    .testableTarget(target: .target("CloudSyncTests")),
                    .testableTarget(target: .target("DomainTests")),
                    .testableTarget(target: .target("InfrastructureTests")),
                ],
                configuration: .debug
            ),
            runAction: .runAction(configuration: .debug, executable: .target("burnrate")),
            archiveAction: .archiveAction(configuration: .release),
            profileAction: .profileAction(configuration: .release, executable: .target("burnrate")),
            analyzeAction: .analyzeAction(configuration: .debug)
        ),
        .scheme(
            name: "burnrate-mas",
            shared: true,
            buildAction: .buildAction(targets: ["burnrate-mas"]),
            runAction: .runAction(configuration: .debug, executable: .target("burnrate-mas")),
            archiveAction: .archiveAction(configuration: .release),
            profileAction: .profileAction(configuration: .release, executable: .target("burnrate-mas")),
            analyzeAction: .analyzeAction(configuration: .debug)
        ),
        .scheme(
            name: "burnrate-mcp",
            shared: true,
            buildAction: .buildAction(targets: ["burnrate-mcp"]),
            runAction: .runAction(configuration: .debug, executable: .target("burnrate-mcp")),
            archiveAction: .archiveAction(configuration: .release),
            analyzeAction: .analyzeAction(configuration: .debug)
        ),
    ]
)
