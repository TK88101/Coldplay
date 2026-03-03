import SwiftUI

struct StatsView: View {
    @Environment(AttendanceStore.self) private var store
    @State private var selectedYear: Int
    @State private var selectedMonth: Int
    @State private var showShareSheet = false
    @State private var csvURL: URL?

    private let calendar = Calendar.current

    init() {
        let now = Date()
        let components = Calendar.current.dateComponents([.year, .month], from: now)
        _selectedYear = State(initialValue: components.year!)
        _selectedMonth = State(initialValue: components.month!)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("选择月份") {
                    Picker("年份", selection: $selectedYear) {
                        ForEach((selectedYear - 2)...(selectedYear + 1), id: \.self) { year in
                            Text("\(String(year))年").tag(year)
                        }
                    }
                    Picker("月份", selection: $selectedMonth) {
                        ForEach(1...12, id: \.self) { month in
                            Text("\(month)月").tag(month)
                        }
                    }
                }

                Section("统计数据") {
                    let stats = store.stats(forYear: selectedYear, month: selectedMonth)
                    LabeledContent("工作天数") {
                        Text("\(stats.workDays) 天")
                            .foregroundStyle(.blue)
                            .bold()
                    }
                    LabeledContent("休息天数") {
                        Text("\(stats.restDays) 天")
                            .foregroundStyle(.green)
                            .bold()
                    }
                    LabeledContent("总工时") {
                        Text(String(format: "%.1f 小时", stats.totalHours))
                            .bold()
                    }
                }

                Section {
                    Button {
                        csvURL = store.exportCSV()
                        if csvURL != nil {
                            showShareSheet = true
                        }
                    } label: {
                        Label("导出 CSV", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .navigationTitle("统计")
            .sheet(isPresented: $showShareSheet) {
                if let url = csvURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
