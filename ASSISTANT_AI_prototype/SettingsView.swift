import SwiftUI

struct SettingsView: View {
    @StateObject private var permissions = PermissionManager()
    @AppStorage("AppPrefEnableEmailSync") private var enableEmailSync = true
    @AppStorage("AppPrefAutoRefreshCalendar") private var autoRefreshCalendar = true
    @AppStorage("AppPrefDefaultEventDuration") private var defaultEventDuration = 60
    @State private var savedMessage: String = ""

    var body: some View {
        List {
            Section(header: Text("Permissions")) {
                HStack {
                    Text("Calendar")
                    Spacer()
                    Text(permissions.calendarStatus)
                        .foregroundColor(permissions.calendarAuthorized ? .green : .orange)
                }
                Button("Request Calendar Access") {
                    permissions.requestCalendarAccess()
                }
                HStack {
                    Text("Notifications")
                    Spacer()
                    Text(permissions.notificationStatus)
                        .foregroundColor(permissions.notificationAuthorized ? .green : .orange)
                }
                Button("Request Notification Access") {
                    Task {
                        await permissions.requestNotificationAccess()
                    }
                }
                Button("Open App Settings") {
                    permissions.openAppSettings()
                }
            }

            Section(header: Text("App Preferences")) {
                Toggle("Enable email sync", isOn: $enableEmailSync)
                Toggle("Auto-refresh calendar", isOn: $autoRefreshCalendar)
                Stepper(value: $defaultEventDuration, in: 15...180, step: 15) {
                    Text("Default event duration: \(defaultEventDuration) min")
                }
                Button("Save preferences") {
                    savedMessage = "Preferences saved."
                }
                if !savedMessage.isEmpty {
                    Text(savedMessage)
                        .font(.footnote)
                        .foregroundColor(.blue)
                }
            }

            Section(header: Text("App Info")) {
                Text("Version: 1.0")
                Text("Build: 1")
                Text("Bundle ID: com.example.ASTAI")
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            permissions.refreshStatuses()
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
