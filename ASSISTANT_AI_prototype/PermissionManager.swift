import Foundation
import EventKit
import UserNotifications
import UIKit

@MainActor
final class PermissionManager: ObservableObject {
    @Published var calendarStatus: String = "Unknown"
    @Published var notificationStatus: String = "Unknown"
    @Published var calendarAuthorized: Bool = false
    @Published var notificationAuthorized: Bool = false

    private let store = EKEventStore()

    init() {
        refreshStatuses()
    }

    func refreshStatuses() {
        let calendarAuth = EKEventStore.authorizationStatus(for: .event)
        calendarAuthorized = calendarAuth == .authorized
        calendarStatus = calendarStatusText(for: calendarAuth)

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationAuthorized = settings.authorizationStatus == .authorized
                self.notificationStatus = self.notificationStatusText(for: settings.authorizationStatus)
            }
        }
    }

    func requestCalendarAccess() {
        store.requestAccess(to: .event) { granted, _ in
            DispatchQueue.main.async {
                self.calendarAuthorized = granted
                self.refreshStatuses()
            }
        }
    }

    func requestNotificationAccess() async {
        let granted = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        DispatchQueue.main.async {
            self.notificationAuthorized = granted == true
            self.refreshStatuses()
        }
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) else {
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    private func calendarStatusText(for status: EKAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "Authorized"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not determined"
        @unknown default: return "Unknown"
        }
    }

    private func notificationStatusText(for status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "Authorized"
        case .denied: return "Denied"
        case .notDetermined: return "Not determined"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }
}
