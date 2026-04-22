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

        // 只有标记今天时才取消提醒（补打历史日期不影响今天的提醒）
        if Calendar.current.isDateInToday(normalized) {
            NotificationService.shared.evaluateReminder(hasTodayRecord: true)
        }

        // 同步到日历（首次会弹出权限请求）
        return await calendar.syncRecord(record)
    }

    // MARK: - 加班

    /// 记录加班并写入"加班"日历，返回日历是否写入成功
    /// Overtime implies work: if the day has no attendance or is rest/annualLeave/compensatoryRest,
    /// it is promoted/overridden to .work. An existing .work record is preserved as-is.
    /// When replaceExisting is true, any existing overtime records and calendar events for that day
    /// are cleared before appending the new one.
    @discardableResult
    func markOvertime(date: Date = Date(), startTime: Date, endTime: Date, replaceExisting: Bool = false) async -> Bool {
        let normalized = Calendar.current.startOfDay(for: date)

        if replaceExisting {
            overtimeRecords.removeAll { Calendar.current.startOfDay(for: $0.date) == normalized }
            await calendar.removeOvertimeEvents(on: normalized)
        }

        var overtime = OvertimeRecord(date: normalized, startTime: startTime, endTime: endTime)
        overtimeRecords.append(overtime)
        persistence.saveOvertime(overtimeRecords)

        let currentType = record(for: normalized)?.type
        if currentType != .work {
            _ = await mark(date: normalized, type: .work)
        } else if Calendar.current.isDateInToday(normalized) {
            NotificationService.shared.evaluateReminder(hasTodayRecord: true)
        }

        let eventID = await calendar.syncOvertime(date: normalized, startTime: startTime, endTime: endTime)
        if let eventID, let index = overtimeRecords.firstIndex(where: { $0.id == overtime.id }) {
            overtime.calendarEventID = eventID
            overtimeRecords[index] = overtime
            persistence.saveOvertime(overtimeRecords)
        }
        return eventID != nil
    }

    func hasOvertime(on date: Date) -> Bool {
        let normalized = Calendar.current.startOfDay(for: date)
        return overtimeRecords.contains { Calendar.current.startOfDay(for: $0.date) == normalized }
    }

    func overtimeHours(on date: Date) -> Double {
        let normalized = Calendar.current.startOfDay(for: date)
        return overtimeRecords
            .filter { Calendar.current.startOfDay(for: $0.date) == normalized }
            .reduce(0.0) { $0 + $1.endTime.timeIntervalSince($1.startTime) / 3600.0 }
    }

    /// Removes any overtime record whose stored calendar event has been deleted from the user's calendar.
    /// Only records with a known calendarEventID are reconciled — legacy records without an ID are left alone.
    /// Returns the number of orphaned records that were removed.
    @discardableResult
    func reconcileOvertimeWithCalendar() async -> Int {
        guard calendar.hasAccess else { return 0 }
        let orphanIDs = overtimeRecords
            .filter { record in
                guard let eventID = record.calendarEventID else { return false }
                return !calendar.overtimeEventExists(eventID: eventID)
            }
            .map(\.id)
        guard !orphanIDs.isEmpty else { return 0 }
        overtimeRecords.removeAll { orphanIDs.contains($0.id) }
        persistence.saveOvertime(overtimeRecords)
        return orphanIDs.count
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
        let compensatoryRestDays: Int
        let annualLeaveDays: Int
        let overtimeHours: Double
        let overtimeDays: Int          // overtimeHours / 8, floored
        let remainingLeave: Int        // (10 + overtimeDays) - annualLeaveDays - compensatoryRestDays
        let totalHours: Double

        /// Display string for overtime:
        /// - Exact multiples of 8h render as whole days ("1 天", "2 天").
        /// - Everything else renders as hours ("1h", "2.5h", "9h", "15h").
        /// This guarantees the day label never appears until a full 8h is actually accrued.
        func overtimeDisplay(daysUnit: String) -> String {
            if overtimeHours > 0 && overtimeHours.truncatingRemainder(dividingBy: 8) == 0 {
                return "\(Int(overtimeHours / 8.0)) \(daysUnit)"
            }
            if overtimeHours.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(overtimeHours))h"
            }
            return String(format: "%.1fh", overtimeHours)
        }
    }

    /// Fiscal year runs Apr 1 – Mar 31. Returns the year of the April start.
    /// e.g. 2026-01-15 → fiscal year 2025 (Apr 2025 – Mar 2026)
    /// e.g. 2026-05-01 → fiscal year 2026 (Apr 2026 – Mar 2027)
    private func fiscalYear(for date: Date) -> Int {
        let cal = Calendar.current
        let month = cal.component(.month, from: date)
        let year = cal.component(.year, from: date)
        return month >= 4 ? year : year - 1
    }

    /// Returns the start date (Apr 1) of the given fiscal year
    private func fiscalYearStart(_ fy: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: fy, month: 4, day: 1))!
    }

    /// Returns the end date (Mar 31 next year) of the given fiscal year
    private func fiscalYearEnd(_ fy: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: fy + 1, month: 3, day: 31))!
    }

    /// Check if a date falls within a fiscal year
    private func isDate(_ date: Date, inFiscalYear fy: Int) -> Bool {
        let start = fiscalYearStart(fy)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: fiscalYearEnd(fy))!
        return date >= start && date < end
    }

    private func overtimeHours(forFiscalYear fy: Int) -> Double {
        overtimeRecords
            .filter { isDate($0.date, inFiscalYear: fy) }
            .reduce(0) { $0 + $1.hours }
    }

    private func overtimeHours(forYear year: Int, month: Int) -> Double {
        overtimeRecords.filter {
            let c = Calendar.current.dateComponents([.year, .month], from: $0.date)
            return c.year == year && c.month == month
        }.reduce(0) { $0 + $1.hours }
    }

    /// 当年度统计（会计年度 4/1 – 3/31）
    var totalStats: Stats {
        let currentFY = fiscalYear(for: Date())
        return stats(forFiscalYear: currentFY)
    }

    func stats(forFiscalYear fy: Int) -> Stats {
        let fyRecords = records.filter { isDate($0.date, inFiscalYear: fy) }
        let workCount = fyRecords.filter { $0.type == .work }.count
        let restCount = fyRecords.filter { $0.type == .rest }.count
        let compensatoryRestCount = fyRecords.filter { $0.type == .compensatoryRest }.count
        let annualLeaveCount = fyRecords.filter { $0.type == .annualLeave }.count
        let otHours = overtimeHours(forFiscalYear: fy)
        let otDays = Int(otHours / 8.0)
        let remaining = max(0, (10 + otDays) - annualLeaveCount - compensatoryRestCount)
        return Stats(
            workDays: workCount,
            restDays: restCount,
            compensatoryRestDays: compensatoryRestCount,
            annualLeaveDays: annualLeaveCount,
            overtimeHours: otHours,
            overtimeDays: otDays,
            remainingLeave: remaining,
            totalHours: Double(workCount) * 8.0
        )
    }

    func stats(forYear year: Int, month: Int) -> Stats {
        let monthRecords = records(forYear: year, month: month)
        let workCount = monthRecords.filter { $0.type == .work }.count
        let restCount = monthRecords.filter { $0.type == .rest }.count
        let compensatoryRestCount = monthRecords.filter { $0.type == .compensatoryRest }.count
        let annualLeaveCount = monthRecords.filter { $0.type == .annualLeave }.count
        let otHours = overtimeHours(forYear: year, month: month)
        let otDays = Int(otHours / 8.0)
        let remaining = max(0, (10 + otDays) - annualLeaveCount - compensatoryRestCount)
        return Stats(
            workDays: workCount,
            restDays: restCount,
            compensatoryRestDays: compensatoryRestCount,
            annualLeaveDays: annualLeaveCount,
            overtimeHours: otHours,
            overtimeDays: otDays,
            remainingLeave: remaining,
            totalHours: Double(workCount) * 8.0
        )
    }

    /// 所有有记录的会计年度（降序）
    var availableYears: [Int] {
        let years = Set(records.map { fiscalYear(for: $0.date) })
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
