import Foundation
import Observation

enum AppLanguage: String, CaseIterable, Codable {
    case zhHant = "zh-Hant"
    case ja = "ja"

    var displayName: String {
        switch self {
        case .zhHant: return "繁體中文"
        case .ja: return "日本語"
        }
    }

    var locale: Locale {
        switch self {
        case .zhHant: return Locale(identifier: "zh-Hant")
        case .ja: return Locale(identifier: "ja")
        }
    }
}

@Observable
@MainActor
final class LocalizationManager {
    static let shared = LocalizationManager()

    var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "app_language")
        }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "app_language"),
           let lang = AppLanguage(rawValue: saved) {
            language = lang
        } else {
            language = .zhHant
        }
    }

    // MARK: - 考勤类型

    var work: String {
        switch language {
        case .zhHant: return "上班"
        case .ja: return "出勤"
        }
    }

    var rest: String {
        switch language {
        case .zhHant: return "休息"
        case .ja: return "休み"
        }
    }

    var annualLeave: String {
        switch language {
        case .zhHant: return "年假"
        case .ja: return "年次休暇"
        }
    }

    var overtime: String {
        switch language {
        case .zhHant: return "加班"
        case .ja: return "残業"
        }
    }

    var compensatoryRest: String {
        switch language {
        case .zhHant: return "補休"
        case .ja: return "代休"
        }
    }

    // MARK: - 主介面

    var notClockedIn: String {
        switch language {
        case .zhHant: return "今天還沒有打卡"
        case .ja: return "今日はまだ打刻なし"
        }
    }

    var backfill: String {
        switch language {
        case .zhHant: return "補打卡"
        case .ja: return "追加打刻"
        }
    }

    var settings: String {
        switch language {
        case .zhHant: return "設定"
        case .ja: return "設定"
        }
    }

    // MARK: - Toast

    func writtenToCalendar(_ label: String) -> String {
        switch language {
        case .zhHant: return "\(label) 已寫入日曆 ✓"
        case .ja: return "\(label) カレンダー記録済み ✓"
        }
    }

    func recorded(_ label: String) -> String {
        switch language {
        case .zhHant: return "\(label) 已記錄"
        case .ja: return "\(label) 記録済み"
        }
    }

    func backfillWritten(date: String, label: String) -> String {
        switch language {
        case .zhHant: return "\(date) \(label) 已寫入日曆 ✓"
        case .ja: return "\(date) \(label) カレンダー記録済み ✓"
        }
    }

    func backfillRecorded(date: String, label: String) -> String {
        switch language {
        case .zhHant: return "\(date) \(label) 已記錄"
        case .ja: return "\(date) \(label) 記録済み"
        }
    }

    // MARK: - 统计

    var workDaysLabel: String {
        switch language {
        case .zhHant: return "上班"
        case .ja: return "出勤"
        }
    }

    var restDaysLabel: String {
        switch language {
        case .zhHant: return "休息"
        case .ja: return "休み"
        }
    }

    var annualLeaveDaysLabel: String {
        switch language {
        case .zhHant: return "年假"
        case .ja: return "年休"
        }
    }

    var overtimeLabel: String {
        switch language {
        case .zhHant: return "加班"
        case .ja: return "残業"
        }
    }

    var compensatoryRestLabel: String {
        switch language {
        case .zhHant: return "補休"
        case .ja: return "代休"
        }
    }

    var remainingLeaveLabel: String {
        switch language {
        case .zhHant: return "剩餘可休"
        case .ja: return "残り休暇"
        }
    }

    var overtimeDaysLabel: String {
        switch language {
        case .zhHant: return "加班天數"
        case .ja: return "残業日数"
        }
    }

    var normalRest: String {
        switch language {
        case .zhHant: return "正常休息"
        case .ja: return "通常休み"
        }
    }

    var compensatoryRestChoice: String {
        switch language {
        case .zhHant: return "還休（扣加班）"
        case .ja: return "代休（残業から差引）"
        }
    }

    var hoursLabel: String {
        switch language {
        case .zhHant: return "工時"
        case .ja: return "勤務"
        }
    }

    var daysUnit: String {
        switch language {
        case .zhHant: return "天"
        case .ja: return "日"
        }
    }

    // MARK: - 补打卡 Sheet

    var selectDate: String {
        switch language {
        case .zhHant: return "選擇日期"
        case .ja: return "日付を選択"
        }
    }

    func alreadyMarked(_ label: String) -> String {
        switch language {
        case .zhHant: return "該日已標記：\(label)"
        case .ja: return "この日は記録済み：\(label)"
        }
    }

    var cancel: String {
        switch language {
        case .zhHant: return "取消"
        case .ja: return "キャンセル"
        }
    }

    var confirm: String {
        switch language {
        case .zhHant: return "確認"
        case .ja: return "確認"
        }
    }

    var overtimeStart: String {
        switch language {
        case .zhHant: return "開始時間"
        case .ja: return "開始時刻"
        }
    }

    var overtimeEnd: String {
        switch language {
        case .zhHant: return "結束時間"
        case .ja: return "終了時刻"
        }
    }

    var noOvertimeCalendar: String {
        switch language {
        case .zhHant: return "未找到「加班」日曆，請先在系統日曆中建立"
        case .ja: return "「残業」カレンダーが見つかりません。システムカレンダーで作成してください"
        }
    }

    // MARK: - 设置页

    var languageLabel: String {
        switch language {
        case .zhHant: return "語言"
        case .ja: return "言語"
        }
    }

    // MARK: - 年度统计

    var yearLabel: String {
        switch language {
        case .zhHant: return "年"
        case .ja: return "年"
        }
    }

    var yearlyStats: String {
        switch language {
        case .zhHant: return "歷年統計"
        case .ja: return "年間統計"
        }
    }

    var currentYearTag: String {
        switch language {
        case .zhHant: return "今年"
        case .ja: return "今年"
        }
    }

    var fiscalYearLabel: String {
        switch language {
        case .zhHant: return "年度"
        case .ja: return "年度"
        }
    }

    var currentFiscalYearTag: String {
        switch language {
        case .zhHant: return "本年度"
        case .ja: return "今年度"
        }
    }

    // MARK: - 数据

    var dataLabel: String {
        switch language {
        case .zhHant: return "資料"
        case .ja: return "データ"
        }
    }

    var exportCSV: String {
        switch language {
        case .zhHant: return "匯出 CSV"
        case .ja: return "CSVエクスポート"
        }
    }

    var autoBackupHint: String {
        switch language {
        case .zhHant: return "每次打卡自動備份至「檔案」App > Coldplay"
        case .ja: return "打刻ごとに「ファイル」App > Coldplay へ自動バックアップ"
        }
    }

    // MARK: - 辅助

    func displayName(for type: AttendanceType) -> String {
        switch type {
        case .work: return work
        case .rest: return rest
        case .annualLeave: return annualLeave
        case .compensatoryRest: return compensatoryRest
        }
    }
}
