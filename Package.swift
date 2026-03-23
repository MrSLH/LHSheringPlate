// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "shearingPlate",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "ShearingPlate",
            targets: ["ShearingPlate"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "ShearingPlate",
            path: "Sources/ShearingPlate",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("SwiftUI"),
                .linkedLibrary("sqlite3"),
            ]
        ),
        .testTarget(
            name: "ShearingPlateTests",
            dependencies: ["ShearingPlate"],
            path: "Tests/ShearingPlateTests"
        ),
    ]
)
