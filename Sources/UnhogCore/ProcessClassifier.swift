import Foundation

enum ProcessClassifier {
    static func tags(
        name: String,
        path: String,
        arguments: [String] = []
    ) -> Set<ProcessTag> {
        let searchable = ([name, path] + arguments)
            .joined(separator: " ")
            .lowercased()
        var result = Set<ProcessTag>()

        if searchable.contains("ms-playwright")
            || searchable.contains("/playwright/")
            || searchable.contains("chromium_headless_shell")
        {
            result.insert(.playwright)
        }

        if searchable.contains("typescript-language-server")
            || searchable.contains("tsserver")
            || searchable.contains("/tsgo")
        {
            result.insert(.typeScript)
        }

        if searchable.contains("nx-daemon")
            || searchable.contains("/nx/bin/")
            || searchable.contains("/nx/src/")
            || searchable.contains(" node_modules/.bin/nx")
        {
            result.insert(.nx)
        }

        return result
    }
}
