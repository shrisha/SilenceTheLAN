import Foundation

enum AppVersion {
    static var marketingVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.1"
    }

    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String ?? "3"
    }

    static var displayString: String {
        marketingVersion
    }

    static var displayStringWithBuild: String {
        "\(marketingVersion) (\(buildNumber))"
    }
}
