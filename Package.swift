
import PackageDescription

let package = Package(
    name: "Apodimark",
    targets: [
        Target(
            name: "Apodimark"
        ),
        Target(
            name: "ApodimarkOutput",
            dependencies: [.Target(name: "Apodimark")]
        ),
        Target(
            name: "Profiling",
            dependencies: [.Target(name: "Apodimark")]
        )
    ]
)
