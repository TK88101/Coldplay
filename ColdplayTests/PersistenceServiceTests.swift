import XCTest
@testable import Coldplay

final class PersistenceServiceTests: XCTestCase {
    private var service: PersistenceService!

    override func setUp() {
        super.setUp()
        service = PersistenceService(fileName: "test_attendance.json")
    }

    override func tearDown() {
        // 清理测试文件
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let testFile = docs.appendingPathComponent("test_attendance.json")
        try? FileManager.default.removeItem(at: testFile)
        let csvFile = docs.appendingPathComponent("attendance_export.csv")
        try? FileManager.default.removeItem(at: csvFile)
        super.tearDown()
    }

    func testSaveAndLoad() {
        let date = Calendar.current.startOfDay(for: Date())
        let records = [
            AttendanceRecord(date: date, type: .work),
            AttendanceRecord(date: date.addingTimeInterval(86400), type: .rest)
        ]

        service.save(records)
        let loaded = service.load()

        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].type, .work)
        XCTAssertEqual(loaded[1].type, .rest)
    }

    func testLoadEmpty() {
        let loaded = service.load()
        XCTAssertTrue(loaded.isEmpty)
    }

    func testExportCSV() {
        let date = Calendar.current.startOfDay(for: Date())
        let records = [
            AttendanceRecord(date: date, type: .work, note: "正常上班"),
            AttendanceRecord(date: date.addingTimeInterval(86400), type: .rest)
        ]

        let url = service.exportCSV(records)
        XCTAssertNotNil(url)

        if let url = url {
            let content = try? String(contentsOf: url, encoding: .utf8)
            XCTAssertNotNil(content)
            XCTAssertTrue(content!.contains("日期,类型,上班时间,下班时间,备注"))
            XCTAssertTrue(content!.contains("上班"))
            XCTAssertTrue(content!.contains("休息"))
            XCTAssertTrue(content!.contains("正常上班"))
        }
    }

    func testRoundTrip() {
        let cal = Calendar.current
        let date = cal.startOfDay(for: Date())
        let startTime = cal.date(bySettingHour: 9, minute: 30, second: 0, of: date)!
        let endTime = cal.date(bySettingHour: 18, minute: 0, second: 0, of: date)!

        let record = AttendanceRecord(
            date: date,
            type: .work,
            startTime: startTime,
            endTime: endTime,
            note: "测试备注"
        )

        service.save([record])
        let loaded = service.load()

        XCTAssertEqual(loaded.count, 1)
        let r = loaded[0]
        XCTAssertEqual(r.type, .work)
        XCTAssertEqual(r.note, "测试备注")
        XCTAssertNotNil(r.startTime)
        XCTAssertNotNil(r.endTime)
    }
}
