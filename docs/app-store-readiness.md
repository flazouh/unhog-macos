# Mac App Store readiness

Checked against Apple’s current documentation on 24 July 2026.

## Verdict

**The current Unhog product is not viable in the Mac App Store without removing its one-click stop/force-quit feature and weakening some monitoring and storage features.**

The Mac App Store requires App Sandbox. Apple explicitly lists “terminating other running apps” as incompatible with App Sandbox, and both `NSRunningApplication.terminate()` and `forceTerminate()` return `false` when a sandboxed app targets another app. The current implementation also sends `SIGTERM` and `SIGKILL` with `kill()`, but Apple DTS confirms that the sandbox blocks Unix signals to other processes and offers no temporary exception for this. [App Sandbox requirement and incompatible features](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox), [`terminate()`](https://developer.apple.com/documentation/appkit/nsrunningapplication/terminate%28%29), [`forceTerminate()`](https://developer.apple.com/documentation/appkit/nsrunningapplication/forceterminate%28%29), [Apple DTS on Unix signals](https://developer.apple.com/forums/thread/776609)

Recommended distribution for the full product: **direct distribution using Developer ID, Hardened Runtime, and Apple notarization**. A Mac App Store edition would need to be monitoring-only and should not promise that it can stop apps.

## Feasibility by feature

| Feature | Mac App Store status | Required action |
| --- | --- | --- |
| List normal GUI apps | Feasible | `NSWorkspace.runningApplications` returns running `NSRunningApplication` objects. It is not a complete Activity Monitor-style process tree. [Apple documentation](https://developer.apple.com/documentation/appkit/nsworkspace/runningapplications) |
| Inspect every helper, CLI process, daemon, CPU, RAM, path, arguments, and working directory | Uncertain/partial | The current `libproc` sampler must be tested inside a distribution-signed sandbox. Expect some process details to be unavailable and handle that as normal. App Review only permits public APIs used for their intended purpose. [Guideline 2.5.1](https://developer.apple.com/app-store/review/guidelines/#software-requirements) |
| Gracefully quit another app | **Blocked** | Sandboxed `NSRunningApplication.terminate()` returns `false`. |
| Force-quit or signal another process | **Blocked** | Sandboxed `forceTerminate()` returns `false`; Unix signals are blocked too. |
| Escape through an embedded helper | **Blocked** | An embedded helper must inherit the app’s sandbox. [Embedding a helper](https://developer.apple.com/documentation/xcode/embedding-a-helper-tool-in-a-sandboxed-app) |
| Use a privileged/root helper | **Not a valid workaround** | Authorization Services is unsupported in App Sandbox. Review guideline 2.4.5 also forbids root escalation and `setuid`. [Authorization Services](https://developer.apple.com/documentation/security/authorization-services), [guideline 2.4.5](https://developer.apple.com/app-store/review/guidelines/#hardware-compatibility) |
| Scan storage automatically across the home folder | **Blocked as currently built** | A sandboxed app has no unrestricted home-folder access. Ask the user to select folders, then use read-only security-scoped bookmarks, or limit scanning to explicitly entitled standard folders. [Sandbox file access](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox) |
| Local alerts | Feasible | Ask for notification authorization in context and respect denial. [User notification permission](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications) |
| Launch at login | Feasible with consent | `SMAppService.register()` is subject to user approval. Do not enable it automatically. [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice/register%28%29) |

## Sandbox and entitlements

At minimum, the App Store build needs:

- `com.apple.security.app-sandbox = true`. This is mandatory for Mac App Store distribution. [App Sandbox](https://developer.apple.com/documentation/security/app-sandbox)
- For user-approved folder scanning, `com.apple.security.files.user-selected.read-only = true`.
- For persistent folder access, app-scoped security-scoped bookmarks and correct `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()` handling. [Persistent sandbox access](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)
- Optional read-only entitlements for specific standard folders, such as Downloads, Music, Movies, or Pictures, only if those features remain. [Downloads entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.files.downloads.read-only)

Do **not** add temporary exception, Apple Events, accessibility, root-helper, or broad file-access entitlements as a termination workaround. Mac App Store apps cannot use temporary sandbox exceptions, and they would not solve Unix signaling anyway. [Apple DTS explanation](https://developer.apple.com/forums/thread/776609)

Current Mac App Store gaps:

- No App Sandbox entitlement file exists.
- The direct-release path uses Developer ID signing, not the Apple Distribution
  identity and provisioning needed for a Mac App Store upload.
- Storage scanning directly traverses Downloads, Documents, media folders, `~/Library/Developer`, and `~/Library/Caches` without user selection or security-scoped bookmarks.
- Agent-session scanning directly reads user home-folder tool data.
- Process termination uses both `NSRunningApplication.terminate()` and `Darwin.kill()`, which will fail in the required sandbox.

## Direct distribution status

The full app now has a separate direct-release flow in
`scripts/release-app.sh`. It is locked to the project's Developer ID
certificate and Apple team `GD7PWQBWJV`, enables Hardened Runtime, creates a
signed DMG, submits it to Apple notarization, staples the ticket, and runs a
final Gatekeeper check. Notarization is locked to a dedicated notarytool
Keychain profile so another installed account cannot be silently selected. A
separate publishing script revalidates the ticket and uploads the DMG and
SHA-256 checksum to the public `flazouh/unhog-macos` GitHub Releases page.

## Privacy declarations

- Complete App Privacy responses in App Store Connect. Apple requires these for new apps and updates. If all process and storage data stays on the Mac and is never transmitted, Apple says on-device-only processing is not “collected”; the answer may therefore be “No, we do not collect data.” Recheck this if crash reporting, analytics, licensing, or cloud features are added. [App privacy details](https://developer.apple.com/app-store/app-privacy-details/), [managing responses](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- Provide a public privacy-policy URL; Apple requires one for macOS apps. [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)
- A `PrivacyInfo.xcprivacy` file is useful if the app or an SDK declares collected data. Apple’s required-reason API declarations currently apply to iOS, iPadOS, tvOS, visionOS, and watchOS, not native macOS. If a manifest is included in a macOS app, it belongs in `Contents/Resources/`. [Privacy manifests](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files), [macOS manifest location](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk)
- The current Swift package has no third-party SDK dependencies, so Apple’s listed third-party SDK manifest/signature rule does not currently add work. Recheck after adding dependencies. [Third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/)

## Signing, archive, and upload

The current ad-hoc package is not submission-ready.

1. Join the Apple Developer Program and register the final bundle ID.
2. Create the macOS app record in App Store Connect **before** uploading. Set name, primary language, bundle ID, and SKU. [Create an app record](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/)
3. Prefer an Xcode macOS app target so signing, sandbox capabilities, provisioning, archives, validation, and uploads are reproducible. Keep Swift packages for reusable code if desired.
4. Build a Release archive with **Product > Archive**, validate it in Organizer, then choose **Distribute App > TestFlight & App Store**. Xcode can manage the Apple Distribution certificate and upload. [Xcode distribution flow](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)
5. Wait for build processing, select the build in App Store Connect, complete compliance questions, add it to a submission, and submit for review. [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds), [submit an app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app/)

For Mac App Store signing, use an **Apple Distribution** identity, not Developer ID and not an ad-hoc signature. Hardened Runtime is best practice for new code but is not the feature that removes the App Sandbox blocker. [Distribution-signed macOS code](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac), [preparing for distribution](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution)

## App Store Connect checklist

Prepare:

- Name, subtitle, description, keywords, categories, age rating, content-rights answers.
- macOS screenshots showing the real app in use.
- Support URL, privacy-policy URL, copyright, version, and review contact.
- App Review notes that clearly explain continuous menu-bar monitoring, notifications, login-item behavior, what data stays on-device, and every permission prompt.
- Price, tax category, countries/regions, release method, and export-compliance answers.

Apple requires complete and accurate metadata, a working review path, and specific notes for non-obvious features. [Required properties](https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties), [platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/), [App Review preparation](https://developer.apple.com/app-store/review/guidelines/#before-you-submit)

## Likely review blockers, ordered

1. **Certain rejection:** core quit/force-quit behavior is incompatible with mandatory App Sandbox.
2. **Certain functional failure:** current home-folder, agent-session, and storage scans lack sandbox-safe user selection and bookmarks.
3. **Submission failure:** no sandbox entitlements, Apple Distribution signature, provisioning setup, or Xcode/App Store archive workflow.
4. **Review risk:** claiming complete process visibility when the sandboxed build can only obtain partial process details.
5. **Review risk:** enabling launch-at-login or notifications without clear, contextual user consent.

The practical choice is between:

- **Full Unhog:** direct, notarized Developer ID distribution; or
- **Mac App Store Unhog:** monitoring and alerts only, user-approved folder scans, and no process termination.
