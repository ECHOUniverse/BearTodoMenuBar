# 系统提醒事项：已逾期分组 & 红色截止日期

## 概述

为菜单栏系统提醒事项栏目新增"已逾期"分组，将超过截止日期的提醒展示在已逾期区域。同时在每条提醒标题下方以红色文字显示具体截止日期。

## 当前状态分析

| 项目                     | 当前实现                                                | 问题                            |
| ---------------------- | --------------------------------------------------- | ----------------------------- |
| `ReminderDueCategory`  | `.today`, `.tomorrow`, `.scheduled`, `.unscheduled` | 过期的提醒会被归入 `.scheduled`，没有视觉区分 |
| `SystemReminderItem`   | 无 `dueDate` 字段                                      | 视图中无法显示具体日期                   |
| `ReminderMenuItemView` | 单行 `Text(title)`                                    | 无法展示二级日期信息                    |
| `categorizeDueDate()`  | 只判断今天/明天/已安排/未安排                                    | 不检测是否已过期                      |
| L10n                   | 无 overdue 字符串                                       | —                             |

## 修改计划

### 文件 1: `Sources/BearTodoMenuBar/Models/TodoItem.swift`

**变更内容：**

1. `ReminderDueCategory` 新增 `.overdue` 枚举项，放在 `.today` **之前**（利用 `CaseIterable` 自动排序），确保菜单栏中已逾期显示在最顶部：

```swift
enum ReminderDueCategory: String, CaseIterable {
    case overdue
    case today
    case tomorrow
    case scheduled
    case unscheduled
}
```

1. `SystemReminderItem` 新增 `dueDate: Date?` 字段：

```swift
struct SystemReminderItem: Identifiable {
    let id: String
    let title: String
    let dueCategory: ReminderDueCategory
    let reminderIdentifier: String
    let dueDate: Date?
}
```

**理由：** 视图层需要原始 `Date` 来展示具体截止日期，无法仅靠枚举分类还原。

***

### 文件 2: `Sources/BearTodoMenuBar/Services/ReminderService.swift`

**变更内容：**

1. `categorizeDueDate()` 方法增加过期判断逻辑（第322-340行）。将 `dueDateComponents` 转为 `Date`，与今日 00:00:00 比较：

```swift
private func categorizeDueDate(from components: DateComponents?, today: DateComponents, tomorrow: DateComponents)
    -> ReminderDueCategory
{
    guard let components = components,
        let year = components.year,
        let month = components.month,
        let day = components.day
    else {
        return .unscheduled
    }

    if year == today.year && month == today.month && day == today.day {
        return .today
    }
    if year == tomorrow.year && month == tomorrow.month && day == tomorrow.day {
        return .tomorrow
    }

    let cal = Calendar.current
    let todayStart = cal.startOfDay(for: Date())
    if let dueDate = cal.date(from: components), dueDate < todayStart {
        return .overdue
    }

    return .scheduled
}
```

1. `fetchUncompletedReminders()` 方法中：

   * 新增 `var overdueItems: [SystemReminderItem] = []`（第212行附近，与其他数组并列）

   * 在构建 `SystemReminderItem` 时计算 `dueDate` 并传入（约第230行）：

```swift
let dueDate: Date? = {
    if let comps = reminder.dueDateComponents {
        return Calendar.current.date(from: comps)
    }
    return nil
}()
let item = SystemReminderItem(
    id: identifier, title: title, dueCategory: category,
    reminderIdentifier: identifier, dueDate: dueDate)
```

* 在 switch 中添加 `.overdue` 分支：

```swift
case .overdue: overdueItems.append(item)
```

* 在最终拼接 `allItems` 时把 overdue 放在最前（第245行附近）：

```swift
let allItems =
    sortBlock(overdueItems) + sortBlock(todayItems) + sortBlock(tomorrowItems)
    + sortBlock(scheduledItems) + sortBlock(unscheduledItems)
```

***

### 文件 3: `Sources/BearTodoMenuBar/Views/MenuBarContent.swift`

**变更内容：**

1. `buildSectionRows()` 方法中的 category switch（第238-244行）新增 `.overdue` 分支：

```swift
case .overdue: return L10n.overdueSection
```

1. `ReminderMenuItemView` 调用处（第257-268行）传入 `dueDate` 参数：

```swift
ReminderMenuItemView(
    title: reminder.title,
    reminderIdentifier: reminder.reminderIdentifier,
    dueDate: reminder.dueDate,
    onToggleComplete: { ... },
    onOpenReminder: { ... },
    onRequestRefresh: { ... }
)
```

***

### 文件 4: `Sources/BearTodoMenuBar/Views/ReminderMenuItemView.swift`

**变更内容：**

1. 新增 `dueDate: Date?` 属性
2. 将单行 `Text(title)` 改为 `VStack` 布局：标题 + 条件渲染的红色日期：

```swift
let dueDate: Date?

// body 中的 Text(title) 替换为：
Button {
    onOpenReminder()
} label: {
    VStack(alignment: .leading, spacing: 2) {
        Text(title)
            .font(.body)
            .lineLimit(1)
            .truncationMode(.tail)
        if let dueDate = dueDate {
            Text(dueDate, style: .date)
                .font(.system(size: 10))
                .foregroundColor(.red)
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}
.buttonStyle(.plain)
```

**注意：** `Text(date, style: .date)` 会根据系统区域设置自动格式化（中文环境显示 "2026年6月5日"，英文环境显示 "Jun 5, 2026"）。

***

### 文件 5: `Sources/BearTodoMenuBar/Services/L10n.swift`

**变更内容：**

1. `StringKey` 枚举（第48-105行）新增：

```swift
case overdueSection
```

1. `zhStrings` 字典新增：

```swift
.overdueSection: "已逾期",
```

1. `enStrings` 字典新增：

```swift
.overdueSection: "Overdue",
```

1. 新增静态属性（放在 `unscheduledSection` 附近）：

```swift
static var overdueSection: String { tr(.overdueSection) }
```

***

## 假设与决策

| # | 决策                                                 | 理由                                             |
| - | -------------------------------------------------- | ---------------------------------------------- |
| 1 | overdue 排序在最前                                      | 过期项最需要用户关注，排在今天之前                              |
| 2 | 截止日期只显示日期不显示时间                                     | `Text(date, style: .date)` 简洁且本地化友好；过期的本质是日期级别 |
| 3 | 截止日期对所有有日期的提醒统一显示红色                                | 用户所有提醒的 due date 都以红色标注，不仅仅是已逾期项，增强紧迫感         |
| 4 | 仅在 `dueDate != nil` 时显示日期行                         | 未安排提醒无截止日期，不显示空白行，保持界面干净                       |
| 5 | 使用 `Calendar.current.startOfDay(for: Date())` 判断过期 | 与 EventKit 日期组件对比逻辑一致                          |

## 验证步骤

1. `swift build` 编译通过
2. 手动测试：在 Reminders.app 中创建已过期的提醒，打开菜单栏确认出现在"已逾期"分组
3. 确认已逾期条目下方显示红色截止日期
4. 确认今天/明天的提醒也显示红色截止日期
5. 确认未安排提醒不显示日期行
6. 切换系统语言验证中/英文字符串

