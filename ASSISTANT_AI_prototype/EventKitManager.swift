import Foundation
import EventKit

@MainActor
class EventKitManager: NSObject, ObservableObject {
    private let store = EKEventStore()
    @Published var events: [EKEvent] = []

    func requestAccessIfNeeded() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized:
            Task { await fetchUpcoming() }
        case .notDetermined:
            store.requestAccess(to: .event) { granted, error in
                if granted {
                    Task { await self.fetchUpcoming() }
                }
            }
        default:
            break
        }
    }

    func fetchUpcoming(days: Int = 7) async {
        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: days, to: start)!
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let found = store.events(matching: predicate)
        DispatchQueue.main.async {
            self.events = found.sorted { ($0.startDate ?? Date()) < ($1.startDate ?? Date()) }
        }
    }

    func addEvent(title: String, startDate: Date, endDate: Date, location: String?, notes: String?, completion: @escaping (Bool, Error?) -> Void) {
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.location = location
        event.notes = notes
        event.calendar = store.defaultCalendarForNewEvents

        do {
            try store.save(event, span: .thisEvent)
            completion(true, nil)
        } catch {
            completion(false, error)
        }
    }
}
