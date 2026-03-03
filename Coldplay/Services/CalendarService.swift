import EventKit

@MainActor
final class CalendarService {
    private let store = EKEventStore()
    private static let calendarTitle = "考勤"

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

    /// 获取或创建"考勤"专用日历
    private func attendanceCalendar() -> EKCalendar? {
        // 先查找已有的"考勤"日历
        if let existing = store.calendars(for: .event).first(where: { $0.title == Self.calendarTitle }) {
            return existing
        }

        // 创建新的"考勤"日历
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = Self.calendarTitle
        calendar.cgColor = CGColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0)

        // 选择本地或 iCloud 来源
        if let source = store.sources.first(where: { $0.sourceType == .calDAV }),
           source.title.contains("iCloud") {
            calendar.source = source
        } else if let source = store.sources.first(where: { $0.sourceType == .local }) {
            calendar.source = source
        } else {
            calendar.source = store.defaultCalendarForNewEvents?.source
        }

        do {
            try store.saveCalendar(calendar, commit: true)
            return calendar
        } catch {
            print("Failed to create 考勤 calendar: \(error)")
            return store.defaultCalendarForNewEvents
        }
    }

    /// 在"考勤"日历中创建/更新考勤事件
    func syncRecord(_ record: AttendanceRecord) async {
        guard hasAccess else { return }

        // 先删除同一天的旧事件
        removeEvents(on: record.normalizedDate)

        let event = EKEvent(eventStore: store)
        event.calendar = attendanceCalendar()

        let cal = Calendar.current

        switch record.type {
        case .work:
            event.title = "上班"
            // 使用记录的上下班时间，或默认 12:00-20:00 JST
            if let start = record.startTime, let end = record.endTime {
                event.startDate = start
                event.endDate = end
            } else {
                event.startDate = cal.date(bySettingHour: 12, minute: 0, second: 0, of: record.normalizedDate)!
                event.endDate = cal.date(bySettingHour: 20, minute: 0, second: 0, of: record.normalizedDate)!
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

    /// 删除某天的考勤事件（仅删除"考勤"日历中的）
    func removeEvents(on date: Date) {
        guard hasAccess else { return }
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return }

        let attendanceCal = attendanceCalendar().map { [$0] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: attendanceCal)
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
