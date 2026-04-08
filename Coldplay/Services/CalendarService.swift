import EventKit

@MainActor
final class CalendarService {
    private var store = EKEventStore()
    private static let calendarTitle = "考勤"

    var hasAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    /// True when user has explicitly denied calendar access (needs Settings redirect)
    var isDenied: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        return status == .denied || status == .restricted
    }

    /// App 启动时调用，请求日历权限
    func requestAccess() async -> Bool {
        guard !hasAccess else { return true }
        // If already denied, the system won't show a prompt — caller should direct user to Settings
        guard !isDenied else { return false }
        do {
            let granted = try await store.requestFullAccessToEvents()
            if granted {
                // Reinitialize store so sources/calendars reflect the new permission
                store = EKEventStore()
            }
            return granted
        } catch {
            print("Calendar access request failed: \(error)")
            return false
        }
    }

    /// 获取或创建"考勤"专用日历
    private func attendanceCalendar() -> EKCalendar? {
        if let existing = store.calendars(for: .event).first(where: { $0.title == Self.calendarTitle }) {
            return existing
        }

        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = Self.calendarTitle
        calendar.cgColor = CGColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0)

        // If sources are empty, reinitialize store to pick up available sources
        if store.sources.isEmpty {
            store = EKEventStore()
        }

        // 优先 iCloud，其次本地，最后默认日历的 source
        if let source = store.sources.first(where: { $0.sourceType == .calDAV && $0.title.contains("iCloud") }) {
            calendar.source = source
        } else if let source = store.sources.first(where: { $0.sourceType == .local }) {
            calendar.source = source
        } else if let source = store.sources.first(where: { $0.sourceType == .calDAV }) {
            calendar.source = source
        } else if let source = store.defaultCalendarForNewEvents?.source {
            calendar.source = source
        } else if let source = store.sources.first {
            calendar.source = source
        } else {
            print("No calendar source available — cannot create 考勤 calendar")
            return nil
        }

        do {
            try store.saveCalendar(calendar, commit: true)
            return calendar
        } catch {
            print("Failed to create 考勤 calendar: \(error)")
            return nil
        }
    }

    /// 清除该天在所有考勤相关日历中的旧事件（考勤 + 年假），避免切换类型时残留
    private func removeAllAttendanceEvents(on date: Date) {
        if let cal = attendanceCalendar() {
            removeEvents(on: date, in: cal)
        }
        if let cal = annualLeaveCalendar() {
            removeEvents(on: date, in: cal)
        }
    }

    /// 创建/更新考勤事件，返回是否成功
    @discardableResult
    func syncRecord(_ record: AttendanceRecord) async -> Bool {
        if !hasAccess {
            let granted = await requestAccess()
            guard granted else { return false }
        }

        // 先清除所有相关日历中该天的旧事件
        removeAllAttendanceEvents(on: record.normalizedDate)

        // 年假写入用户已有的「年假」日历
        if record.type == .annualLeave {
            guard let alCalendar = annualLeaveCalendar() else {
                print("未找到「年假」日历，请先在系统日历中创建")
                return false
            }
            let event = EKEvent(eventStore: store)
            event.calendar = alCalendar
            event.title = "年假"
            event.isAllDay = true
            event.startDate = record.normalizedDate
            event.endDate = record.normalizedDate
            if let note = record.note { event.notes = note }
            event.url = URL(string: "coldplay://attendance")
            do {
                try store.save(event, span: .thisEvent)
                return true
            } catch {
                print("Failed to save annual leave event: \(error)")
                return false
            }
        }

        // 其他类型写入「考勤」日历
        guard let calendar = attendanceCalendar() else { return false }

        let event = EKEvent(eventStore: store)
        event.calendar = calendar

        let cal = Calendar.current

        switch record.type {
        case .work:
            event.title = "上班"
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
        case .compensatoryRest:
            event.title = "補休"
            event.isAllDay = true
            event.startDate = record.normalizedDate
            event.endDate = record.normalizedDate
        case .annualLeave:
            break // handled above
        }

        if let note = record.note {
            event.notes = note
        }

        event.url = URL(string: "coldplay://attendance")

        do {
            try store.save(event, span: .thisEvent)
            return true
        } catch {
            print("Failed to save calendar event: \(error)")
            return false
        }
    }

    // MARK: - 加班（写入用户已有的"加班"日历）

    private static let overtimeCalendarTitle = "加班"
    private static let annualLeaveCalendarTitle = "年假"

    /// 查找用户已有的"加班"日历
    private func overtimeCalendar() -> EKCalendar? {
        store.calendars(for: .event).first(where: { $0.title == Self.overtimeCalendarTitle })
    }

    /// 查找用户已有的"年假"日历
    private func annualLeaveCalendar() -> EKCalendar? {
        store.calendars(for: .event).first(where: { $0.title == Self.annualLeaveCalendarTitle })
    }

    /// 在"加班"日历中创建加班事件，返回是否成功
    @discardableResult
    func syncOvertime(date: Date, startTime: Date, endTime: Date) async -> Bool {
        if !hasAccess {
            let granted = await requestAccess()
            guard granted else { return false }
        }

        guard let calendar = overtimeCalendar() else {
            print("未找到「加班」日历，请先在系统日历中创建")
            return false
        }

        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = "加班"
        event.startDate = startTime
        event.endDate = endTime
        event.url = URL(string: "coldplay://overtime")

        do {
            try store.save(event, span: .thisEvent)
            return true
        } catch {
            print("Failed to save overtime event: \(error)")
            return false
        }
    }

    /// 删除某天的考勤事件
    private func removeEvents(on date: Date, in calendar: EKCalendar) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: [calendar])
        let events = store.events(matching: predicate)

        for event in events {
            do {
                try store.remove(event, span: .thisEvent)
            } catch {
                print("Failed to remove calendar event: \(error)")
            }
        }
    }
}
