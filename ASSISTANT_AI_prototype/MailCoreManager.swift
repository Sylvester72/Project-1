import Foundation

#if canImport(MailCore)
import MailCore
#endif

public struct EmailAccount {
    public let imapHost: String
    public let imapPort: UInt32
    public let smtpHost: String
    public let smtpPort: UInt32
    public let username: String
    public let password: String
    public let useTLS: Bool
}

public final class MailCoreManager {
    public static let shared = MailCoreManager()
    private init() {}

    public func fetchRecentSubjects(account: EmailAccount, completion: @escaping ([String], Error?) -> Void) {
        #if canImport(MailCore)
        let session = MCOIMAPSession()
        session.hostname = account.imapHost
        session.port = account.imapPort
        session.username = account.username
        session.password = account.password
        session.connectionType = account.useTLS ? .TLS : .clear

        let requestKind: MCOIMAPMessagesRequestKind = [.headers]
        let inbox = "INBOX"
        let uids = MCOIndexSet(range: MCORangeMake(1, 50))

        let op = session.fetchMessagesByNumberOperation(withFolder: inbox, requestKind: requestKind, numbers: uids)
        op?.start { error, messages, vanished in
            guard error == nil, let messages = messages as? [MCOIMAPMessage] else {
                completion([], error)
                return
            }

            let subjects = messages.compactMap { $0.header.subject }
            completion(subjects, nil)
        }
        #else
        completion(["MailCore not installed: install MailCore2 and import MailCore."], nil)
        #endif
    }

    public func sendEmail(account: EmailAccount, to: String, subject: String, body: String, completion: @escaping (Bool, Error?) -> Void) {
        #if canImport(MailCore)
        let smtpSession = MCOSMTPSession()
        smtpSession.hostname = account.smtpHost
        smtpSession.port = account.smtpPort
        smtpSession.username = account.username
        smtpSession.password = account.password
        smtpSession.connectionType = account.useTLS ? .TLS : .clear

        let builder = MCOMessageBuilder()
        builder.header.from = MCOAddress(displayName: "AST AI", mailbox: account.username)
        builder.header.to = [MCOAddress(displayName: nil, mailbox: to)]
        builder.header.subject = subject
        builder.textBody = body

        guard let rfc822Data = builder.data() else {
            completion(false, NSError(domain: "MailCoreManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to build email data"]))
            return
        }

        let sendOp = smtpSession.sendOperation(with: rfc822Data)
        sendOp?.start { error in
            completion(error == nil, error)
        }
        #else
        completion(false, NSError(domain: "MailCoreManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "MailCore not installed"]))
        #endif
    }
}
