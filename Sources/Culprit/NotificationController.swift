import CulpritCore
import Foundation
import UserNotifications

actor NotificationController {
    private let center = UNUserNotificationCenter.current()

    func requestPermission() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func send(_ incident: HeatIncident) async {
        let content = UNMutableNotificationContent()
        content.title = "\(incident.group.displayName) is heating up your Mac"
        content.body = notificationBody(for: incident)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: notificationIdentifier(for: incident.id),
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    private func notificationBody(for incident: HeatIncident) -> String {
        let cpu = Int(incident.group.cpuPercent.rounded())
        let memory = ByteCountFormatter.string(
            fromByteCount: Int64(clamping: incident.group.memoryBytes),
            countStyle: .memory
        )
        return "\(cpu)% CPU · \(memory) · \(incident.reason)"
    }

    private func notificationIdentifier(for id: ProcessGroupID) -> String {
        "culprit-\(id.rootPID)"
    }
}
