import SwiftUI

struct WhatsAppEventItem: Identifiable, Codable {
    let id: String
    let from: String
    let text: String
    let timestamp: Int64?
}

final class WhatsAppEventsViewModel: ObservableObject {
    @Published var events: [WhatsAppEventItem] = []
    @Published var status: String = ""

    func fetchEvents() {
        guard let backend = UserDefaults.standard.string(forKey: "BackendURL"),
              let url = URL(string: backend)?.appendingPathComponent("events") else {
            status = "Backend not configured"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let auth = KeychainHelper.read(service: "ASTAI.WhatsApp", account: "AuthToken") {
            request.setValue("Bearer \(auth)", forHTTPHeaderField: "Authorization")
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.status = "Fetch failed: \(error.localizedDescription)"
                    return
                }
                guard let data = data else {
                    self.status = "No data"
                    return
                }
                if let list = try? JSONDecoder().decode([WhatsAppEventItem].self, from: data) {
                    self.events = list
                    self.status = "Loaded \(list.count) events"
                } else {
                    self.status = "Decode failed"
                }
            }
        }
        task.resume()
    }
}

struct WhatsAppEventsView: View {
    @StateObject private var vm = WhatsAppEventsViewModel()

    var body: some View {
        NavigationView {
            List {
                ForEach(vm.events) { ev in
                    NavigationLink(destination: WhatsAppEventDetailView(event: ev)) {
                        VStack(alignment: .leading) {
                            Text(ev.from).font(.headline)
                            Text(ev.text).font(.body).lineLimit(2)
                            if let ts = ev.timestamp {
                                Text(Date(timeIntervalSince1970: TimeInterval(ts/1000))).font(.caption)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .navigationTitle("WhatsApp Events")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        vm.fetchEvents()
                    }
                }
            }
            .onAppear {
                vm.fetchEvents()
            }
        }
    }
}

struct WhatsAppEventDetailView: View {
    let event: WhatsAppEventItem
    @State private var replyText: String = ""
    @State private var status: String = ""

    var body: some View {
        VStack(alignment: .leading) {
            Text("From: \(event.from)")
                .font(.headline)
            Text(event.text)
                .padding(.vertical)

            TextEditor(text: $replyText)
                .frame(minHeight: 120)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.25)))

            Button("Send Reply") {
                sendReply()
            }
            .padding(.top)

            Text(status).font(.footnote).foregroundColor(.blue)
            Spacer()
        }
        .padding()
        .onAppear {
            replyText = "Hi — thanks for your message. "
        }
    }

    private func sendReply() {
        status = "Sending..."
        SIPProviderManager.shared.sendWhatsAppMessage(to: event.from, message: replyText) { success, error in
            DispatchQueue.main.async {
                if success {
                    status = "Reply sent."
                } else {
                    status = "Send failed: \(error?.localizedDescription ?? "unknown")"
                }
            }
        }
    }
}

struct WhatsAppEventsView_Previews: PreviewProvider {
    static var previews: some View {
        WhatsAppEventsView()
    }
}
