import Foundation
import Observation

@Observable
@MainActor
final class AttendanceStore {
    static let shared = AttendanceStore()

    private(set) var records: [AttendanceRecord] = []
    private(set) var overtimeRecords: [OvertimeRecord] = []
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
        overtimeRecords = persistence.loadOvertime()
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
        persistence.autoBackup(records)

        // 同步到日历（首次会弹出权限请求）
        return await calendar.syncRecord(record)
    }

    // MARK: - 加班

    /// 记录加班并写入"加班"日历，返回日历是否写入成功
    @discardableResult
    func markOvertime(date: Date = Date(), startTime: Date, endTime: Date) async -> Bool {
        let normalized = Calendar.current.startOfDay(for: date)
        let record = OvertimeRecord(date: normalized, startTime: startTime, endTime: endTime)
        overtimeRecords.append(record)
        persistence.saveOvertime(overtimeRecords)
        return await calendar.syncOvertime(date: normalized, startTime: startTime, endTime: endTime)
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
        let annualLeaveDays: Int
        let overtimeHours: Double
        let totalHours: Double
    }

    private func overtimeHours(forYear year: Int) -> Double {
        overtimeRecords
            .filter { Calendar.current.component(.year, from: $0.date) == year }
            .reduce(0) { $0 + $1.hours }
    }

    private func overtimeHours(forYear year: Int, month: Int) -> Double {
        overtimeRecords.filter {
            let c = Calendar.current.dateComponents([.year, .month], from: $0.date)
            return c.year == year && c.month == month
        }.reduce(0) { $0 + $1.hours }
    }

    /// 当年统计（每年 1/1 重置）
    var totalStats: Stats {
        let currentYear = Calendar.current.component(.year, from: Date())
        let yearRecords = records.filter {
            Calendar.current.component(.year, from: $0.date) == currentYear
        }
        let workCount = yearRecords.filter { $0.type == .work }.count
        let restCount = yearRecords.filter { $0.type == .rest }.count
        let annualLeaveCount = yearRecords.filter { $0.type == .annualLeave }.count
        let otHours = overtimeHours(forYear: currentYear)
        return Stats(workDays: workCount, restDays: restCount, annualLeaveDays: annualLeaveCount, overtimeHours: otHours, totalHours: Double(workCount) * 8.0)
    }

    func stats(forYear year: Int) -> Stats {
        let yearRecords = records.filter {
            Calendar.current.component(.year, from: $0.date) == year
        }
        let workCount = yearRecords.filter { $0.type == .work }.count
        let restCount = yearRecords.filter { $0.type == .rest }.count
        let annualLeaveCount = yearRecords.filter { $0.type == .annualLeave }.count
        let otHours = overtimeHours(forYear: year)
        return Stats(workDays: workCount, restDays: restCount, annualLeaveDays: annualLeaveCount, overtimeHours: otHours, totalHours: Double(workCount) * 8.0)
    }

    func stats(forYear year: Int, month: Int) -> Stats {
        let monthRecords = records(forYear: year, month: month)
        let workCount = monthRecords.filter { $0.type == .work }.count
        let restCount = monthRecords.filter { $0.type == .rest }.count
        let annualLeaveCount = monthRecords.filter { $0.type == .annualLeave }.count
        let otHours = overtimeHours(forYear: year, month: month)
        return Stats(workDays: workCount, restDays: restCount, annualLeaveDays: annualLeaveCount, overtimeHours: otHours, totalHours: Double(workCount) * 8.0)
    }

    /// 所有有记录的年份（降序）
    var availableYears: [Int] {
        let years = Set(records.map { Calendar.current.component(.year, from: $0.date) })
        return years.sorted(by: >)
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
