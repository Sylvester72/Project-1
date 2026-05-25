import SwiftUI
import EventKit

struct ContentView: View {
    @StateObject private var ek = EventKitManager()
    @StateObject private var emailSettings = EmailAccountSettings()
    @State private var emailSubjects: [String] = []
    @State private var draft: String = ""
    @State private var emailRecipient: String = ""
    @State private var emailSubject: String = "AST AI reply"
    @State private var emailBody: String = ""
    @State private var sendStatus: String = ""
    @State private var eventTitle: String = "New AST AI Event"
    @State private var eventLocation: String = ""
    @State private var eventNotes: String = ""
    @State private var eventStart = Date()
    @State private var eventEnd = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    @State private var calendarStatus: String = ""
    @State private var aiPrompt: String = "Reply to the most recent email and confirm calendar availability."
    @State private var aiReply: String = ""
    @State private var aiIntent: LLMManager.ReplyIntent = .confirmAvailability
    @State private var aiStatus: String = ""
    @State private var backendURL: String = ""
    @State private var deviceToken: String = "Not available"
    @State private var callNumber: String = ""
    @State private var whatsAppRecipient: String = ""
    @State private var whatsAppMessage: String = ""
    @State private var whatsAppStatus: String = ""
    @State private var registrationMessage: String = ""
    @State private var emailStatus: String = ""
    @State private var llmSettings = LLMManager.Settings()
    @State private var openAIAPIKey: String = ""

