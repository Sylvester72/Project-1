import Foundation
import PushKit

final class PushKitManager: NSObject {
    static let shared = PushKitManager()
    private var registry: PKPushRegistry?
    private var backendURLString: String?
    var onTokenUpdate: ((String) -> Void)?

    func configureBackendURL(_ urlString: String?) {
        backendURLString = urlString
    }

    func start() {
        registry = PKPushRegistry(queue: .main)
        registry?.delegate = self
        registry?.desiredPushTypes = [.voIP]
    }

    private func sendTokenToBackend(_ token: String) {
        guard let backendURLString = backendURLString,
              let url = URL(string: backendURLString),
              isAllowedBackendURL(url) else {
            return
        }

        let endpoint = url.appendingPathComponent("register-voip-token")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["deviceToken": token], options: [])

        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                // Avoid logging the token itself
                print("Push token registration failed: \(error.localizedDescription)")
            }
        }
        task.resume()
    }

    private func isAllowedBackendURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        if scheme == "https" {
            return true
        }
        if scheme == "http", let host = url.host?.lowercased(), host == "localhost" || host == "127.0.0.1" {
            return true
        }
        return false
    }
}

extension PushKitManager: PKPushRegistryDelegate {
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        onTokenUpdate?(token)
        sendTokenToBackend(token)
    }

    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {}

    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
        let uuid = UUID()
        let caller = (payload.dictionaryPayload["caller"] as? String) ?? "Unknown"
        CallKitManager.shared.reportIncomingCall(uuid: uuid, handle: caller) { error in
            if let error = error {
                print("Failed to report incoming call: \(error)")
            }
        }
    }
}
