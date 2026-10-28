import Foundation

/// Where feedback and bug reports go. Bug reports carry the app and macOS versions so they can be reproduced.
nonisolated enum SupportLinks {
    static let email = "admin@lazycatlabs.com"
    static let website = URL(string: "https://copaste.lazycatlabs.com")!
    static let sourceCode = URL(string: "https://github.com/lazycatlabs/copaste")!
    static let license = URL(string: "https://github.com/lazycatlabs/copaste/blob/main/LICENSE")!

    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    static func feedback() -> URL? {
        mail(subject: L(.feedbackSubject), body: "")
    }

    static func bugReport(appVersion: String = appVersion,
                          systemVersion: String = ProcessInfo.processInfo.operatingSystemVersionString) -> URL? {
        mail(subject: L(.bugReportSubject), body: L(.bugReportBody(appVersion, systemVersion)))
    }

    static func mail(subject: String, body: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: body)]
            .filter { !($0.value ?? "").isEmpty }
        return components.url
    }
}
