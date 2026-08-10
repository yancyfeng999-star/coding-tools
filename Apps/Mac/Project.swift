import ProjectDescription

let project = Project(
    name: "CodingTools",
    options: .options(
        defaultKnownRegions: ["en", "zh-Hans"],
        developmentRegion: "zh-Hans"
    ),
    settings: .settings(
        base: [
            "SWIFT_VERSION": "6.0",
            "MACOSX_DEPLOYMENT_TARGET": "14.0",
            "ENABLE_DEBUG_DYLIB": "YES",
            "SWIFT_STRICT_CONCURRENCY": "minimal",
        ],
        debug: [
            "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
        ],
        release: [
            "ENABLE_DEBUG_DYLIB": "NO",
            "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
            "SWIFT_OPTIMIZATION_LEVEL": "-O",
        ]
    ),
    targets: [
        // ============== Foundation layers ==============

        .target(
            name: "Domain",
            destinations: .macOS,
            product: .framework,
            bundleId: "com.codingtools.domain",
            deploymentTargets: .macOS("14.0"),
            sources: ["Sources/Domain/**"]
        ),
        .target(
            name: "Catalog",
            destinations: .macOS,
            product: .framework,
            bundleId: "com.codingtools.catalog",
            deploymentTargets: .macOS("14.0"),
            sources: ["Sources/Catalog/**"],
            dependencies: [
                .target(name: "Domain"),
            ]
        ),
        .target(
            name: "ManifestSecurity",
            destinations: .macOS,
            product: .framework,
            bundleId: "com.codingtools.manifestsecurity",
            deploymentTargets: .macOS("14.0"),
            sources: ["Sources/ManifestSecurity/**"],
            dependencies: [
                .target(name: "Domain"),
            ]
        ),
        .target(
            name: "Installers",
            destinations: .macOS,
            product: .framework,
            bundleId: "com.codingtools.installers",
            deploymentTargets: .macOS("14.0"),
            sources: ["Sources/Installers/**"],
            dependencies: [
                .target(name: "Domain"),
                .target(name: "ProcessExecution"),
            ]
        ),
        .target(
            name: "ProcessExecution",
            destinations: .macOS,
            product: .framework,
            bundleId: "com.codingtools.processexecution",
            deploymentTargets: .macOS("14.0"),
            sources: ["Sources/ProcessExecution/**"]
        ),
        .target(
            name: "Detection",
            destinations: .macOS,
            product: .framework,
            bundleId: "com.codingtools.detection",
            deploymentTargets: .macOS("14.0"),
            sources: ["Sources/Detection/**"],
            dependencies: [
                .target(name: "Domain"),
                .target(name: "ProcessExecution"),
            ]
        ),
        .target(
            name: "Launching",
            destinations: .macOS,
            product: .framework,
            bundleId: "com.codingtools.launching",
            deploymentTargets: .macOS("14.0"),
            sources: ["Sources/Launching/**"],
            dependencies: [
                .target(name: "Domain"),
            ]
        ),
        .target(
            name: "Content",
            destinations: .macOS,
            product: .framework,
            bundleId: "com.codingtools.content",
            deploymentTargets: .macOS("14.0"),
            sources: ["Sources/Content/**"],
            dependencies: [
                .target(name: "Domain"),
                .target(name: "Persistence"),
            ]
        ),
        .target(
            name: "Persistence",
            destinations: .macOS,
            product: .framework,
            bundleId: "com.codingtools.persistence",
            deploymentTargets: .macOS("14.0"),
            sources: ["Sources/Persistence/**"],
            dependencies: [
                .target(name: "Domain"),
            ]
        ),
        .target(
            name: "Localization",
            destinations: .macOS,
            product: .framework,
            bundleId: "com.codingtools.localization",
            deploymentTargets: .macOS("14.0"),
            sources: ["Sources/Localization/**"]
        ),
        .target(
            name: "Theme",
            destinations: .macOS,
            product: .framework,
            bundleId: "com.codingtools.theme",
            deploymentTargets: .macOS("14.0"),
            sources: ["Sources/Theme/**"]
        ),
        .target(
            name: "Updates",
            destinations: .macOS,
            product: .framework,
            bundleId: "com.codingtools.updates",
            deploymentTargets: .macOS("14.0"),
            sources: ["Sources/Updates/**"],
            dependencies: [
                .target(name: "Domain"),
                .external(name: "Sparkle"),
            ]
        ),

        // ============== Application ==============

        .target(
            name: "UI",
            destinations: .macOS,
            product: .framework,
            bundleId: "com.codingtools.ui",
            deploymentTargets: .macOS("14.0"),
            sources: ["Sources/UI/**"],
            dependencies: [
                .target(name: "Domain"),
                .target(name: "Catalog"),
                .target(name: "Installers"),
                .target(name: "Detection"),
                .target(name: "Launching"),
                .target(name: "Content"),
                .target(name: "Persistence"),
                .target(name: "Localization"),
                .target(name: "Theme"),
                .target(name: "Updates"),
            ]
        ),
        .target(
            name: "CodingTools",
            destinations: .macOS,
            product: .app,
            bundleId: "com.codingtools.macos",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .file(path: "Sources/App/Info.plist"),
            sources: ["Sources/App/**"],
            resources: [
                "Sources/App/Resources/**",
            ],
            entitlements: .file(path: "Sources/App/entitlements.plist"),
            dependencies: [
                .target(name: "Domain"),
                .target(name: "Catalog"),
                .target(name: "ManifestSecurity"),
                .target(name: "Installers"),
                .target(name: "ProcessExecution"),
                .target(name: "Detection"),
                .target(name: "Launching"),
                .target(name: "Content"),
                .target(name: "Persistence"),
                .target(name: "Localization"),
                .target(name: "Theme"),
                .target(name: "Updates"),
                .target(name: "UI"),
                .external(name: "Sparkle"),
            ],
            settings: .settings(
                base: [
                    "PRODUCT_NAME": "Coding Tools",
                    "EXECUTABLE_NAME": "CodingTools",
                    "ENABLE_PREVIEWS": "NO",
                    "CODE_SIGN_IDENTITY": "-",
                    "CODE_SIGNING_ALLOWED": "YES",
                    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                    "INFOPLIST_KEY_LSUIElement": "YES",
                    "INFOPLIST_KEY_LSApplicationCategoryType": "public.app-category.developer-tools",
                ]
            )
        ),

        // ============== Tests ==============

        .target(
            name: "DomainTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.codingtools.domain-tests",
            deploymentTargets: .macOS("14.0"),
            sources: ["Tests/DomainTests/**"],
            dependencies: [
                .target(name: "Domain"),
            ]
        ),
        .target(
            name: "CatalogTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.codingtools.catalog-tests",
            deploymentTargets: .macOS("14.0"),
            sources: ["Tests/CatalogTests/**"],
            dependencies: [
                .target(name: "Catalog"),
                .target(name: "Domain"),
            ]
        ),
        .target(
            name: "InstallerTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.codingtools.installer-tests",
            deploymentTargets: .macOS("14.0"),
            sources: ["Tests/InstallerTests/**"],
            dependencies: [
                .target(name: "Installers"),
                .target(name: "ProcessExecution"),
                .target(name: "Domain"),
                .target(name: "Detection"),
            ]
        ),
        .target(
            name: "ManifestSecurityTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.codingtools.manifestsecurity-tests",
            deploymentTargets: .macOS("14.0"),
            sources: ["Tests/ManifestSecurityTests/**"],
            dependencies: [
                .target(name: "ManifestSecurity"),
                .target(name: "Domain"),
            ]
        ),
        .target(
            name: "AppTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.codingtools.app-tests",
            deploymentTargets: .macOS("14.0"),
            sources: ["Tests/AppTests/**"],
            dependencies: [
                .target(name: "CodingTools"),
                .target(name: "Localization"),
                .target(name: "Theme"),
                .target(name: "Content"),
                .target(name: "UI"),
                .target(name: "Domain"),
            ]
        ),
        .target(
            name: "UpdatesTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.codingtools.updates-tests",
            deploymentTargets: .macOS("14.0"),
            sources: ["Tests/UpdatesTests/**"],
            dependencies: [
                .target(name: "Updates"),
            ]
        ),
    ],
    schemes: [
        .scheme(
            name: "CodingTools",
            shared: true,
            buildAction: .buildAction(targets: [.target("CodingTools")]),
            testAction: .targets(
                [
                    TestableTarget.testableTarget(target: "DomainTests"),
                    TestableTarget.testableTarget(target: "CatalogTests"),
                    TestableTarget.testableTarget(target: "InstallerTests"),
                    TestableTarget.testableTarget(target: "ManifestSecurityTests"),
                    TestableTarget.testableTarget(target: "UpdatesTests"),
                    TestableTarget.testableTarget(target: "AppTests"),
                ]
            ),
            runAction: .runAction(configuration: .debug, executable: .target("CodingTools"))
        ),
        .scheme(
            name: "AppTests",
            shared: true,
            buildAction: .buildAction(targets: [.target("CodingTools")]),
            testAction: .targets([TestableTarget.testableTarget(target: "AppTests")])
        ),
        .scheme(
            name: "DomainTests",
            shared: true,
            buildAction: .buildAction(targets: [.target("Domain")]),
            testAction: .targets([TestableTarget.testableTarget(target: "DomainTests")])
        ),
        .scheme(
            name: "CatalogTests",
            shared: true,
            buildAction: .buildAction(targets: [.target("Catalog")]),
            testAction: .targets([TestableTarget.testableTarget(target: "CatalogTests")])
        ),
        .scheme(
            name: "InstallerTests",
            shared: true,
            buildAction: .buildAction(targets: [.target("Installers")]),
            testAction: .targets([TestableTarget.testableTarget(target: "InstallerTests")])
        ),
        .scheme(
            name: "ManifestSecurityTests",
            shared: true,
            buildAction: .buildAction(targets: [.target("ManifestSecurity")]),
            testAction: .targets([TestableTarget.testableTarget(target: "ManifestSecurityTests")])
        ),
        .scheme(
            name: "UpdatesTests",
            shared: true,
            buildAction: .buildAction(targets: [.target("Updates")]),
            testAction: .targets([TestableTarget.testableTarget(target: "UpdatesTests")])
        ),
    ]
)
