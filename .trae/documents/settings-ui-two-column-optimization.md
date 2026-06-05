# 设置界面UI优化计划

## 概述

将当前单列设置面板重构为双列布局，增加保存按钮，优化 macOS Liquid Glass 视觉效果。

***

## 当前状态分析

### 现有架构

* **SettingsView\.swift** (`Sources/BearTodoMenuBar/Views/SettingsView.swift`): 单列 `VStack`，固定宽度 420px，包含 7 个 `GlassCard` 卡片

* **AppDelegate** (`Sources/BearTodoMenuBar/BearTodoMenuBarApp.swift`): 在 `openSettings()` 中创建窗口，尺寸 420×620

* **DesignComponents.swift** (`Sources/BearTodoMenuBar/Views/DesignComponents.swift`): `GlassCard` 使用 `.ultraThinMaterial` + 0.5px `.primary.opacity(0.08)` 边框

* **数据持久化**: 通过 `KeychainStorage` + `@AppStorage`，所有变更通过 `onChange` 立即写入

### 当前设置项（7项）

| 卡片            | 控件类型                | 持久化方式               |
| ------------- | ------------------- | ------------------- |
| 系统提醒事项        | Toggle + 权限状态       | KeychainStorage     |
| 同步间隔          | Slider (0/1/3/5/7s) | KeychainStorage     |
| 开机启动          | Toggle              | KeychainStorage     |
| 显示已完成事项       | Toggle              | KeychainStorage     |
| 数据库访问授权       | Button + 状态         | BearBookmarkManager |
| 语言 / Language | Segmented Picker    | @AppStorage         |
| GitHub 链接     | Link                | 无                   |

***

## 修改计划

### 1. SettingsView\.swift — 双列布局 + 保存按钮

**文件**: `Sources/BearTodoMenuBar/Views/SettingsView.swift`

#### 1.1 状态管理改造

当前所有设置通过 `onChange` 立即持久化。需要改为"缓冲 + 保存"模式：

```swift
// 本地编辑缓冲（@State，不直接写入 KeychainStorage）
@State private var draftReminderSync: Bool
@State private var draftLaunchAtLogin: Bool
@State private var draftCompletedSection: Bool
@State private var draftSyncIntervalIndex: Double
@State private var draftLanguage: Language

// 用 init 从 KeychainStorage/@AppStorage 读取初始值
// 点击保存时批量写入
```

例外：**数据库授权**是即时操作（调用 NSOpenPanel），不需要缓冲。**语言切换**影响整个 UI，可以即时生效但需记录草稿状态。

#### 1.2 双列布局结构

```
┌──────────────────────────────────────────────────────┐
│  设置                                         Header │
│  配置 Bear 待办同步选项                               │
├──────────────────────┬───────────────────────────────┤
│  一般设置             │  同步与集成                    │
│  ┌─────────────────┐ │ ┌───────────────────────────┐ │
│  │ 语言 / Language │ │ │ 系统提醒事项               │ │
│  └─────────────────┘ │ └───────────────────────────┘ │
│  ┌─────────────────┐ │ ┌───────────────────────────┐ │
│  │ 开机启动         │ │ │ 同步间隔                   │ │
│  └─────────────────┘ │ └───────────────────────────┘ │
│  ┌─────────────────┐ │ ┌───────────────────────────┐ │
│  │ 显示已完成事项   │ │ │ 数据库访问授权             │ │
│  └─────────────────┘ │ └───────────────────────────┘ │
├──────────────────────┴───────────────────────────────┤
│                            [GitHub]    [取消] [保存] │
└──────────────────────────────────────────────────────┘
```

卡片分配：

* **左列 "一般设置"**: 语言、开机启动、显示已完成事项

* **右列 "同步与集成"**: 系统提醒事项、同步间隔、数据库访问授权

#### 1.3 保存按钮逻辑

```swift
// 保存按钮
Button(action: saveSettings) {
    Text(L10n.save)
        .fontWeight(.semibold)
}
.buttonStyle(.borderedProminent)
.controlSize(.regular)

// 取消按钮 — 关闭窗口（不保存，草稿丢弃）
Button(action: { closeWindow() }) {
    Text(L10n.cancel)
}
```

`saveSettings()` 内部：

1. 写入 `isReminderSyncEnabled` → KeychainStorage
2. 写入 `syncInterval` → KeychainStorage（发通知触发 ViewModel 更新）
3. 写入 `isLaunchAtLoginEnabled` → KeychainStorage + SMAppService
4. 写入 `isCompletedSectionVisible` → KeychainStorage
5. 写入 `language` → @AppStorage（如果与初始值不同）
6. 关闭窗口

#### 1.4 Liquid Glass 视觉优化

**窗口级**：窗口背景使用 `.hiddenTitleBar` + `.ultraThinMaterial`，标题栏透明。

**卡片级**：增强 GlassCard 效果：

* 背景：`.regularMaterial` 替代 `.ultraThinMaterial`（增强磨砂感）

* 边框：`.primary.opacity(0.10)` 从 0.08 提升到 0.10

* 内阴影：添加 subtle inner highlight

**列标题**：使用小号 section header 样式：

```swift
Text("一般设置")
    .font(.subheadline)
    .fontWeight(.semibold)
    .foregroundStyle(.secondary)
    .textCase(.uppercase)
```

**分隔线**：两列之间添加垂直 Divider

### 2. AppDelegate — 窗口尺寸调整

**文件**: `Sources/BearTodoMenuBar/BearTodoMenuBarApp.swift`

```swift
// 旧: width: 420, height: 620
// 新: width: 640, height: 560
let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 640, height: 560),
    ...
)
```

以及在 `hostingView` 的 frame：

```swift
SettingsView()
    .frame(minWidth: 560, idealWidth: 640, minHeight: 480)
```

### 3. 国际化新增字符串

**文件**: `Sources/BearTodoMenuBar/Services/L10n.swift`

新增 key：

| Key                | 中文    | English            |
| ------------------ | ----- | ------------------ |
| `.save`            | 保存    | Save               |
| `.cancel`          | 取消    | Cancel             |
| `.generalSettings` | 一般设置  | General            |
| `.syncIntegration` | 同步与集成 | Sync & Integration |

### 4. 设计组件微调

**文件**: `Sources/BearTodoMenuBar/Views/DesignComponents.swift`

`GlassCard` 样式微调（可选，视最终效果决定）：

* Material 可选参数化（默认 `.ultraThinMaterial`，可传入 `.regularMaterial`）

* 边框不透明度可微调

***

## 假设与决策

1. **双列固定宽度**：640px 总宽，每列约 290px，中间间距 20px，padding 24px
2. **保存模式不阻断数据库授权**：数据库授权按钮触发 NSOpenPanel → 立即写入 bookmark，不走缓冲
3. **语言切换即时生效**：Picker 的 onChange 即时改变 UI 语言（用户体验更好），但保存时才持久化
4. **窗口关闭 = 取消**：关闭窗口不保存草稿，等价于点击取消
5. **保留现有 GlassCard 组件**：不做大改，仅微调参数

***

## 验证步骤

1. 打开设置面板 → 确认双列布局正确渲染
2. 修改各设置项 → 不关闭窗口 → 确认设置未实际生效（未写入 KeychainStorage）
3. 点击保存 → 确认所有设置生效 + 窗口关闭
4. 修改设置后点击取消/关闭窗口 → 重新打开 → 确认设置回到原始值
5. 数据库授权 → 确认立即生效（不走缓冲）
6. 语言切换 → 确认 UI 即时响应
7. 构建 `./scripts/build-app.sh` 无报错

