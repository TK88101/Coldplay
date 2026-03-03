import AppIntents

struct MarkRestIntent: AppIntent {
    static var title: LocalizedStringResource = "记录休息"
    static var description: IntentDescription = "标记今天为休息日"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await AttendanceStore.shared.mark(type: .rest)
        return .result(dialog: "已记录今天休息 ✓")
    }
}
