import AppKit
import Combine
import CulpritCore
import Foundation

@MainActor
final class AppStore: ObservableObject {
    enum StopState: Equatable {
        case idle
        case quitting(ProcessGroupID)
        case forceAvailable(ProcessGroupID)
        case forceKilling(ProcessGroupID)
    }

    @Published private(set) var groups: [ProcessGroup] = []
    @Published private(set) var incidents: [ResourceIncident] = []
    @Published private(set) var isPreparing = true
    @Published private(set) var stopState: StopState = .idle
    @Published private(set) var message: String?
    @Published private(set) var pendingForceName: String?
    @Published var selectedGroupID: ProcessGroupID?

    private let monitor: ProcessMonitor
    private let terminator: SystemProcessTerminator
    private let grouper = ProcessGrouper()
    private let terminationPolicy: TerminationPolicy
    private let notifications = NotificationController()
    private let currentUID: UInt32
    private let appPID: Int32
    private var detector: ResourcePressureDetector
    private var monitoringTask: Task<Void, Never>?
    private var sampleCount = 0
    private var notifiedIncidentIDs = Set<ProcessGroupID>()
    private var latestGroups: [ProcessGroup] = []
    private var latestProcessIdentities = Set<ProcessIdentity>()
    private var previousGroupMemory: [ProcessGroupID: UInt64] = [:]
    private var pressureIsRising = false
    private var pendingForcePlan: TerminationPlan?
    private var pendingForceGroup: ProcessGroup?

    init(
        monitor: ProcessMonitor = ProcessMonitor(),
        currentUID: UInt32 = getuid(),
        appPID: Int32 = getpid()
    ) {
        self.monitor = monitor
        self.currentUID = currentUID
        self.appPID = appPID
        self.detector = ResourcePressureDetector(
            thresholds: .forInstalledMemory(
                ProcessInfo.processInfo.physicalMemory
            )
        )
        self.terminator = SystemProcessTerminator(currentUID: currentUID)
        self.terminationPolicy = TerminationPolicy(
            currentUID: currentUID,
            appPID: appPID
        )
        UserDefaults.standard.register(defaults: ["notificationsEnabled": true])
    }

    var activeIncident: ResourceIncident? {
        incidents.first
    }

    var installedMemoryBytes: UInt64 {
        ProcessInfo.processInfo.physicalMemory
    }

    var memoryComposition: MemoryComposition {
        MemoryComposition(
            installedBytes: installedMemoryBytes,
            groups: latestGroups,
            maximumVisibleSegments: 3
        )
    }

    func ramShare(for group: ProcessGroup) -> Double {
        guard installedMemoryBytes > 0 else { return 0 }
        return min(
            1,
            Double(group.memoryBytes) / Double(installedMemoryBytes)
        )
    }

    func batteryEstimate(for group: ProcessGroup) -> BatteryDrainEstimate {
        BatteryDrainEstimate(cpuPercent: group.cpuPercent)
    }

    var menuBarSymbol: String {
        switch activeIncident?.severity {
        case .high:
            "exclamationmark.circle.fill"
        case .elevated:
            "exclamationmark.circle"
        case nil:
            isPreparing ? "circle.dotted" : "circle"
        }
    }

    var menuBarAccessibilityLabel: String {
        if let incident = activeIncident {
            return "\(incident.group.displayName) is creating system pressure"
        }
        return isPreparing ? "Culprit is measuring system activity" : "System activity is calm"
    }

    func start() {
        guard monitoringTask == nil else { return }

        monitoringTask = Task { [weak self] in
            if UserDefaults.standard.bool(forKey: "notificationsEnabled"),
               let notifications = self?.notifications {
                await notifications.requestPermission()
            }

            while !Task.isCancelled {
                guard let interval = await self?.refreshAndNextInterval() else {
                    return
                }
                try? await Task.sleep(for: interval)
            }
        }
    }

    func toggleDetails(for id: ProcessGroupID) {
        selectedGroupID = selectedGroupID == id ? nil : id
    }

    func capability(for group: ProcessGroup) -> TerminationCapability {
        terminationPolicy.plan(for: group).capability
    }

    func requestQuit(_ id: ProcessGroupID) {
        guard stopState == .idle || stopState == .forceAvailable(id),
              let group = group(with: id) else {
            return
        }

        let plan = terminationPolicy.plan(for: group)
        guard plan.capability == .allowed else {
            if case let .protected(reason) = plan.capability {
                message = reason
            }
            return
        }

        stopState = .quitting(id)
        message = nil
        pendingForceName = nil
        pendingForcePlan = nil
        pendingForceGroup = nil

        Task {
            let usedNormalApplicationQuit: Bool
            let signalResult: TerminationResult?

            if case .application = group.kind,
               let application = NSRunningApplication(
                   processIdentifier: group.id.rootPID
               ) {
                usedNormalApplicationQuit = application.terminate()
                signalResult = nil
            } else {
                usedNormalApplicationQuit = false
                signalResult = await terminator.terminate(plan, mode: .graceful)
            }

            try? await Task.sleep(for: .seconds(2))
            await refresh()

            let remaining = plan.targets.filter {
                latestProcessIdentities.contains($0)
            }

            if !remaining.isEmpty {
                if let refreshedGroup = refreshedGroup(
                    from: group,
                    keeping: remaining
                ) {
                    let refreshedPlan = terminationPolicy.plan(for: refreshedGroup)
                    if refreshedPlan.capability == .allowed,
                       !refreshedPlan.targets.isEmpty {
                        pendingForcePlan = refreshedPlan
                        pendingForceGroup = refreshedGroup
                        pendingForceName = group.displayName
                        stopState = .forceAvailable(id)
                        message = "\(remaining.count) process\(remaining.count == 1 ? "" : "es") did not quit."
                    } else {
                        stopState = .idle
                        message = "The remaining process became protected and was not stopped."
                    }
                } else {
                    stopState = .idle
                    message = "The original processes stopped."
                }
            } else {
                let restarted = latestGroups.contains {
                    $0.id == group.id && !$0.processes.isEmpty
                }
                stopState = .idle
                if restarted {
                    message = "\(group.displayName) stopped, but it restarted."
                } else if let signalResult, !signalResult.failures.isEmpty {
                    message = "Quit completed with \(signalResult.failures.count) warning\(signalResult.failures.count == 1 ? "" : "s")."
                } else if case .application = group.kind, !usedNormalApplicationQuit {
                    message = "The app did not accept a normal quit request."
                } else {
                    message = "The original \(group.displayName) processes stopped."
                }
            }
        }
    }

