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
    @Published private(set) var recoveryAssessment: RecoveryAssessment?
    @Published private(set) var resolvingGroup: ProcessGroup?
    @Published private(set) var message: String?
    @Published private(set) var pendingForceName: String?
    @Published var selectedGroupID: ProcessGroupID?

    private let monitor: ProcessMonitor
    private let terminator: SystemProcessTerminator
    private let grouper = ProcessGrouper()
    private let terminationPolicy: TerminationPolicy
    private let notifications = NotificationController()
    private let recoveryVerifier = RecoveryVerifier()
    private let resourceExplainer = ResourceExplainer()
    private let currentUID: UInt32
    private let appPID: Int32
    private var detector: ResourcePressureDetector
    private var monitoringTask: Task<Void, Never>?
    private var sampleCount = 0
    private var notifiedIncidentIDs = Set<ProcessGroupID>()
    private var latestGroups: [ProcessGroup] = []
    private var latestProcessIdentities = Set<ProcessIdentity>()
    private var previousGroupMemory: [ProcessGroupID: UInt64] = [:]
    private var stableGroupOrder: [WorkloadFingerprint: Int] = [:]
    private var nextStableGroupOrder = 0
    private var pressureIsRising = false
    private var pendingForcePlan: TerminationPlan?
    private var pendingForceGroup: ProcessGroup?
    private var resolutionOriginalGroup: ProcessGroup?
    private var resolutionPreexistingMatchingGroupIDs =
        Set<ProcessGroupID>()
    private var resolutionStartedAt: Date?
    private let actionsEnabled: Bool

    init(
        monitor: ProcessMonitor = ProcessMonitor(),
        currentUID: UInt32 = getuid(),
        appPID: Int32 = getpid(),
        actionsEnabled: Bool = true
    ) {
        self.monitor = monitor
        self.currentUID = currentUID
        self.appPID = appPID
        self.actionsEnabled = actionsEnabled
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

    var focusedGroup: ProcessGroup? {
        if let recoveryAssessment {
            switch recoveryAssessment {
            case .recovered:
                return nil
            case let .restarted(receipt):
                return receipt.successorGroupID.flatMap(group(with:))
            case .partial:
                return resolvingGroup
            }
        }
        if let resolvingGroup {
            return resolvingGroup
        }
        if let incident = activeIncident {
            return incident.group
        }
        return nil
    }

    var focusedGroupID: ProcessGroupID? {
        focusedGroup?.id
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

    func explanation(for group: ProcessGroup) -> ResourceExplanation {
        resourceExplainer.explain(group)
    }

    var menuBarSymbol: String {
        if let recoveryAssessment {
            switch recoveryAssessment {
            case .recovered:
                return "checkmark.circle"
            case .restarted:
                return "arrow.clockwise.circle"
            case .partial:
                return "exclamationmark.circle"
            }
        }
        return switch activeIncident?.severity {
        case .high:
            "exclamationmark.circle.fill"
        case .elevated:
            "exclamationmark.circle"
        case nil:
            isPreparing ? "circle.dotted" : "circle"
        }
    }

    var menuBarAccessibilityLabel: String {
        if let recoveryAssessment {
            return switch recoveryAssessment {
            case .recovered:
                "Culprit verified that resource use recovered"
            case .restarted:
                "Culprit detected that the stopped workload restarted"
            case let .partial(_, remaining):
                "Culprit found \(remaining.count) processes still running"
            }
        }
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

    func applyPreviewFixture(
        groups: [ProcessGroup],
        incidents: [ResourceIncident],
        recoveryAssessment: RecoveryAssessment? = nil,
        resolvingGroup: ProcessGroup? = nil,
        stopState: StopState = .idle
    ) {
        monitoringTask?.cancel()
        monitoringTask = nil
        sampleCount = 2
        isPreparing = false
        latestGroups = groups
        latestProcessIdentities = Set(
            groups.flatMap(\.processes).map(\.identity)
        )
        self.groups = groups
        self.incidents = incidents
        self.recoveryAssessment = recoveryAssessment
        self.resolvingGroup = resolvingGroup
        self.stopState = stopState
    }

    func toggleDetails(for id: ProcessGroupID) {
        selectedGroupID = selectedGroupID == id ? nil : id
    }

    func capability(for group: ProcessGroup) -> TerminationCapability {
        terminationPolicy.plan(for: group).capability
    }

    func requestQuit(_ id: ProcessGroupID) {
        guard actionsEnabled else {
            message = "Preview only — no process was stopped."
            return
        }
        guard stopState == .idle,
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
        recoveryAssessment = nil
        resolvingGroup = group
        resolutionOriginalGroup = group
        let fingerprint = WorkloadFingerprint(group: group)
        resolutionPreexistingMatchingGroupIDs = Set(
            latestGroups
                .filter {
                    $0.id != group.id
                        && WorkloadFingerprint(group: $0) == fingerprint
                }
                .map(\.id)
        )
        resolutionStartedAt = Date()
        message = nil
        pendingForceName = nil
        pendingForcePlan = nil
        pendingForceGroup = nil

        Task {
            let signalResult: TerminationResult?

            if case .application = group.kind,
               let application = NSRunningApplication(
                   processIdentifier: group.id.rootPID
               ) {
                _ = application.terminate()
                signalResult = nil
            } else {
                signalResult = await terminator.terminate(plan, mode: .graceful)
            }

            try? await Task.sleep(for: .seconds(2))
            await refresh()

            let assessment = recoveryVerifier.assess(
                original: group,
                currentGroups: latestGroups,
                currentProcessIdentities: latestProcessIdentities,
                preexistingMatchingGroupIDs:
                    resolutionPreexistingMatchingGroupIDs,
                verificationDuration: resolutionStartedAt.map {
                    Date().timeIntervalSince($0)
                } ?? 2
            )
            recoveryAssessment = assessment

            switch assessment {
            case let .partial(_, remaining):
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
                    } else {
                        stopState = .idle
                        message = "The remaining process became protected and was not stopped."
                    }
                } else {
                    stopState = .idle
                    message = "The remaining processes could not be verified."
                }

            case .recovered:
                stopState = .idle
                if let signalResult, !signalResult.failures.isEmpty {
                    message = "Quit completed with \(signalResult.failures.count) warning\(signalResult.failures.count == 1 ? "" : "s")."
                }

            case .restarted:
                stopState = .idle
            }
        }
    }

    func requestForceQuit(_ id: ProcessGroupID) {
        guard actionsEnabled else {
            message = "Preview only — no process was stopped."
            return
        }
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
            let original = resolutionOriginalGroup ?? oldGroup
            let assessment = recoveryVerifier.assess(
                original: original,
                currentGroups: latestGroups,
                currentProcessIdentities: latestProcessIdentities,
                preexistingMatchingGroupIDs:
                    resolutionPreexistingMatchingGroupIDs,
                verificationDuration: resolutionStartedAt.map {
                    Date().timeIntervalSince($0)
                } ?? 2.6
            )
            recoveryAssessment = assessment
            stopState = .idle
            pendingForcePlan = nil
            pendingForceGroup = nil
            pendingForceName = nil

            if case let .partial(_, remaining) = assessment {
                let count = max(remaining.count, result.failures.count)
                message = "\(count) process\(count == 1 ? "" : "es") could not be stopped."
            } else if !result.failures.isEmpty {
                message = "\(displayName) stopped with \(result.failures.count) warning\(result.failures.count == 1 ? "" : "s")."
            }
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

    func dismissRecovery() {
        guard stopState == .idle else { return }
        recoveryAssessment = nil
        resolvingGroup = nil
        resolutionOriginalGroup = nil
        resolutionPreexistingMatchingGroupIDs = []
        resolutionStartedAt = nil
        message = nil
    }

    func cancelPendingForceQuit() {
        guard case .forceAvailable = stopState else { return }
        stopState = .idle
        pendingForcePlan = nil
        pendingForceGroup = nil
        pendingForceName = nil
        recoveryAssessment = nil
        resolvingGroup = nil
        resolutionOriginalGroup = nil
        resolutionPreexistingMatchingGroupIDs = []
        resolutionStartedAt = nil
        message = "Force quit cancelled. Some processes are still running."
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
        let visibleGroups = allGroups
            .filter { $0.cpuPercent >= 0.5 || $0.memoryBytes >= 30_000_000 }
        for group in visibleGroups.sorted(by: {
            $0.memoryBytes > $1.memoryBytes
        }) {
            let fingerprint = WorkloadFingerprint(group: group)
            if stableGroupOrder[fingerprint] == nil {
                stableGroupOrder[fingerprint] = nextStableGroupOrder
                nextStableGroupOrder += 1
            }
        }
        groups = Array(
            visibleGroups
                .sorted {
                    let leftNeedsAttention = incidentIDs.contains($0.id)
                    let rightNeedsAttention = incidentIDs.contains($1.id)
                    if leftNeedsAttention != rightNeedsAttention {
                        return leftNeedsAttention
                    }
                    let leftOrder = stableGroupOrder[
                        WorkloadFingerprint(group: $0)
                    ] ?? .max
                    let rightOrder = stableGroupOrder[
                        WorkloadFingerprint(group: $1)
                    ] ?? .max
                    if leftOrder == rightOrder {
                        return $0.id.rootPID < $1.id.rootPID
                    }
                    return leftOrder < rightOrder
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
