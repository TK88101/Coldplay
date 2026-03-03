import Foundation

enum AttendanceType: String, Codable, CaseIterable {
    case work = "上班"
    case rest = "休息"
}

struct AttendanceRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let type: AttendanceType
    let startTime: Date?
    let endTime: Date?
    let note: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date,
        type: AttendanceType,
        startTime: Date? = nil,
        endTime: Date? = nil,
        note: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.startTime = startTime
        self.endTime = endTime
        self.note = note
        self.createdAt = createdAt
    }

    /// 返回该记录日期的标准化版本（去掉时分秒，仅保留年月日）
    var normalizedDate: Date {
        Calendar.current.startOfDay(for: date)
    }
}
