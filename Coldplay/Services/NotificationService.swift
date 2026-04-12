import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let identifier = "coldplay.attendance.reminder"

    private init() {}

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func checkDenied() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .denied
    }

    // MARK: - Reminder toggle

    var reminderEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "attendanceReminderEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "attendanceReminderEnabled") }
    }

    // MARK: - Scheduling

    func scheduleReminder() {
        let loc = LocalizationManager.shared
        let content = UNMutableNotificationContent()
        content.title = loc.reminderTitle
        content.body = loc.reminderBody
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: 12, minute: 0),
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.add(request)
    }

    func cancelReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func evaluateReminder(hasTodayRecord: Bool) {
        guard reminderEnabled else {
            cancelReminder()
            return
        }
        if hasTodayRecord {
            cancelReminder()
            rescheduleForNextDay()
        } else {
            scheduleReminder()
        }
    }

    // MARK: - Next-day scheduling

    private func rescheduleForNextDay() {
        let loc = LocalizationManager.shared
        let content = UNMutableNotificationContent()
        content.title = loc.reminderTitle
        content.body = loc.reminderBody
        content.sound = .default

        let hour = Calendar.current.component(.hour, from: Date())
        let trigger: UNCalendarNotificationTrigger
        if hour < 12 {
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
            comps.hour = 12
            comps.minute = 0
            trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        } else {
            trigger = UNCalendarNotificationTrigger(
                dateMatching: DateComponents(hour: 12, minute: 0),
                repeats: true
            )
        }

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }
}
