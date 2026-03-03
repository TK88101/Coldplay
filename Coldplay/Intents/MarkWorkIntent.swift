import AppIntents

struct MarkWorkIntent: AppIntent {
    static var title: LocalizedStringResource = "记录上班"
    static var description: IntentDescription = "标记今天为工作日"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await AttendanceStore.shared.mark(type: .work)
        return .result(dialog: "已记录今天上班 ✓")
    }
}
