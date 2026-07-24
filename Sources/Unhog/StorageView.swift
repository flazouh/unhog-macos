import AppKit
import SwiftUI
import UnhogCore

struct StorageView: View {
    @ObservedObject var store: StorageStore

    @Environment(\.unhogReduceMotion) private var reduceMotion
    @State private var revealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            capacity
            folders
        }
        .onAppear {
            store.prepare()
            if reduceMotion {
                revealed = true
            } else {
                withAnimation(UnhogTheme.motionEnter) {
                    revealed = true
                }
            }
        }
    }

    private var capacity: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text("Mac storage")
                    .font(.system(size: 12, weight: .semibold))

                Spacer()

                if let volume = store.volume {
                    Text(
                        "\(MetricFormatting.storage(volume.totalBytes)) total"
                    )
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }
            }

            if let volume = store.volume {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(UnhogTheme.remainder)

                        Rectangle()
                            .fill(capacityColor(for: volume))
                            .frame(
                                width: proxy.size.width
                                    * max(0, min(1, volume.usedShare))
                                    * (revealed ? 1 : 0)
                            )
                    }
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 5,
                            style: .continuous
                        )
                    )
                }
                .frame(height: 18)

                HStack {
                    Text(
                        "\(MetricFormatting.storage(volume.usedBytes)) used"
                    )
                    Spacer()
                    Text(
                        "\(MetricFormatting.storage(volume.availableBytes)) free"
                    )
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            } else if case let .failed(message) = store.scanState {
                storageError(message)
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Reading disk capacity…")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(height: 36)
            }
        }
    }

    private var folders: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Common folders")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Scans only when you ask")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if store.scanState == .complete {
                    Button("Scan again") {
                        store.scan()
                    }
                    .buttonStyle(
                        InlineActionStyle(
                            tone: .secondary,
                            compact: true
                        )
                    )
                }
            }

            switch store.scanState {
            case .idle:
                scanPrompt
            case .scanning:
                scanningState
            case .complete:
                folderResults
            case let .failed(message):
                VStack(alignment: .leading, spacing: 8) {
                    storageError(message)
                    Button("Try again") {
                        store.scan()
                    }
                    .buttonStyle(
                        InlineActionStyle(
                            tone: .primary,
                            compact: true
                        )
                    )
                }
            }
        }
    }

    private var scanPrompt: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(UnhogTheme.cpu)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("See what is taking space")
                    .font(.system(size: 11, weight: .semibold))
                Text("Read-only · nothing is deleted")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Scan") {
                store.scan()
            }
            .buttonStyle(
                InlineActionStyle(
                    tone: .primary,
                    compact: true
                )
            )
        }
        .padding(12)
        .background(UnhogTheme.surface)
        .clipShape(
            RoundedRectangle(
                cornerRadius: UnhogTheme.cornerRadius,
                style: .continuous
            )
        )
    }

    private var scanningState: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            VStack(alignment: .leading, spacing: 2) {
                Text("Scanning common folders…")
                    .font(.system(size: 11, weight: .semibold))
                Text("Runs at utility priority")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Cancel") {
                store.cancelScan()
            }
            .buttonStyle(
                InlineActionStyle(
                    tone: .secondary,
                    compact: true
                )
            )
        }
        .padding(12)
        .background(UnhogTheme.surface)
        .clipShape(
            RoundedRectangle(
                cornerRadius: UnhogTheme.cornerRadius,
                style: .continuous
            )
        )
    }

    @ViewBuilder
    private var folderResults: some View {
        let available = store.folders.filter {
            $0.status == .available
        }
        let maximumBytes = available.map(\.bytes).max() ?? 0

        if available.isEmpty {
            Text("No readable folders were found.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.vertical, 12)
        } else {
            VStack(spacing: 4) {
                ForEach(available.prefix(6)) { folder in
                    StorageFolderRow(
                        folder: folder,
                        maximumBytes: maximumBytes
                    )
                    .transition(.opacity)
                }
            }
        }

        let unavailableCount = store.folders.filter {
            $0.status == .unavailable
        }.count
        if unavailableCount > 0 {
            Label(
                "\(unavailableCount) folder"
                    + (unavailableCount == 1 ? "" : "s")
                    + " could not be read",
                systemImage: "lock"
            )
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.top, 2)
        }
    }

    private func storageError(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle")
            .font(.system(size: 10))
            .foregroundStyle(UnhogTheme.attention)
    }

    private func capacityColor(
        for volume: StorageVolumeSnapshot
    ) -> Color {
        let freeShare = 1 - volume.usedShare
        if freeShare < 0.10 {
            return UnhogTheme.destructive
        }
        if freeShare < 0.20 {
            return UnhogTheme.energy
        }
        return UnhogTheme.ram
    }
}

private struct StorageFolderRow: View {
    let folder: StorageFolderUsage
    let maximumBytes: UInt64

    @State private var isHovered = false

    var body: some View {
        Button {
            NSWorkspace.shared.activateFileViewerSelecting([folder.url])
        } label: {
            HStack(spacing: 10) {
                Image(systemName: symbolName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(
                        UnhogTheme.identityColor(for: folder.name)
                    )
                    .frame(width: 18)

                Text(folder.name)
                    .font(.system(size: 11, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)

                usageBar
                    .frame(width: 64, height: 4)

                Text(MetricFormatting.storage(folder.bytes))
                    .font(
                        .system(
                            size: 10,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .monospacedDigit()
                    .frame(width: 58, alignment: .trailing)

                Image(systemName: "arrow.forward")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .opacity(isHovered ? 1 : 0.42)
            }
            .padding(.horizontal, 8)
            .frame(minHeight: 34)
            .background(
                isHovered
                    ? UnhogTheme.surfaceHover
                    : Color.clear
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: UnhogTheme.compactRadius,
                    style: .continuous
                )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(
            "\(folder.name), "
                + MetricFormatting.storage(folder.bytes)
                + ". Reveal in Finder."
        )
    }

    private var usageBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(UnhogTheme.remainder)
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        UnhogTheme.identityColor(for: folder.name)
                    )
                    .frame(
                        width: proxy.size.width
                            * shareOfMaximum
                    )
            }
        }
    }

    private var shareOfMaximum: Double {
        guard maximumBytes > 0 else { return 0 }
        return Double(folder.bytes) / Double(maximumBytes)
    }

    private var symbolName: String {
        switch folder.id {
        case "downloads":
            "arrow.down.circle"
        case "applications":
            "app.dashed"
        case "documents":
            "doc"
        case "pictures":
            "photo"
        case "movies":
            "film"
        case "music":
            "music.note"
        case "developer":
            "hammer"
        case "caches":
            "shippingbox"
        default:
            "folder"
        }
    }
}
