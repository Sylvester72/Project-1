import Foundation
import UserNotifications

final class WhatsAppEventManager {
    static let shared = WhatsAppEventManager()
    private init() {}

    private struct Event: Codable {
        let id: String
        let from: String
        let text: String
        let timestamp: Int64?
    }

    func handleIncomingEvent(eventId: String) {
        guard let backend = UserDefaults.standard.string(forKey: "BackendURL"),
              let url = URL(string: backend)?.appendingPathComponent("events").appendingPathComponent(eventId) else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // Attach auth token from Keychain if available
        if let auth = KeychainHelper.read(service: "ASTAI.WhatsApp", account: "AuthToken") {
            request.setValue("Bearer \(auth)", forHTTPHeaderField: "Authorization")
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil, let data = data else { return }
            if let ev = try? JSONDecoder().decode(Event.self, from: data) {
                self.presentNotification(from: ev.from, text: ev.text)
            }
        }
        task.resume()
    }

    private func presentNotification(from: String, text: String) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            if settings.authorizationStatus != .authorized {
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    guard granted else { return }
                    self.scheduleNotification(from: from, text: text)
                }
            } else {
                self.scheduleNotification(from: from, text: text)
            }
        }
    }

    private func scheduleNotification(from: String, text: String) {
        let content = UNMutableNotificationContent()
        content.title = "WhatsApp from \(from)"
        content.body = text
        content.sound = .default

        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }
}
