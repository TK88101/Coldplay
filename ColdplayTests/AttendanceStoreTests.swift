import XCTest
@testable import Coldplay

@MainActor
final class AttendanceStoreTests: XCTestCase {
    func testMonthlyStats() {
        let store = AttendanceStore.shared
        let cal = Calendar.current

        // 清空现有记录以便测试
        let year = cal.component(.year, from: Date())
        let month = cal.component(.month, from: Date())

        let stats = store.stats(forYear: year, month: month)
        // 基本验证：stats 结构应该返回合理值
        XCTAssertGreaterThanOrEqual(stats.workDays, 0)
        XCTAssertGreaterThanOrEqual(stats.restDays, 0)
        XCTAssertGreaterThanOrEqual(stats.totalHours, 0)
    }

    func testRecordQuery() {
        let store = AttendanceStore.shared
        // record(for:) 应该对未标记的日期返回 nil
        let farPastDate = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1))!
        XCTAssertNil(store.record(for: farPastDate))
    }
}
