import UserNotifications

struct NotificationService {
    /// 请求通知权限并注册每日 12:00 提醒
    static func scheduleDailyReminder() {
        let center = UNUserNotificationCenter.current()

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }

            // 移除旧的提醒，防止重复
            center.removePendingNotificationRequests(withIdentifiers: ["daily-reminder"])

            let content = UNMutableNotificationContent()
            content.title = "考勤助手"
            content.body = "今天上班吗？"
            content.sound = .default

            // 每天 12:00 触发（使用设备本地时区，即 JST）
            var dateComponents = DateComponents()
            dateComponents.hour = 12
            dateComponents.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

            let request = UNNotificationRequest(
                identifier: "daily-reminder",
                content: content,
                trigger: trigger
            )

            center.add(request)
        }
    }
}
