import EventKit

@MainActor
final class CalendarService {
    private let store = EKEventStore()

    var hasAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            print("Calendar access request failed: \(error)")
            return false
        }
    }

    /// 在系统日历中创建/更新考勤事件
    func syncRecord(_ record: AttendanceRecord) async {
        guard hasAccess else { return }

        // 先删除同一天的旧事件
        removeEvents(on: record.normalizedDate)

        let event = EKEvent(eventStore: store)
        event.calendar = store.defaultCalendarForNewEvents

        let cal = Calendar.current

        switch record.type {
        case .work:
            event.title = "上班"
            // 使用记录的上下班时间，或默认 9:00-18:00
            if let start = record.startTime, let end = record.endTime {
                event.startDate = start
                event.endDate = end
            } else {
                event.startDate = cal.date(bySettingHour: 9, minute: 0, second: 0, of: record.normalizedDate)!
                event.endDate = cal.date(bySettingHour: 18, minute: 0, second: 0, of: record.normalizedDate)!
            }
        case .rest:
            event.title = "休息"
            event.isAllDay = true
            event.startDate = record.normalizedDate
            event.endDate = record.normalizedDate
        }

        if let note = record.note {
            event.notes = note
        }

        // 添加标记以便后续识别
        event.url = URL(string: "coldplay://attendance")

        do {
            try store.save(event, span: .thisEvent)
        } catch {
            print("Failed to save calendar event: \(error)")
        }
    }

    /// 删除某天的考勤事件
    func removeEvents(on date: Date) {
        guard hasAccess else { return }
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)

        for event in events where event.url?.scheme == "coldplay" {
            do {
                try store.remove(event, span: .thisEvent)
            } catch {
                print("Failed to remove calendar event: \(error)")
            }
        }
    }
}
