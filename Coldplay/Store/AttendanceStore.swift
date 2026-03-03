import Foundation
import Observation

@Observable
@MainActor
final class AttendanceStore {
    static let shared = AttendanceStore()

    private(set) var records: [AttendanceRecord] = []
    private let persistence = PersistenceService()
    let calendar = CalendarService()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private init() {
        records = persistence.load()
        deduplicate()
    }

    /// 启动时清理可能存在的同一天重复记录（保留最新的）
    private func deduplicate() {
        var seen = Set<String>()
        var cleaned = [AttendanceRecord]()
        // 从后往前遍历，保留每天最新的记录
        for record in records.reversed() {
            let key = Self.dayFormatter.string(from: record.date)
            if !seen.contains(key) {
                seen.insert(key)
                cleaned.append(record)
            }
        }
        if cleaned.count != records.count {
            records = cleaned.reversed()
            persistence.save(records)
        }
    }

    // MARK: - 日期 key

    private func dayKey(for date: Date) -> String {
        Self.dayFormatter.string(from: date)
    }

    // MARK: - 标记

    /// 标记某天的考勤（同一天只保留最新一次），返回日历是否写入成功
    @discardableResult
    func mark(date: Date = Date(), type: AttendanceType, startTime: Date? = nil, endTime: Date? = nil, note: String? = nil) async -> Bool {
        let normalized = Calendar.current.startOfDay(for: date)
        let key = dayKey(for: normalized)

        // 用日期字符串精确去重，确保同一天只有一条记录
        records.removeAll { dayKey(for: $0.date) == key }

        let record = AttendanceRecord(
            date: normalized,
            type: type,
            startTime: startTime,
            endTime: endTime,
            note: note
        )
        records.append(record)
        persistence.save(records)

        // 同步到日历（首次会弹出权限请求）
        return await calendar.syncRecord(record)
    }

    // MARK: - 查询

    func record(for date: Date) -> AttendanceRecord? {
        let key = dayKey(for: date)
        return records.first { dayKey(for: $0.date) == key }
    }

    func records(forYear year: Int, month: Int) -> [AttendanceRecord] {
        records.filter { record in
            let components = Calendar.current.dateComponents([.year, .month], from: record.date)
            return components.year == year && components.month == month
        }
    }

    // MARK: - 统计

    struct Stats {
        let workDays: Int
        let restDays: Int
        let totalHours: Double
    }

    var totalStats: Stats {
        let workCount = records.filter { $0.type == .work }.count
        let restCount = records.filter { $0.type == .rest }.count
        return Stats(workDays: workCount, restDays: restCount, totalHours: Double(workCount) * 8.0)
    }

    func stats(forYear year: Int, month: Int) -> Stats {
        let monthRecords = records(forYear: year, month: month)
        let workCount = monthRecords.filter { $0.type == .work }.count
        let restCount = monthRecords.filter { $0.type == .rest }.count
        return Stats(workDays: workCount, restDays: restCount, totalHours: Double(workCount) * 8.0)
    }

    // MARK: - 导出

    func exportCSV() -> URL? {
        persistence.exportCSV(records)
    }

    // MARK: - 测试支持

    #if DEBUG
    convenience init(persistence: PersistenceService) {
        self.init()
        self.records = persistence.load()
    }
    #endif
}