    var body: some View {
        TabView {
            NavigationView {
                List {
                Section(header: Text("Upcoming Events")) {
                    if ek.events.isEmpty {
                        Text("No events or permission not granted.")
                    } else {
                        ForEach(ek.events, id: \ .identifier) { e in
                            VStack(alignment: .leading) {
                                Text(e.title ?? "(no title)")
                                    .font(.headline)
                                Text(eventSubtitle(e))
                                    .font(.subheadline)
                                if let location = e.location, !location.isEmpty {
                                    Text(location)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    Button("Refresh Calendar") {
                        Task {
                            await ek.fetchUpcoming()
                            calendarStatus = "Calendar refreshed"
                        }
                    }
                    Text(calendarStatus)
                        .font(.footnote)
                        .foregroundColor(.blue)
                }

                Section(header: Text("Create Calendar Event")) {
                    TextField("Event title", text: $eventTitle)
                    TextField("Location", text: $eventLocation)
                        .autocapitalization(.words)
                    DatePicker("Starts", selection: $eventStart, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Ends", selection: $eventEnd, displayedComponents: [.date, .hourAndMinute])
                    TextEditor(text: $eventNotes)
                        .frame(minHeight: 100)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.25)))
                    Button("Add to Calendar") {
                        ek.addEvent(title: eventTitle, startDate: eventStart, endDate: eventEnd, location: eventLocation.isEmpty ? nil : eventLocation, notes: eventNotes.isEmpty ? nil : eventNotes) { success, error in
                            DispatchQueue.main.async {
                                if success {
                                    calendarStatus = "Event added to calendar."
                                    Task {
                                        await ek.fetchUpcoming()
                                    }
                                } else {
                                    calendarStatus = "Failed to add event: \(error?.localizedDescription ?? "unknown error")"
                                }
                            }
                        }
                    }
                }

                Section(header: Text("Emails")) {
                    if emailSubjects.isEmpty {
                        Text("No email preview loaded.")
                    } else {
                        ForEach(emailSubjects, id: \ .self) { m in
                            Text(m)
                        }
                    }
                }

                Section(header: Text("Backend & VoIP")) {
                    TextField("Backend URL", text: $backendURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    Button("Configure backend URL") {
                        SIPProviderManager.shared.configureBackendURL(backendURL)
                        PushKitManager.shared.configureBackendURL(backendURL)
                        backendURLSaved(backendURL)
                        registrationMessage = "Backend configured"
                    }
                    Text("Device token: \(maskedToken(deviceToken))")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Button("Register VoIP token now") {
                        if deviceToken != "Not available" {
                            SIPProviderManager.shared.registerVoIPToken(deviceToken) { success, error in
                                DispatchQueue.main.async {
                                    registrationMessage = success ? "Token registered" : "Registration failed"
                                    if let error = error {
                                        registrationMessage += ": \(error.localizedDescription)"
                                    }
                                }
                            }
                        }
                    }
                    Text(registrationMessage)
                        .font(.footnote)
                        .foregroundColor(.blue)
                }

                Section(header: Text("Email Settings")) {
                    TextField("IMAP host", text: $emailSettings.imapHost)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    TextField("IMAP port", text: $emailSettings.imapPort)
                        .keyboardType(.numberPad)
                    TextField("SMTP host", text: $emailSettings.smtpHost)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    TextField("SMTP port", text: $emailSettings.smtpPort)
                        .keyboardType(.numberPad)
                    TextField("Username", text: $emailSettings.username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    SecureField("Password", text: $emailSettings.password)
                    Toggle("Use TLS", isOn: $emailSettings.useTLS)
                    Button("Save email settings") {
                        emailSettings.save()
                    }
                    Button("Fetch recent email subjects") {
                        guard let account = emailSettings.account else {
                            emailStatus = "Please complete all email settings."
                            return
                        }
                        MailCoreManager.shared.fetchRecentSubjects(account: account) { subjects, error in
                            DispatchQueue.main.async {
                                if let error = error {
                                    emailStatus = "Email fetch failed: \(error.localizedDescription)"
                                    self.emailSubjects = []
                                } else {
                                    emailSubjects = subjects
                                    emailStatus = "Loaded \(subjects.count) subjects"
                                }
                            }
                        }
                    }
                    Text(emailStatus)
                        .font(.footnote)
                        .foregroundColor(.green)
                }

                Section(header: Text("AI Reply Engine")) {
                    Picker("Provider", selection: $llmSettings.provider) {
                        ForEach(LLMManager.Provider.allCases, id: \ .self) { provider in
                            Text(provider.rawValue)
                        }
                    }
                    TextField("OpenAI API key", text: $openAIAPIKey)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    TextField("Model", text: $llmSettings.openAIModel)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    Button("Save AI settings") {
                        LLMManager.shared.updateSettings(llmSettings)
                        LLMManager.shared.updateOpenAIAPIKey(openAIAPIKey)
                        aiStatus = "AI settings saved."
                    }
                    TextEditor(text: $aiPrompt)
                        .frame(minHeight: 100)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.25)))
                    Picker("Intent", selection: $aiIntent) {
                        ForEach(LLMManager.ReplyIntent.allCases) { intent in
                            Text(intent.rawValue).tag(intent)
                        }
                    }
                    Text("Response:")
                        .font(.headline)
                    TextEditor(text: $aiReply)
                        .frame(minHeight: 120)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.25)))
                    Button("Generate AI Reply") {
                        Task {
                            aiReply = await LLMManager.shared.generateReply(for: aiPrompt, intent: aiIntent)
                            aiStatus = "AI reply generated."
                        }
                    }
                    Text(aiStatus)
                        .font(.footnote)
                        .foregroundColor(.blue)
                }

                Section(header: Text("Compose Email")) {
                    TextField("Recipient email", text: $emailRecipient)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .disableAutocorrection(true)
                    TextField("Subject", text: $emailSubject)
                        .autocapitalization(.words)
                    TextEditor(text: $emailBody)
                        .frame(minHeight: 120)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.25)))
                    Button("Send Email") {
                        guard let account = emailSettings.account else {
                            sendStatus = "Please save email settings first."
                            return
                        }
                        guard !emailRecipient.isEmpty else {
                            sendStatus = "Enter a recipient email address."
                            return
                        }
                        MailCoreManager.shared.sendEmail(account: account, to: emailRecipient, subject: emailSubject, body: emailBody) { success, error in
                            DispatchQueue.main.async {
                                if success {
                                    sendStatus = "Email sent successfully."
                                } else {
                                    sendStatus = "Email send failed: \(error?.localizedDescription ?? "unknown error")"
                                }
                            }
                        }
                    }
                    Text(sendStatus)
                        .font(.footnote)
                        .foregroundColor(.blue)
                }

                Section(header: Text("Outgoing Call")) {
                    TextField("Phone number to call", text: $callNumber)
                        .keyboardType(.phonePad)
                    Button("Place Twilio call") {
                        SIPProviderManager.shared.startTwilioCall(to: callNumber) { success, error in
                            DispatchQueue.main.async {
                                registrationMessage = success ? "Twilio call initiated." : "Twilio call failed."
                                if let error = error {
                                    registrationMessage += " \(error.localizedDescription)"
                                }
                            }
                        }
                    }
                }

                Section(header: Text("WhatsApp")) {
                    TextField("Recipient WhatsApp number", text: $whatsAppRecipient)
                        .keyboardType(.phonePad)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    TextEditor(text: $whatsAppMessage)
                        .frame(minHeight: 100)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.25)))
                    Button("Send WhatsApp message") {
                        SIPProviderManager.shared.sendWhatsAppMessage(to: whatsAppRecipient, message: whatsAppMessage) { success, error in
                            DispatchQueue.main.async {
                                whatsAppStatus = success ? "WhatsApp message sent." : "WhatsApp send failed."
                                if let error = error {
                                    whatsAppStatus += " \(error.localizedDescription)"
                                }
                            }
                        }
                    }
                    Text(whatsAppStatus)
                        .font(.footnote)
                        .foregroundColor(.blue)
                }

                Section(header: Text("Draft Reply")) {
                    TextEditor(text: $draft)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("AST AI Assistant")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Generate Draft") {
                        Task {
                            draft = await LLMManager.shared.generateDraft(prompt: "Reply to the most recent email and confirm calendar availability.")
                        }
                    }
                }
            }
            .tabItem {
                Label("Assistant", systemImage: "sparkles")
            }
            WhatsAppEventsView()
                .tabItem {
                    Label("WhatsApp", systemImage: "message")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .onAppear {
            ek.requestAccessIfNeeded()
            loadSavedSettings()
            llmSettings = LLMManager.shared.settings
            openAIAPIKey = LLMManager.shared.openAIAPIKey
            PushKitManager.shared.onTokenUpdate = { token in
                DispatchQueue.main.async {
                    deviceToken = token
                }
            }
        }
    }

    private func backendURLSaved(_ url: String) {
        UserDefaults.standard.set(url, forKey: "BackendURL")
    }

    private func loadSavedSettings() {
        backendURL = UserDefaults.standard.string(forKey: "BackendURL") ?? ""
        if !backendURL.isEmpty {
            SIPProviderManager.shared.configureBackendURL(backendURL)
            PushKitManager.shared.configureBackendURL(backendURL)
            registrationMessage = "Backend configured"
        }
    }

    func eventSubtitle(_ event: EKEvent) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .short
        return "\(fmt.string(from: event.startDate)) — \(event.location ?? "")"
    }

    func maskedToken(_ token: String) -> String {
        guard token.count > 16 else { return token }
        let prefix = token.prefix(8)
        let suffix = token.suffix(8)
        return "\(prefix)…\(suffix)"
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
