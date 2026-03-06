# Coldplay — 考勤助手 PRD

## 产品概述

Coldplay 是一款极简 iOS 考勤打卡应用，专为不固定休息日的工作模式设计。用户每天只需点击一个按钮即可标记上班/休息/年假/加班/补休，记录自动同步到 iPhone 原生日历。采用会计年度制（4/1-3/31），自动计算剩余可休天数（10天年假+加班天数）。

## 目标用户

- 不固定休息日的工作者（如服务业、排班制）
- 需要简单记录出勤情况的个人用户
- 希望在 iPhone 日历中查看工作/休息安排的用户

## 核心功能

### 1. 每日快速打卡

| 项目 | 说明 |
|------|------|
| 操作方式 | 主屏五个胶囊按钮：上班(蓝) / 加班(红) / 休息(绿) / 年假(紫) / 补打卡(橘)，垂直排列。休息点击后弹出选择：「正常休息」或「還休（扣加班）」 |
| 同一天逻辑 | 同一天多次点击只保留最后一次（替换而非累加） |
| 反馈 | 成功后弹出 Confetti 纸花特效 + Toast 提示 |
| 状态展示 | 卡片显示今日已打卡状态（图标 + 类型 + 年月日星期） |

### 2. 补打卡

| 项目 | 说明 |
|------|------|
| 入口 | 主屏第五个胶囊按钮（橘色） |
| 交互 | 弹出 Sheet，含图形化日期选择器（仅可选今天及之前），日历语言跟随 app 设置 |
| 提示 | 如果所选日期已有记录，显示当前标记状态 |
| 确认 | 五个按钮与主界面顺序一致（上班/加班/休息/年假/补休），加班弹出时间选择器 |

### 3. 日历同步

| 项目 | 说明 |
|------|------|
| 考勤日历 | "考勤"（专用日历，自动创建） |
| 上班事件 | 时间段事件，默认 12:00-20:00（JST） |
| 休息事件 | 全天事件 |
| 年假事件 | 全天事件（写入用户已有的"年假"日历） |
| 加班日历 | "加班"（使用用户已有的日历，不自动创建） |
| 加班事件 | 时间段事件，用户选择起止时间 |
| 同步来源 | 优先 iCloud，其次本地日历 |
| 防重复 | 重新标记时先清除所有相关日历（考勤+年假）的旧事件再创建新事件 |
| 权限 | 首次使用自动请求日历权限，权限被拒时仍可本地记录 |

### 4. 年度统计

| 项目 | 说明 |
|------|------|
| 展示位置 | 主屏底部玻璃胶囊栏（与按钮等宽等高） |
| 统计项 | 上班天数、加班天数(不满8h显示小时)、休息天数、剩余可休天数 |
| 年假额度 | 每年度固定10天年假 + 加班天数（8h=1天），补休和年假从中扣除 |
| 剩余可休 | `max(0, 10 + overtimeDays - annualLeaveDays - compensatoryRestDays)` |
| 年度重置 | 会计年度制 4/1 自动归零（4月1日 - 次年3月31日） |
| 历年查看 | 点击统计栏弹出历年统计 Sheet，按年度降序，显示6项数据（工作/休息/加班/年假/补休/剩余可休） |

### 5. 每日提醒

| 项目 | 说明 |
|------|------|
| 触发时间 | 每天 12:00（设备本地时区，即 JST） |
| 内容 | "今天上班吗？" |
| 目的 | 防止用户忘记打卡 |

### 6. Siri 语音快捷指令

| 指令 | 短语示例 |
|------|----------|
| 记录上班 | "用 Coldplay 记录上班"、"在 Coldplay 打卡上班" |
| 记录休息 | "用 Coldplay 记录休息"、"在 Coldplay 打卡休息" |

### 7. CSV 备份与导出

| 项目 | 说明 |
|------|------|
| 格式 | CSV（日期, 类型, 上班时间, 下班时间, 备注） |
| 自动备份 | 每次打卡自动按月保存 CSV（`attendance_YYYY-MM.csv`）到 Documents 目录 |
| 文件可见 | 通过 `UIFileSharingEnabled` 在 iOS「文件」App > Coldplay 下可查看 |
| 手动导出 | 设置页面提供 ShareLink 一键导出完整记录 |
| 数据安全 | 修改打卡（如上班改休息）后 CSV 同步更新 |

