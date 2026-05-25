import SwiftUI

@main
struct AssistantApp: App {
    init() {
        PushKitManager.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
