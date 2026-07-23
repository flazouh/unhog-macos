import CulpritCore
import Foundation
@preconcurrency import UserNotifications

actor NotificationController {
    private let center = UNUserNotificationCenter.current()

    func requestPermission() async -> Bool {
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .denied {
            return false
        }
        if settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional {
            return true
        }
        return (try? await center.requestAuthorization(
            options: [.alert, .sound]
        )) ?? false
    }

    func permissionIsDenied() async -> Bool {
        await center.notificationSettings().authorizationStatus == .denied
    }

    func send(
        _ incident: ResourceIncident,
        policy: NotificationPolicy
    ) async {
        let content = UNMutableNotificationContent()
        content.title = notificationTitle(
            for: incident,
            showsWorkloadNames: policy.showsWorkloadNames
        )
        content.body = notificationBody(for: incident)
        content.sound = policy.playsSound ? .default : nil

        let request = UNNotificationRequest(
            identifier: notificationIdentifier(for: incident.id),
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    func sendRecovery(
        _ receipt: RecoveryReceipt,
        policy: NotificationPolicy
    ) async {
        let content = UNMutableNotificationContent()
        content.title = policy.showsWorkloadNames
            ? "\(receipt.displayName) recovered"
            : "Resource use recovered"
        let memory = ByteCountFormatter.string(
            fromByteCount: Int64(clamping: receipt.memoryReductionBytes),
            countStyle: .memory
        )
        content.body = "The workload’s measured memory fell by \(memory)."
        content.sound = policy.playsSound ? .default : nil
        try? await center.add(
            UNNotificationRequest(
                identifier: "culprit-recovery-\(receipt.originalGroupID.rootPID)",
                content: content,
                trigger: nil
            )
        )
    }

    func sendRestart(
        _ receipt: RecoveryReceipt,
        policy: NotificationPolicy
    ) async {
        let content = UNMutableNotificationContent()
        content.title = policy.showsWorkloadNames
            ? "\(receipt.displayName) started again"
            : "A stopped workload started again"
        content.body = "Unhog will not stop it again without your approval."
        content.sound = policy.playsSound ? .default : nil
        try? await center.add(
            UNNotificationRequest(
                identifier: "culprit-restart-\(receipt.originalGroupID.rootPID)",
                content: content,
                trigger: nil
            )
        )
    }

    private func notificationTitle(
        for incident: ResourceIncident,
        showsWorkloadNames: Bool
    ) -> String {
        let name = showsWorkloadNames
            ? incident.group.displayName
            : "A workload"
        return switch incident.signal {
        case .memory:
            "\(name) is using unusual memory"
        case .cpu:
            "\(name) is keeping your CPU busy"
        }
    }

    private func notificationBody(for incident: ResourceIncident) -> String {
        let cpu = Int(incident.group.cpuPercent.rounded())
        let memory = ByteCountFormatter.string(
            fromByteCount: Int64(clamping: incident.group.memoryBytes),
            countStyle: .memory
        )
        return "\(cpu)% CPU · \(memory). This may slow your Mac or drain its battery."
    }

    private func notificationIdentifier(for id: ProcessGroupID) -> String {
        "culprit-\(id.rootPID)"
    }
}
