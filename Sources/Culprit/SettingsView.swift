import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: AppStore
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Culprit")
                    .font(.system(size: 22, weight: .semibold))
                Text("A quiet guardian for runaway processes.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            SoftSurface {
                Toggle(isOn: $notificationsEnabled) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Sustained-load notifications")
                            .font(.system(size: 13, weight: .medium))
                        Text("Alert after high CPU or memory lasts 20 seconds.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .onChange(of: notificationsEnabled) { _, isEnabled in
                    store.notificationSettingChanged(isEnabled: isEnabled)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Safety")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Culprit only stops processes owned by your user. macOS system processes, other users’ processes, and Culprit itself are always protected.")
                    .font(.system(size: 12))
                    .foregroundStyle(CulpritTheme.subtleText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Text("Sampling: adaptive 2–5 seconds · Data stays on this Mac")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(width: 420, height: 320)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
