import Foundation

@MainActor
final class EmailAccountSettings: ObservableObject {
    @Published var imapHost: String = ""
    @Published var imapPort: String = "993"
    @Published var smtpHost: String = ""
    @Published var smtpPort: String = "587"
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var useTLS: Bool = true

    init() {
        load()
    }

    private let storage = UserDefaults.standard
    private let keychainService = "ASTAI.Email"

    private enum Keys {
        static let imapHost = "EmailImapHost"
        static let imapPort = "EmailImapPort"
        static let smtpHost = "EmailSmtpHost"
        static let smtpPort = "EmailSmtpPort"
        static let username = "EmailUsername"
        static let passwordAccount = "EmailPassword"
        static let useTLS = "EmailUseTLS"
    }

    func load() {
        imapHost = storage.string(forKey: Keys.imapHost) ?? ""
        imapPort = storage.string(forKey: Keys.imapPort) ?? "993"
        smtpHost = storage.string(forKey: Keys.smtpHost) ?? ""
        smtpPort = storage.string(forKey: Keys.smtpPort) ?? "587"
        username = storage.string(forKey: Keys.username) ?? ""
        password = KeychainHelper.read(service: keychainService, account: Keys.passwordAccount) ?? ""
        useTLS = storage.object(forKey: Keys.useTLS) as? Bool ?? true
    }

    func save() {
        storage.set(imapHost, forKey: Keys.imapHost)
        storage.set(imapPort, forKey: Keys.imapPort)
        storage.set(smtpHost, forKey: Keys.smtpHost)
        storage.set(smtpPort, forKey: Keys.smtpPort)
        storage.set(username, forKey: Keys.username)
        storage.set(useTLS, forKey: Keys.useTLS)

        if password.isEmpty {
            KeychainHelper.delete(service: keychainService, account: Keys.passwordAccount)
        } else {
            KeychainHelper.save(password, service: keychainService, account: Keys.passwordAccount)
        }
    }

    var account: EmailAccount? {
        guard !imapHost.isEmpty,
              let imapPortValue = UInt32(imapPort),
              !smtpHost.isEmpty,
              let smtpPortValue = UInt32(smtpPort),
              !username.isEmpty,
              !password.isEmpty else {
            return nil
        }

        return EmailAccount(
            imapHost: imapHost,
            imapPort: imapPortValue,
            smtpHost: smtpHost,
            smtpPort: smtpPortValue,
            username: username,
            password: password,
            useTLS: useTLS
        )
    }
}
