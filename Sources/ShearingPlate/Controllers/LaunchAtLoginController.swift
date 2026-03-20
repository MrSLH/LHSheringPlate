import Foundation
import ServiceManagement

enum LaunchAtLoginStatusKind {
    case enabled
    case warning
    case disabled
    case unavailable
}

struct LaunchAtLoginStatusSnapshot {
    let kind: LaunchAtLoginStatusKind
    let isEnabled: Bool
    let title: String
    let detail: String
    let serviceStatusDescription: String
    let bundlePath: String

    static func disabledFallback() -> LaunchAtLoginStatusSnapshot {
        LaunchAtLoginStatusSnapshot(
            kind: .disabled,
            isEnabled: false,
            title: "登录启动未启用",
            detail: "开启后，系统会在你登录 macOS 后自动启动 ShearingPlate。",
            serviceStatusDescription: "未注册",
            bundlePath: Bundle.main.bundleURL.path
        )
    }
}

enum LaunchAtLoginError: LocalizedError {
    case requiresAppBundle

    var errorDescription: String? {
        switch self {
        case .requiresAppBundle:
            return "请从打包后的 .app 中开启登录启动，直接使用 swift run 时无法注册。"
        }
    }
}

@MainActor
final class LaunchAtLoginController {
    private let fileManager = FileManager.default

    private var service: SMAppService {
        SMAppService.mainApp
    }

    var currentStatus: LaunchAtLoginStatusSnapshot {
        let bundleURL = Bundle.main.bundleURL.standardizedFileURL
        let serviceStatus = service.status
        let serviceStatusDescription = describe(serviceStatus: serviceStatus)

        guard bundleURL.pathExtension == "app" else {
            return LaunchAtLoginStatusSnapshot(
                kind: .unavailable,
                isEnabled: false,
                title: "当前是开发运行态",
                detail: "请从打包后的 .app 启用登录启动，`swift run` 方式无法注册登录项。",
                serviceStatusDescription: serviceStatusDescription,
                bundlePath: bundleURL.path
            )
        }

        let isInApplicationsDirectory = isInsideApplicationsDirectory(bundleURL)

        switch serviceStatus {
        case .enabled:
            if isInApplicationsDirectory {
                return LaunchAtLoginStatusSnapshot(
                    kind: .enabled,
                    isEnabled: true,
                    title: "登录启动已启用",
                    detail: "应用位于 Applications 目录，登录后会自动启动，状态稳定。",
                    serviceStatusDescription: serviceStatusDescription,
                    bundlePath: bundleURL.path
                )
            }

            return LaunchAtLoginStatusSnapshot(
                kind: .warning,
                isEnabled: true,
                title: "登录启动已启用，但应用不在 Applications",
                detail: "当前也许可以工作，但应用被移动或重命名后很容易失效。建议先移到 /Applications 或 ~/Applications。",
                serviceStatusDescription: serviceStatusDescription,
                bundlePath: bundleURL.path
            )
        case .requiresApproval:
            return LaunchAtLoginStatusSnapshot(
                kind: .warning,
                isEnabled: true,
                title: "登录启动等待系统批准",
                detail: "请前往“系统设置 > 通用 > 登录项”，确认 ShearingPlate 的登录项请求。",
                serviceStatusDescription: serviceStatusDescription,
                bundlePath: bundleURL.path
            )
        case .notFound:
            return LaunchAtLoginStatusSnapshot(
                kind: .warning,
                isEnabled: false,
                title: "系统未找到登录项",
                detail: "通常发生在应用被移动、重命名或旧注册残留后。可以重新关闭并开启一次登录启动。",
                serviceStatusDescription: serviceStatusDescription,
                bundlePath: bundleURL.path
            )
        case .notRegistered:
            return LaunchAtLoginStatusSnapshot(
                kind: .disabled,
                isEnabled: false,
                title: "登录启动未启用",
                detail: isInApplicationsDirectory
                    ? "应用已位于 Applications，可以直接开启登录启动。"
                    : "建议先把应用移到 /Applications 或 ~/Applications，再开启登录启动。",
                serviceStatusDescription: serviceStatusDescription,
                bundlePath: bundleURL.path
            )
        @unknown default:
            return LaunchAtLoginStatusSnapshot(
                kind: .warning,
                isEnabled: false,
                title: "登录启动状态未知",
                detail: "系统返回了未知状态。建议刷新一次，或重新切换登录启动开关。",
                serviceStatusDescription: serviceStatusDescription,
                bundlePath: bundleURL.path
            )
        }
    }

    func setEnabled(_ isEnabled: Bool) throws -> LaunchAtLoginStatusSnapshot {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            throw LaunchAtLoginError.requiresAppBundle
        }

        if isEnabled {
            try service.register()
        } else {
            try service.unregister()
        }

        return currentStatus
    }

    private func describe(serviceStatus: SMAppService.Status) -> String {
        switch serviceStatus {
        case .enabled:
            return "已启用"
        case .requiresApproval:
            return "等待系统批准"
        case .notFound:
            return "未找到"
        case .notRegistered:
            return "未注册"
        @unknown default:
            return "未知"
        }
    }

    private func isInsideApplicationsDirectory(_ url: URL) -> Bool {
        let standardizedPath = url.standardizedFileURL.path
        let globalApplicationsPath = "/Applications/"
        let userApplicationsPath = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
            .path + "/"

        return standardizedPath.hasPrefix(globalApplicationsPath)
            || standardizedPath.hasPrefix(userApplicationsPath)
    }
}
