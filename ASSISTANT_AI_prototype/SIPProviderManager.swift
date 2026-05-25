import Foundation

public struct VoIPBackendConfig {
    public let baseURL: URL
    public let apiKey: String?
}

public final class SIPProviderManager {
    public static let shared = SIPProviderManager()
    private init() {}

    private var backendURL: URL?

    public func configureBackendURL(_ urlString: String) {
        guard let url = URL(string: urlString), isAllowedBackendURL(url) else {
            backendURL = nil
            return
        }
        backendURL = url
    }

    private func makeURL(path: String) -> URL? {
        guard let base = backendURL else { return nil }
        return base.appendingPathComponent(path)
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

    public func registerVoIPToken(_ token: String, completion: @escaping (Bool, Error?) -> Void) {
        guard let url = makeURL(path: "register-voip-token") else {
            completion(false, nil)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["deviceToken": token], options: [])

        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            let success = error == nil && (response as? HTTPURLResponse)?.statusCode == 200
            completion(success, error)
        }
        task.resume()
    }

    public func startTwilioCall(to phoneNumber: String, completion: @escaping (Bool, Error?) -> Void) {
        guard let url = makeURL(path: "twilio/make-call") else {
            completion(false, nil)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["to": phoneNumber], options: [])

        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            let success = error == nil && (response as? HTTPURLResponse)?.statusCode == 200
            completion(success, error)
        }
        task.resume()
    }

    public func sendWhatsAppMessage(to phoneNumber: String, message: String, completion: @escaping (Bool, Error?) -> Void) {
        guard let url = makeURL(path: "whatsapp/send") else {
            completion(false, nil)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["to": phoneNumber, "message": message], options: [])

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            let success = error == nil && (response as? HTTPURLResponse)?.statusCode == 200
            completion(success, error)
        }
        task.resume()
    }
}