### 8. 多语言支持

| 项目 | 说明 |
|------|------|
| 支持语言 | 繁體中文（默认）、日本語 |
| 切换入口 | 设置页面 |
| 覆盖范围 | 所有 UI 文字、日期格式、DatePicker 日历语言 |
| 持久化 | UserDefaults 存储，重启保持选择 |
| 实现 | `LocalizationManager` 单例，`@Observable`，通过 `.environment()` 注入 |

### 9. 设置页

| 项目 | 说明 |
|------|------|
| 入口 | 主屏右上角齿轮图标 |
| 功能 | 语言切换、CSV 导出、自动备份路径提示 |

## 技术架构

### 技术栈

| 项目 | 选型 |
|------|------|
| 语言 | Swift 5.9 |
| 框架 | SwiftUI |
| 最低版本 | iOS 26.0 |
| 日历 | EventKit |
| 语音 | App Intents |
| 通知 | UserNotifications |
| 存储 | 本地 JSON + CSV 自动备份（Documents 目录） |
| 多语言 | LocalizationManager（繁體中文 / 日本語） |
| 动画 | ConfettiSwiftUI (SPM) |
| UI 风格 | iOS 26 Liquid Glass |
| 项目管理 | XcodeGen (project.yml) |
| 分发 | Xcode 免费签名 Sideload / SideStore 自动续签 |

### 架构模式

轻量 MVVM + Service Layer：

```
App/                    → 应用入口
Models/                 → 数据模型 (AttendanceRecord)
Models/
  AttendanceRecord      → 数据模型
  AppLanguage           → 语言枚举 + LocalizationManager 单例
Services/
  PersistenceService    → JSON 读写 + CSV 导出/自动备份
  CalendarService       → EventKit 封装（日历创建/事件管理）
  NotificationService   → 每日提醒调度
Store/
  AttendanceStore       → @Observable 单例，核心业务逻辑（年度统计 + 历年查询）
Views/
  ContentView           → 主界面（Liquid Glass 胶囊按钮 + 历年统计 Sheet）
  SettingsView          → 语言切换 + CSV 导出
Intents/
  MarkWorkIntent        → Siri "记录上班"
  MarkRestIntent        → Siri "记录休息"
  AttendanceShortcuts   → 短语注册
```

### 数据模型

```swift
enum AttendanceType: String, Codable, CaseIterable {
    case work = "上班"
    case rest = "休息"
    case annualLeave = "年假"
    case compensatoryRest = "補休"
}

struct OvertimeRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let startTime: Date
    let endTime: Date
    let createdAt: Date
}

struct AttendanceRecord: Codable, Identifiable {
    let id: UUID
    let date: Date              // 哪一天（标准化到 startOfDay）
    let type: AttendanceType    // 上班 or 休息
    let startTime: Date?        // 上班时间（仅工作日，可选）
    let endTime: Date?          // 下班时间（仅工作日，可选）
    let note: String?           // 备注
    let createdAt: Date         // 创建时间
}
```

### 关键设计决策

| 决策 | 原因 |
|------|------|
| `yyyy-MM-dd` 字符串去重 | 比 `Calendar.isDate(_:inSameDayAs:)` 更可靠，避免时区陷阱 |
| 启动时 `deduplicate()` | 清理历史中可能存在的同一天重复记录 |
| CalendarService 自动请求权限 | `syncRecord()` 内部检查并按需请求，无需手动触发 |
| 单例 `AttendanceStore.shared` | Siri Intent 和 UI 共享同一份数据 |
| JSON 原子写入 | `.atomic` 选项防止写入中断导致数据损坏 |
| 年度统计重置 | `totalStats` 按会计年度（4/1-3/31）过滤，历年数据仍可查看 |
| CSV 每次打卡自动备份 | `autoBackup()` 在 `mark()` 后自动运行，按月分文件，覆盖更新 |
| 不使用 iCloud 容器 | 免费签名不支持 iCloud entitlement，改用 `UIFileSharingEnabled` 本地共享 |
| `LocalizationManager` 字典式本地化 | 轻量方案，无需 .strings 文件，所有字串集中在 `AppLanguage.swift` |

