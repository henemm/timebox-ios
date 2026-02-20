import Foundation

/// Shared build info helper for iOS + macOS Settings views.
/// Reads version, build number, and optional Git hash from the main bundle.
enum BuildInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    /// Git commit hash injected by Build Phase Script into git-hash.txt.
    static var gitHash: String? {
        guard let url = Bundle.main.url(forResource: "git-hash", withExtension: "txt"),
              let hash = try? String(contentsOf: url, encoding: .utf8),
              !hash.isEmpty else { return nil }
        return hash
    }

    /// Formatted display string: "1.0 (abc1234)" or "1.0" if no git hash.
    static var versionDisplay: String {
        if let hash = gitHash, !hash.isEmpty {
            return "\(version) (\(hash))"
        }
        return version
    }
}
