import Foundation

enum UnhogResourceBundle {
    static let bundle: Bundle? = {
        let bundleName = "Unhog_Unhog.bundle"
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent(bundleName),
            Bundle.main.bundleURL.appendingPathComponent(bundleName),
        ]
        for candidate in candidates.compactMap({ $0 }) {
            if let bundle = Bundle(url: candidate) {
                return bundle
            }
        }
        return nil
    }()
}
