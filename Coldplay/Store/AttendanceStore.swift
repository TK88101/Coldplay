import Foundation
import Observation

@Observable
@MainActor
final class AttendanceStore {
    static let shared = AttendanceStore()

    private(set) var records: [AttendanceRecord] = []
    private let persistence = PersistenceService()
    let calendar = CalendarService()

    private init() {
        records = persistence.load()
    }

    // MARK: - 标记

    /// 标记某天的考勤（自动替换同日旧记录）
    func mark(date: Date = Date(), type: AttendanceType, startTime: Date? = nil, endTime: Date? = nil, note: String? = nil) async {
        let normalized = Calendar.current.startOfDay(for: date)

        // 移除同一天的旧记录
        records.removeAll { Calendar.current.isDate($0.date, inSameDayAs: normalized) }

        let record = AttendanceRecord(
            date: normalized,
            type: type,
            startTime: startTime,
            endTime: endTime,
            note: note
        )
        records.append(record)
        persistence.save(records)

        // 尝试同步到日历（最佳努力）
        await calendar.syncRecord(record)
    }

    // MARK: - 查询

    /// 获取某天的记录
    func record(for date: Date) -> AttendanceRecord? {
        let normalized = Calendar.current.startOfDay(for: date)
        return records.first { Calendar.current.isDate($0.date, inSameDayAs: normalized) }
    }

    /// 获取某月的所有记录
    func records(forYear year: Int, month: Int) -> [AttendanceRecord] {
        records.filter { record in
            let components = Calendar.current.dateComponents([.year, .month], from: record.date)
            return components.year == year && components.month == month
        }
    }

    // MARK: - 统计

    struct MonthlyStats {
        let workDays: Int
        let restDays: Int
        let totalHours: Double
    }

    func stats(forYear year: Int, month: Int) -> MonthlyStats {
        let monthRecords = records(forYear: year, month: month)
        let workRecords = monthRecords.filter { $0.type == .work }
        let restRecords = monthRecords.filter { $0.type == .rest }

        let totalHours = workRecords.reduce(0.0) { total, record in
            guard let start = record.startTime, let end = record.endTime else {
                return total + 8.0 // 默认 8 小时
            }
            return total + end.timeIntervalSince(start) / 3600.0
        }

        return MonthlyStats(
            workDays: workRecords.count,
            restDays: restRecords.count,
            totalHours: totalHours
        )
    }

    // MARK: - 导出

    func exportCSV() -> URL? {
        persistence.exportCSV(records)
    }

    // MARK: - 测试支持

    #if DEBUG
    /// 仅用于测试：注入自定义 persistence
    convenience init(persistence: PersistenceService) {
        self.init()
        self.records = persistence.load()
    }
    #endif
}
