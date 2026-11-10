import Foundation

enum AppMetadata {
    static let author = "Wenshuishi0528"
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发版"
    static let repositoryURL = URL(string: "https://github.com/Wenshuishi0528/cherry-mx31-lighting-mac")!
    static let licenseURL = URL(string: "https://creativecommons.org/licenses/by-nc/4.0/")!
}
