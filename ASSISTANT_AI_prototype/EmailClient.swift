import Foundation

/// Legacy email helper and placeholder UI support.
///
/// The active email IMAP/SMTP helper is `MailCoreManager.swift`.
/// To enable real email retrieval and sending, integrate MailCore2 in Xcode.
/// Example installation methods:
///   - CocoaPods: `pod 'MailCore2/SMTP', 'MailCore2/IMAP'`
///   - Manual framework install from https://github.com/MailCore/mailcore2
///
/// After adding MailCore2, change `import Foundation` to `import MailCore`.

final class EmailClient {
    static let shared = EmailClient()

    private init() {}

    /// Example placeholder: returns a sample inbox preview.
    func fetchRecentSubjects(completion: @escaping ([String]) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
            completion(["Sample: Meeting reschedule request", "Welcome to AST AI Prototype"]) 
        }
    }

    /// Send an email using SMTP.
    /// Replace this stub with MailCore2 SMTP implementation.
    func sendEmail(to: String, subject: String, body: String, completion: @escaping (Bool, Error?) -> Void) {
        completion(false, nil)
    }

    /// Example MailCore2 integration placeholder.
    /// Uncomment and implement after integrating MailCore2.
    /*
    func sendEmailWithMailCore(host: String, port: UInt32, username: String, password: String, to: String, subject: String, body: String, completion: @escaping (Bool, Error?) -> Void) {
        let smtpSession = MCOSMTPSession()
        smtpSession.hostname = host
        smtpSession.port = port
        smtpSession.username = username
        smtpSession.password = password
        smtpSession.connectionType = .TLS

        let builder = MCOMessageBuilder()
        builder.header.to = [MCOAddress(displayName: nil, mailbox: to)]
        builder.header.from = MCOAddress(displayName: "AST AI", mailbox: username)
        builder.header.subject = subject
        builder.textBody = body

        let rfc822Data = builder.data()
        let sendOperation = smtpSession.sendOperation(with: rfc822Data)
        sendOperation?.start { error in
            completion(error == nil, error)
        }
    }
    */
}