## UI 设计

### 视觉风格

采用 iOS 26 Liquid Glass 设计语言：

- **背景**: 蓝/青/绿微透明渐变，为玻璃效果提供色彩折射
- **状态卡片**: `.glassEffect(.regular)` 圆角矩形，带 `.symbolEffect(.breathe)` 呼吸动画，显示完整年月日星期
- **打卡按钮**: 五个垂直排列的胶囊按钮（`.capsule`），标准液态玻璃效果（`.regular.interactive()`），图标和文字为对应颜色
- **统计栏**: `.glassEffect(.regular, in: .capsule)` 胶囊形玻璃底栏，与按钮等宽等高（56pt），可点击查看历年统计
- **设置入口**: 右上角齿轮图标
- **Toast 提示**: 玻璃材质胶囊，从顶部滑入
- **无障碍**: 尊重 `accessibilityReduceMotion` 系统设置

### 配色

| 元素 | 颜色 |
|------|------|
| 上班图标/文字 | 蓝色 (.blue) |
| 加班图标/文字 | 红色 (.red) |
| 休息图标/文字 | 绿色 (.green) |
| 年假图标/文字 | 紫色 (.purple) |
| 补打卡图标/文字 | 橘色 (.orange) |
| 按钮背景 | 标准液态玻璃（无色彩填充） |
| 未打卡状态 | 次要色 (.secondary) |

## 测试

### 单元测试（6 个，全部通过）

**PersistenceServiceTests (4)**:
- `testSaveAndLoad` — JSON 保存和加载
- `testLoadEmpty` — 空文件加载
- `testExportCSV` — CSV 导出格式验证
- `testRoundTrip` — 完整数据往返（含 startTime/endTime/note）

**AttendanceStoreTests (2)**:
- `testMonthlyStats` — 月度统计结构验证
- `testRecordQuery` — 日期查询（未标记日返回 nil）

## 已知限制

| 限制 | 说明 |
|------|------|
| 7 天签名过期 | 免费签名需每周连 Mac 重装，可通过 SideStore 自动续签。数据不丢失 |
| Siri 中文识别 | 需真机测试，已提供多种短语变体 |
| 无 iCloud 同步 | 免费签名不支持 iCloud 容器，CSV 备份存于本地「文件」App |
| 仅限 iOS 26+ | 使用 Liquid Glass API，不兼容旧版 iOS |

## 构建指南

### 前置条件

- macOS + Xcode 26.2+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Apple ID（用于免费签名）

### 构建步骤

```bash
# 1. 生成 Xcode 项目
xcodegen generate

# 2. 模拟器编译
xcodebuild -scheme Coldplay -sdk iphonesimulator26.2 SYMROOT=/tmp/ColdplayBuild build

# 3. 真机编译（需在 Xcode 中配置签名团队）
xcodebuild -scheme Coldplay -sdk iphoneos26.2 SYMROOT=/tmp/ColdplayBuild -allowProvisioningUpdates build

# 4. 运行测试
xcodebuild -scheme Coldplay -sdk iphonesimulator26.2 SYMROOT=/tmp/ColdplayBuild \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

> **注意**: 构建输出重定向到 `/tmp/ColdplayBuild` 以避免 iCloud 同步目录的扩展属性问题。

## 版本记录

| 版本 | 日期 | 变更 |
|------|------|------|
| 1.0 | 2026-03-04 | 初始版本：快速打卡、日历同步、统计、Siri、通知、补打卡、Liquid Glass UI |
| 1.1 | 2026-03-04 | 多语言（繁中/日语）、CSV 自动备份、年度统计重置+历年查看、胶囊按钮 UI、设置页、SideStore 兼容打包 |
| 1.2 | 2026-03-04 | 新增年假(紫)/加班(红)功能；五按钮布局；统计栏新增年假天数；加班写入独立"加班"日历 |
| 1.3 | 2026-03-06 | 新增补休功能；会计年度制(4/1-3/31)；年假额度系统(10天+加班)；年假写入用户"年假"日历；补打卡新增加班+补休；日历事件去重修复 |
