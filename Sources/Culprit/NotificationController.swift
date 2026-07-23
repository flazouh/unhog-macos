import CulpritCore
import Foundation
import UserNotifications

actor NotificationController {
    private let center = UNUserNotificationCenter.current()

    func requestPermission() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func send(_ incident: ResourceIncident) async {
        let content = UNMutableNotificationContent()
        content.title = notificationTitle(for: incident)
        content.body = notificationBody(for: incident)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: notificationIdentifier(for: incident.id),
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    private func notificationTitle(for incident: ResourceIncident) -> String {
        switch incident.signal {
        case .memory:
            "\(incident.group.displayName) is using unusual memory"
        case .cpu:
            "\(incident.group.displayName) is keeping your CPU busy"
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
