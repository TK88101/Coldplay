import Foundation

struct PersistenceService {
    private let fileURL: URL

    /// 「文件」App > Coldplay 文件夹（UIFileSharingEnabled 已开启）
    static var backupDir: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        if !FileManager.default.fileExists(atPath: docs.path) {
            try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        }
        return docs
    }

    init(fileName: String = "attendance.json") {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = docs.appendingPathComponent(fileName)
    }

    // MARK: - JSON

    func load() -> [AttendanceRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([AttendanceRecord].self, from: data)
        } catch {
            print("Failed to load records: \(error)")
            return []
        }
    }

    func save(_ records: [AttendanceRecord]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(records)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save records: \(error)")
        }
    }

    // MARK: - CSV 导出（全部记录）

    func exportCSV(_ records: [AttendanceRecord]) -> URL? {
        let csvURL = Self.backupDir.appendingPathComponent("attendance_export.csv")
        return writeCSV(records: records, to: csvURL)
    }

    // MARK: - CSV 自动备份（按年月）

    func autoBackup(_ records: [AttendanceRecord]) {
        let cal = Calendar.current
        // 按年月分组
        var grouped: [String: [AttendanceRecord]] = [:]
        for r in records {
            let comps = cal.dateComponents([.year, .month], from: r.date)
            let key = String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
            grouped[key, default: []].append(r)
        }

        for (yearMonth, monthRecords) in grouped {
            let fileName = "attendance_\(yearMonth).csv"
            let url = Self.backupDir.appendingPathComponent(fileName)
            _ = writeCSV(records: monthRecords, to: url)
        }
    }

    // MARK: - CSV 写入

    private func writeCSV(records: [AttendanceRecord], to url: URL) -> URL? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        var csv = "日期,类型,上班时间,下班时间,备注\n"
        let sorted = records.sorted { $0.date < $1.date }
        for r in sorted {
            let dateStr = dateFormatter.string(from: r.date)
            let typeStr = r.type.rawValue
            let startStr = r.startTime.map { timeFormatter.string(from: $0) } ?? ""
            let endStr = r.endTime.map { timeFormatter.string(from: $0) } ?? ""
            let noteStr = r.note ?? ""
            csv += "\(dateStr),\(typeStr),\(startStr),\(endStr),\(noteStr)\n"
        }

        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            print("Failed to export CSV: \(error)")
            return nil
        }
    }
}
