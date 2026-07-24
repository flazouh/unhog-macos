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
                    LoadingIndicator(size: 11)
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
                liveScanSurface
            case .complete:
                resultSurface
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

    private var liveScanSurface: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                LoadingIndicator(size: 11)
                    .foregroundStyle(UnhogTheme.cpu)

                VStack(alignment: .leading, spacing: 2) {
                    Text(scanningTitle)
                        .font(.system(size: 11, weight: .semibold))
                    Text(scanningDetail)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
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

            if !store.folders.isEmpty {
                discoveryMap
                folderResults
            }
        }
        .padding(12)
        .background(UnhogTheme.surface)
        .clipShape(
            RoundedRectangle(
                cornerRadius: UnhogTheme.cornerRadius,
                style: .continuous
            )
        )
        .animation(
            reduceMotion ? nil : UnhogTheme.motionMove,
            value: store.folders
        )
    }

    private var resultSurface: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !store.folders.isEmpty {
                discoveryMap
            }
            folderResults
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

    private var discoveryMap: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Common folders mapped")
                Spacer()
                Text(mappedStorageLabel)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.secondary)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    UnhogTheme.remainder

                    ForEach(
                        Array(mappedFolders.enumerated()),
                        id: \.element.id
                    ) { index, folder in
                        Rectangle()
                            .fill(
                                storageColor(for: folder)
                            )
                            .frame(
                                width: proxy.size.width
                                    * discoveredShare(
                                        folder.bytes
                                    )
                            )
                            .offset(
                                x: proxy.size.width
                                    * discoveredOffset(
                                        before: index
                                    )
                            )
                    }
                }
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 4,
                        style: .continuous
                    )
                )
            }
            .frame(height: 10)
            .accessibilityLabel(
                "\(mappedStorageLabel) discovered in common folders"
            )
        }
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
                        maximumBytes: maximumBytes,
                        color: storageColor(for: folder)
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

    private var mappedFolders: [StorageFolderUsage] {
        store.folders.filter { $0.status == .available }
    }

    private var mappedStorageLabel: String {
        MetricFormatting.storage(discoveredBytes)
    }

    private var scanningTitle: String {
        guard let activeID = store.scanProgress?.activeLocationID,
            let location = StorageLocation.commonLocations().first(
                where: { $0.id == activeID }
            )
        else {
            return "Finding storage…"
        }
        return "Scanning \(location.name)"
    }

    private var scanningDetail: String {
        guard let progress = store.scanProgress else {
            return "Preparing a live map"
        }
        let locationProgress =
            "\(progress.completedLocationCount) of "
            + "\(progress.totalLocationCount) folders"
        guard progress.discoveredFileCount > 0 else {
            return locationProgress
        }
        return "\(locationProgress) · "
            + "\(progress.discoveredFileCount.formatted()) files"
    }

    private func discoveredShare(_ bytes: UInt64) -> Double {
        let denominator = max(
            store.volume?.usedBytes ?? 0,
            discoveredBytes
        )
        guard denominator > 0 else {
            return 0
        }
        return Double(bytes) / Double(denominator)
    }

    private func discoveredOffset(before index: Int) -> Double {
        mappedFolders.prefix(index).reduce(0) {
            $0 + discoveredShare($1.bytes)
        }
    }

    private var discoveredBytes: UInt64 {
        store.scanProgress?.discoveredBytes
            ?? mappedFolders.reduce(0) { total, folder in
                let addition = total.addingReportingOverflow(folder.bytes)
                return addition.overflow
                    ? UInt64.max
                    : addition.partialValue
            }
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
    let color: Color

    @State private var isHovered = false
    @Environment(\.unhogReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            NSWorkspace.shared.activateFileViewerSelecting([folder.url])
        } label: {
            HStack(spacing: 10) {
                Image(systemName: symbolName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(color)
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
                    .fill(color)
                    .frame(
                        width: proxy.size.width
                            * shareOfMaximum
                    )
                    .animation(
                        reduceMotion ? nil : UnhogTheme.motionMove,
                        value: folder.bytes
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

private func storageColor(
    for folder: StorageFolderUsage
) -> Color {
    switch folder.id {
    case "downloads":
        UnhogTheme.energy
    case "applications":
        UnhogTheme.ram
    case "documents":
        UnhogTheme.selection
    case "pictures":
        UnhogTheme.ram
    case "movies":
        UnhogTheme.destructive
    case "music":
        UnhogTheme.ram
    case "developer":
        UnhogTheme.cpu
    case "caches":
        UnhogTheme.selection
    default:
        UnhogTheme.identityColor(for: folder.name)
    }
}
