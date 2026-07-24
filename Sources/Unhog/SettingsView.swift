import SwiftUI

struct SettingsView: View {
    private enum Section: String, CaseIterable {
        case general = "General"
        case monitoring = "Monitoring"
        case notifications = "Notifications"
        case safety = "Safety & privacy"
        case advanced = "Advanced"

        var symbol: String {
            switch self {
            case .general: "gearshape"
            case .monitoring: "waveform.path.ecg"
            case .notifications: "bell"
            case .safety: "hand.raised"
            case .advanced: "slider.horizontal.3"
            }
        }

        var summary: String {
            switch self {
            case .general: "How Unhog appears and starts."
            case .monitoring:
                "Choose when sustained drain deserves attention."
            case .notifications:
                "Useful alerts without sample-by-sample noise."
            case .safety: "Control prompts, not process protection."
            case .advanced: "Power-user controls with safe polling limits."
            }
        }
    }

    @ObservedObject var store: AppStore
    @ObservedObject var updateController: UpdateController
    @State private var selection: Section = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selection.rawValue)
                            .font(.system(size: 22, weight: .semibold))
                        Text(selection.summary)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    content
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 650, height: 470)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            await store.refreshNotificationAuthorization()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Unhog", systemImage: "circle.lefthalf.filled")
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.bottom, 14)

            ForEach(Section.allCases, id: \.self) { section in
                Button {
                    selection = section
                } label: {
                    Label(section.rawValue, systemImage: section.symbol)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            selection == section
                                ? UnhogTheme.surfaceHover
                                : .clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
            }

            Spacer()
            Text("Local by design")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 10)
        }
        .padding(14)
        .frame(width: 178)
        .background(UnhogTheme.surface.opacity(0.45))
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .general:
            GeneralSettingsPane(
                store: store,
                updateController: updateController
            )
        case .monitoring:
            MonitoringSettingsPane(
                store: store,
                showAdvanced: { selection = .advanced }
            )
        case .notifications:
            NotificationSettingsPane(store: store)
        case .safety:
            SafetySettingsPane(store: store)
        case .advanced:
            AdvancedSettingsPane(store: store)
        }
    }
}
