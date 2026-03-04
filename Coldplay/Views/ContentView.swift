import SwiftUI
import ConfettiSwiftUI

struct ContentView: View {
    @Environment(AttendanceStore.self) private var store
    @Environment(LocalizationManager.self) private var loc
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var toastMessage: String?
    @State private var confettiTrigger = 0
    @State private var showBackfill = false
    @State private var backfillDate = Date()
    @State private var showSettings = false
    @State private var showYearlyStats = false
    @State private var showOvertime = false
    @State private var overtimeStart = Date()
    @State private var overtimeEnd = Date()
    @Namespace private var glassNS

    private var todayRecord: AttendanceRecord? {
        store.record(for: Date())
    }

    var body: some View {
        ZStack {
            // 渐变背景 — 给 Liquid Glass 提供色彩折射
            LinearGradient(
                colors: [.blue.opacity(0.15), .cyan.opacity(0.1), .green.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // 设置按钮 — 右上角
                HStack {
                    Spacer()
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                Spacer()

                // 当前状态 — Liquid Glass 卡片
                statusCard
                    .padding(.bottom, 32)

                // 五个按钮 — 上班 / 加班 / 休息 / 年假 / 补打卡（垂直排列，胶囊形）
                GlassEffectContainer(spacing: 14) {
                    VStack(spacing: 14) {
                        actionButton(
                            label: loc.work,
                            icon: "briefcase.fill",
                            tint: .blue
                        ) {
                            performMark(type: .work)
                        }

                        actionButton(
                            label: loc.overtime,
                            icon: "moon.fill",
                            tint: .red
                        ) {
                            overtimeStart = Date()
                            overtimeEnd = Date().addingTimeInterval(3600)
                            showOvertime = true
                        }

                        actionButton(
                            label: loc.rest,
                            icon: "leaf.fill",
                            tint: .green
                        ) {
                            performMark(type: .rest)
                        }

                        actionButton(
                            label: loc.annualLeave,
                            icon: "airplane",
                            tint: .purple
                        ) {
                            performMark(type: .annualLeave)
                        }

                        actionButton(
                            label: loc.backfill,
                            icon: "calendar.badge.plus",
                            tint: .orange
                        ) {
                            backfillDate = Date()
                            showBackfill = true
                        }
                    }
                }
                .padding(.horizontal, 24)
                .confettiCannon(trigger: $confettiTrigger, num: 30, radius: 300)

                Spacer()

                // 累计统计 — Liquid Glass 底栏
                statsBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }

            // Toast 提示
            if let message = toastMessage {
                VStack {
                    Text(message)
                        .font(.subheadline.bold())
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .glassEffect(.regular, in: .capsule)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .padding(.top, 60)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: toastMessage)
        .sheet(isPresented: $showBackfill) {
            backfillSheet
        }
        .sheet(isPresented: $showOvertime) {
            overtimeSheet
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(loc)
                .environment(store)
        }
    }

    // MARK: - 状态卡片

    @ViewBuilder
    private var statusCard: some View {
        if let record = todayRecord {
            VStack(spacing: 12) {
                Image(systemName: iconName(for: record.type))
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(iconColor(for: record.type))
                    .symbolEffect(.breathe, isActive: !reduceMotion)

                Text(loc.displayName(for: record.type))
                    .font(.title2.bold())

                Text(Date().formatted(.dateTime.year().month(.wide).day().weekday(.wide).locale(loc.language.locale)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 28)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28))
        } else {
            VStack(spacing: 12) {
                Image(systemName: "clock")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(loc.notClockedIn)
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text(Date().formatted(.dateTime.year().month(.wide).day().weekday(.wide).locale(loc.language.locale)))
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 28)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28))
        }
    }

    // MARK: - 操作按钮（矩形）

    private func actionButton(label: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(tint)
                Text(label)
                    .font(.headline)
                    .foregroundStyle(tint)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    // MARK: - 打卡操作

    private func performMark(type: AttendanceType) {
        Task {
            let synced = await store.mark(type: type)
            withAnimation(.bouncy) {
                confettiTrigger += 1
            }
            let label = loc.displayName(for: type)
            toastMessage = synced ? loc.writtenToCalendar(label) : loc.recorded(label)
            try? await Task.sleep(for: .seconds(2))
            toastMessage = nil
        }
    }

    // MARK: - 补打卡 Sheet

    private var backfillSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                DatePicker(
                    loc.selectDate,
                    selection: $backfillDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal)

                if let existing = store.record(for: backfillDate) {
                    Text(loc.alreadyMarked(loc.displayName(for: existing.type)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Button {
                        performBackfill(type: .work)
                    } label: {
                        Label(loc.work, systemImage: "briefcase.fill")
                            .font(.headline)
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)

                    Button {
                        performBackfill(type: .rest)
                    } label: {
                        Label(loc.rest, systemImage: "leaf.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)

                    Button {
                        performBackfill(type: .annualLeave)
                    } label: {
                        Label(loc.annualLeave, systemImage: "airplane")
                            .font(.headline)
                            .foregroundStyle(.purple)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .navigationTitle(loc.backfill)
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.locale, loc.language.locale)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc.cancel) { showBackfill = false }
                }
            }
        }
    }

    private func performBackfill(type: AttendanceType) {
        Task {
            let synced = await store.mark(date: backfillDate, type: type)
            showBackfill = false
            withAnimation(.bouncy) {
                confettiTrigger += 1
            }
            let dateStr = backfillDate.formatted(.dateTime.month(.abbreviated).day().locale(loc.language.locale))
            let label = loc.displayName(for: type)
            toastMessage = synced ? loc.backfillWritten(date: dateStr, label: label) : loc.backfillRecorded(date: dateStr, label: label)
            try? await Task.sleep(for: .seconds(2))
            toastMessage = nil
        }
    }

    // MARK: - 加班 Sheet

    private var overtimeSheet: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                DatePicker(
                    loc.overtimeStart,
                    selection: $overtimeStart,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()

                Text(loc.overtimeStart)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider().padding(.horizontal, 40)

                DatePicker(
                    loc.overtimeEnd,
                    selection: $overtimeEnd,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()

                Text(loc.overtimeEnd)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    performOvertime()
                } label: {
                    Label(loc.confirm, systemImage: "checkmark")
                        .font(.headline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .glassEffect(.regular.interactive(), in: .capsule)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationTitle(loc.overtime)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc.cancel) { showOvertime = false }
                }
            }
        }
    }

    private func performOvertime() {
        Task {
            let synced = await store.markOvertime(startTime: overtimeStart, endTime: overtimeEnd)
            showOvertime = false
            withAnimation(.bouncy) {
                confettiTrigger += 1
            }
            toastMessage = synced ? loc.writtenToCalendar(loc.overtime) : loc.recorded(loc.overtime)
            try? await Task.sleep(for: .seconds(2))
            toastMessage = nil
        }
    }

    // MARK: - 统计栏（点击查看历年）

    private var statsBar: some View {
        let stats = store.totalStats
        return Button {
            showYearlyStats = true
        } label: {
            HStack(spacing: 0) {
                statItem(label: loc.workDaysLabel, value: "\(stats.workDays) \(loc.daysUnit)", color: .blue)
                Spacer()
                Divider().frame(height: 24)
                Spacer()
                statItem(label: loc.restDaysLabel, value: "\(stats.restDays) \(loc.daysUnit)", color: .green)
                Spacer()
                Divider().frame(height: 24)
                Spacer()
                statItem(label: loc.annualLeaveDaysLabel, value: "\(stats.annualLeaveDays) \(loc.daysUnit)", color: .purple)
                Spacer()
                Divider().frame(height: 24)
                Spacer()
                statItem(label: loc.hoursLabel, value: "\(Int(stats.totalHours))h", color: .primary)
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
        .glassEffect(.regular, in: .capsule)
        .sheet(isPresented: $showYearlyStats) {
            yearlyStatsSheet
        }
    }

    // MARK: - 历年统计 Sheet

    private var yearlyStatsSheet: some View {
        NavigationStack {
            List {
                ForEach(store.availableYears, id: \.self) { year in
                    let s = store.stats(forYear: year)
                    let currentYear = Calendar.current.component(.year, from: Date())
                    Section {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("\(s.workDays) \(loc.daysUnit)", systemImage: "briefcase.fill")
                                    .foregroundStyle(.blue)
                                Text(loc.workDaysLabel)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .leading, spacing: 4) {
                                Label("\(s.restDays) \(loc.daysUnit)", systemImage: "leaf.fill")
                                    .foregroundStyle(.green)
                                Text(loc.restDaysLabel)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .leading, spacing: 4) {
                                Label("\(s.annualLeaveDays) \(loc.daysUnit)", systemImage: "airplane")
                                    .foregroundStyle(.purple)
                                Text(loc.annualLeaveDaysLabel)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .leading, spacing: 4) {
                                Label("\(Int(s.totalHours))h", systemImage: "clock")
                                    .foregroundStyle(.primary)
                                Text(loc.hoursLabel)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        HStack {
                            Text("\(String(year)) \(loc.yearLabel)")
                                .font(.headline)
                            if year == currentYear {
                                Text(loc.currentYearTag)
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle(loc.yearlyStats)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showYearlyStats = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func statItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 类型图标/颜色

    private func iconName(for type: AttendanceType) -> String {
        switch type {
        case .work: return "briefcase.fill"
        case .rest: return "leaf.fill"
        case .annualLeave: return "airplane"
        }
    }

    private func iconColor(for type: AttendanceType) -> Color {
        switch type {
        case .work: return .blue
        case .rest: return .green
        case .annualLeave: return .purple
        }
    }
}
