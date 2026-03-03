import AppIntents

struct AttendanceShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: MarkWorkIntent(),
            phrases: [
                "用\(.applicationName)记录上班",
                "在\(.applicationName)打卡上班",
                "\(.applicationName)记录今天上班"
            ],
            shortTitle: "记录上班",
            systemImageName: "briefcase.fill"
        )
        AppShortcut(
            intent: MarkRestIntent(),
            phrases: [
                "用\(.applicationName)记录休息",
                "在\(.applicationName)打卡休息",
                "\(.applicationName)记录今天休息"
            ],
            shortTitle: "记录休息",
            systemImageName: "leaf.fill"
        )
    }
}
