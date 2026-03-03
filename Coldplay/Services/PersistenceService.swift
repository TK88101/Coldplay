import Foundation

struct PersistenceService {
    private let fileURL: URL

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

    // MARK: - CSV

    func exportCSV(_ records: [AttendanceRecord]) -> URL? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let csvURL = docs.appendingPathComponent("attendance_export.csv")

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
            try csv.write(to: csvURL, atomically: true, encoding: .utf8)
            return csvURL
        } catch {
            print("Failed to export CSV: \(error)")
            return nil
        }
    }
}