    func requestForceQuit(_ id: ProcessGroupID) {
        guard stopState == .forceAvailable(id),
              let oldPlan = pendingForcePlan,
              let oldGroup = pendingForceGroup,
              let refreshedGroup = refreshedGroup(
                  from: oldGroup,
                  keeping: oldPlan.targets
              ) else {
            cancelPendingForceQuit()
            return
        }

        let plan = terminationPolicy.plan(for: refreshedGroup)
        guard plan.capability == .allowed, !plan.targets.isEmpty else {
            cancelPendingForceQuit()
            message = "The remaining process became protected and was not stopped."
            return
        }

        stopState = .forceKilling(id)
        message = nil
        let displayName = pendingForceName ?? "Process family"

        Task {
            let result = await terminator.terminate(plan, mode: .force)
            try? await Task.sleep(for: .milliseconds(600))
            await refresh()
            let remaining = plan.targets.filter {
                latestProcessIdentities.contains($0)
            }
            stopState = .idle
            pendingForcePlan = nil
            pendingForceGroup = nil
            pendingForceName = nil
            message = remaining.isEmpty && result.failures.isEmpty
                ? "\(displayName) was force quit."
                : "\(max(remaining.count, result.failures.count)) process\(max(remaining.count, result.failures.count) == 1 ? "" : "es") could not be stopped."
        }
    }

    func notificationSettingChanged(isEnabled: Bool) {
        guard isEnabled else { return }
        Task {
            await notifications.requestPermission()
        }
    }

    func dismissMessage() {
        if case .forceAvailable = stopState { return }
        message = nil
    }

    func cancelPendingForceQuit() {
        guard case .forceAvailable = stopState else { return }
        stopState = .idle
        pendingForcePlan = nil
        pendingForceGroup = nil
        pendingForceName = nil
        message = nil
    }

    func quitApplication() {
        NSApp.terminate(nil)
    }

    private func refresh() async {
        let samples = await monitor.sample()
        let userSamples = samples.filter {
            $0.ownerUID == currentUID && $0.identity.pid != appPID
        }
        let allGroups = grouper.groups(from: userSamples)
        let newIncidents = detector.evaluate(allGroups)
        let memoryIsGrowing = allGroups.contains { group in
            guard let previous = previousGroupMemory[group.id] else {
                return false
            }
            return group.memoryBytes > previous + 100_000_000
        }

        sampleCount += 1
        isPreparing = sampleCount < 2
        latestGroups = allGroups
        latestProcessIdentities = Set(samples.map(\.identity))
        previousGroupMemory = Dictionary(
            uniqueKeysWithValues: allGroups.map { ($0.id, $0.memoryBytes) }
        )
        pressureIsRising = !newIncidents.isEmpty
            || memoryIsGrowing
            || allGroups.contains { $0.cpuPercent >= 100 }
        let incidentIDs = Set(newIncidents.map(\.id))
        groups = Array(
            allGroups
                .filter { $0.cpuPercent >= 0.5 || $0.memoryBytes >= 30_000_000 }
                .sorted {
                    let leftNeedsAttention = incidentIDs.contains($0.id)
                    let rightNeedsAttention = incidentIDs.contains($1.id)
                    if leftNeedsAttention != rightNeedsAttention {
                        return leftNeedsAttention
                    }
                    if $0.memoryBytes != $1.memoryBytes {
                        return $0.memoryBytes > $1.memoryBytes
                    }
                    return $0.cpuPercent > $1.cpuPercent
                }
                .prefix(6)
        )
        incidents = newIncidents

        let activeIDs = Set(newIncidents.map(\.id))
        notifiedIncidentIDs.formIntersection(activeIDs)

        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else {
            return
        }

        for incident in newIncidents where notifiedIncidentIDs.insert(incident.id).inserted {
            await notifications.send(incident)
        }
    }

    private func group(with id: ProcessGroupID) -> ProcessGroup? {
        latestGroups.first { $0.id == id }
            ?? incidents.first { $0.id == id }?.group
    }

    private var nextSamplingInterval: Duration {
        return pressureIsRising ? .seconds(2) : .seconds(5)
    }

    private func refreshAndNextInterval() async -> Duration {
        await refresh()
        return nextSamplingInterval
    }

    private func refreshedGroup(
        from original: ProcessGroup,
        keeping identities: [ProcessIdentity]
    ) -> ProcessGroup? {
        let wanted = Set(identities)
        let processes = latestGroups
            .flatMap(\.processes)
            .filter { wanted.contains($0.identity) }
        guard !processes.isEmpty else { return nil }

        return ProcessGroup(
            id: original.id,
            kind: original.kind,
            displayName: original.displayName,
            origin: original.origin,
            processes: processes
        )
    }
}
