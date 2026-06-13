# BearTodoMenuBar 2.7 — 重构任务清单

## 阶段 0: 项目骨架重建

### 任务 0.1: 清理旧代码 + 创建新目录结构
- [ ] 备份旧 `Sources/` 到 `Sources.bak/`
- [ ] 创建新模块目录: `App/`, `Models/`, `Services/`, `Persistence/`, `ViewModel/`, `Views/MenuBar/`, `Views/Settings/`, `Views/Design/`
- [ ] 更新 `Package.swift`:
  - `swift-tools-version: 6.2`
  - `platforms: [.macOS(.v26)]`
  - `swiftSettings: [.swiftLanguageMode(.v6), .enableUpcomingFeature(.StrictConcurrency)]`
- [ ] 更新 `Info.plist`: `LSMinimumSystemVersion` → `26.0`
- **验证**: `swift build` 通过（空可执行目标）

### 任务 0.2: 数据模型
- [ ] `Models/TodoItem.swift`:
  - `TodoLine`: `Sendable` struct（text, lineNumber, isCompleted）
  - `TodoItem`: `Sendable` struct, Identifiable（id=UUID, text, noteId, noteTitle, lineNumber, isCompleted）
  - `NoteTodos`: `Sendable` struct, Identifiable（id, title, todos, modified）
  - `SyncResult`: `Sendable` struct（completedKeys: Set<String>, uncompletedKeys: Set<String>）
  - `ReminderDueCategory`: `Sendable` enum（overdue, today, tomorrow, scheduled, unscheduled）
  - `SystemReminderItem`: `Sendable` struct, Identifiable（id, title, dueCategory, reminderIdentifier, dueDate）
- [ ] `Models/Settings.swift`:
  - `Language`: `Sendable` enum（auto, simplifiedChinese, english）
  - `BearMonitorMethod`: `Sendable` enum（fileWatcher, polling）
- **验证**: `swift build` 通过

## 阶段 1: 核心服务层

### 任务 1.1: TodoParser
- [ ] `Services/TodoParser.swift`:
  - `static func parseAllTodos(from markdown: String) -> [TodoLine]`
  - 正则匹配 `- [ ] text` 和 `- [x] text`
  - 纯函数，无外部依赖
- **验证**: `swift build` 通过

### 任务 1.2: BearService（async/await）
- [ ] `Services/BearService.swift`:
  - `actor BearService` 或 `@MainActor class`
  - `func fetchAllTodos() async throws -> [NoteTodos]`: 调用 bearcli search, JSON 解析, TodoParser
  - `func completeTodo(_ todo: TodoItem) async throws`: bearcli edit --find --replace
  - `func uncompleteTodo(_ todo: TodoItem) async throws`
  - `func openNote(id: String)`: bearcli open
  - 内部用 `withCheckedThrowingContinuation` 包装 `Process`
- **验证**: `swift build` 通过

### 任务 1.3: ReminderService（async/await）
- [ ] `Services/ReminderService.swift`:
  - `@MainActor class ReminderService`
  - `func requestAccess() async -> Bool`: EventKit 权限请求
  - `func sync(todos: [TodoItem], noteModDates: [String: Date?]) async -> SyncResult`: 双向同步逻辑
  - `func fetchUncompletedReminders() async -> [SystemReminderItem]`: 获取系统提醒事项
  - `func toggleReminderCompletion(identifier: String) async throws`
  - `func openReminderInApp(identifier: String)`
  - 内部: `@preconcurrency import EventKit` + `EKEventStore` 实例管理
  - 双向冲突解决: 时间戳比较 + reminderIsNewer
- **验证**: `swift build` 通过

### 任务 1.4: MonitorService（文件监控 + 轮询）
- [ ] `Services/MonitorService.swift`:
  - `actor MonitorService`: 统一文件监控和轮询
  - `func start(method: BearMonitorMethod)`: 启动监控
  - `func stop()`: 停止监控
  - `var onChange: (@Sendable () -> Void)?`: 变更回调
  - 内部: DispatchSource 文件监控 + Timer 轮询
  - BearBookmarkManager 安全作用域管理
- **验证**: `swift build` 通过

## 阶段 2: 持久化 & ViewModel

### 任务 2.1: KeychainStorage（@Observable）
- [ ] `Persistence/KeychainStorage.swift`:
  - `@Observable @MainActor class KeychainStorage`
  - 计算属性: `isReminderSyncEnabled`, `isLaunchAtLoginEnabled`, `isCompletedSectionVisible`, `syncInterval`, `bearMonitorMethod`, `language`
  - UserDefaults + Keychain 双层存储
  - 变更通知: 属性 setter 中发 Notification
- **验证**: `swift build` 通过

### 任务 2.2: MenuBarViewModel（@Observable @MainActor）
- [ ] `ViewModel/MenuBarViewModel.swift`:
  - `@Observable @MainActor class MenuBarViewModel`
  - `var noteTodos: [NoteTodos]`, `var completedNoteTodos: [NoteTodos]`
  - `var systemReminders: [SystemReminderItem]`
  - `var lastRefreshDate: Date?`, `var isRefreshing: Bool`, `var isPaused: Bool`
  - `func refresh() async`: BearService + ReminderService 联动
  - `func togglePause()`, `func completeTodo(_:)`, `func uncompleteTodo(_:)`
  - `func openNote(_:)`, `func openNoteById(_:)`, `func openReminder(_:)`
  - MonitorService 集成，debounce 逻辑
  - NSWorkspace 通知监听（前后台切换）
- **验证**: `swift build` 通过

## 阶段 3: 菜单栏 UI（Liquid Glass）

### 任务 3.1: DesignComponents
- [ ] `Views/Design/GlassCard.swift`: Liquid Glass 卡片组件
- [ ] `Views/Design/StatusPill.swift`: 状态指示器（已授权/未授权/待定）
- [ ] `Views/Design/StaggeredEntrance.swift`: 交错入场动画 modifier
- [ ] `Views/Design/LiquidGlassCircleButton.swift`: 圆形玻璃按钮
- [ ] 使用 `.ultraThinMaterial`, `RoundedRectangle`, `.glassEffect()` 等
- **验证**: `swift build` 通过

### 任务 3.2: 菜单栏行视图
- [ ] `Views/MenuBar/BearTodoRow.swift`:
  - 独立 `View` struct
  - 输入: `let text: String, let isCompleted: Bool, let onToggle: () -> Void, let onOpenNote: () -> Void`
  - `@State private var isAnimating = false`
  - circle/checkmark 图标 + 文字 + spring 动画
- [ ] `Views/MenuBar/ReminderRow.swift`:
  - 独立 `View` struct
  - 输入: `let title: String, let dueDate: Date?, let onToggleComplete: () -> Void, let onOpenReminder: () -> Void`
  - circle 图标 + 标题 + 日期 + 动画
- **验证**: `swift build` 通过

### 任务 3.3: MenuBarContent
- [ ] `Views/MenuBar/MenuBarContent.swift`:
  - 独立 `View` struct
  - 输入: `let viewModel: MenuBarViewModel`
  - ScrollView + VStack 布局
  - Header: 刷新状态/按钮 + 暂停/恢复
  - Section Cards: Bear 待办、已完成、系统提醒
  - Footer: 设置 + 退出按钮（LiquidGlassCircleButton）
  - `.menuBarExtraStyle(.window)`, 320pt 固定宽度
  - 使用 GlassCard 包装每个 section
- **验证**: `swift build` 通过

### 任务 3.4: App 入口
- [ ] `App/BearTodoMenuBarApp.swift`:
  - `@main struct BearTodoMenuBarApp: App`
  - `MenuBarExtra("Bear Todo", systemImage: "checklist")`
  - `@State private var viewModel = MenuBarViewModel()`
  - Swift 5 language mode 下 `@State` 初始化正常
  - 或使用 Swift 6 语言模式 + 正确 @State init
- [ ] `App/AppDelegate.swift`:
  - `@MainActor class AppDelegate: NSObject, NSApplicationDelegate`
  - 设置窗口管理: `openSettings`, `AutoSizingHostingView`（保留原实现）
  - `applicationDidFinishLaunching`: 激活策略、权限请求
- **验证**: `swift build` 通过

## 阶段 4: 设置 UI（Liquid Glass）

### 任务 4.1: SettingsView 主框架
- [ ] `Views/Settings/SettingsView.swift`:
  - 独立 `View` struct
  - `@State private var selectedTab: SettingsTab`
  - `@Environment(KeychainStorage.self) var storage`
  - Header + GlassEffectContainer Tab 切换器 + 内容区 + Save/Cancel
  - Liquid Glass 设计：GlassEffectContainer + Capsule 背景
  - 三个 Tab 交叉淡入淡出切换
- **验证**: `swift build` 通过

### 任务 4.2: 设置 Tab 页面
- [ ] `Views/Settings/GeneralTab.swift`: 语言切换（GlassEffectContainer）, 启动登录, 显示已完成
- [ ] `Views/Settings/SyncTab.swift`: 提醒事项同步, 同步间隔 Slider, Bear 监控方式（GlassEffectContainer）
- [ ] `Views/Settings/AboutTab.swift`: 应用图标, 版本号, 检查更新
- **验证**: `swift build` 通过

## 阶段 5: 本地化 & 集成验证

### 任务 5.1: 本地化
- [ ] `Services/L10n.swift`:
  - `@Observable class L10n`: 中/英字符串
  - `var language: Language` 属性驱动 UI 刷新
  - 所有用户可见字符串（约 60 个 key）
- **验证**: `swift build` 通过

### 任务 5.2: 最终集成
- [ ] 删除 `Sources.bak/`
- [ ] `swift build -c release` 零错误零警告
- [ ] `./scripts/run.sh` 运行验证
- [ ] 菜单栏图标显示正常
- [ ] 点击设置正常打开面板
- [ ] 设置面板: Tab 切换、语言切换、同步配置正常工作
- [ ] 如有 GitHub Actions, 更新 workflow（Node 24, macOS 27）

### 检查点

| 检查点 | 位置 | 验证内容 |
|---|---|---|
| CP-1 | 任务 0.2 后 | 数据模型可编译 |
| CP-2 | 任务 1.3 后 | 核心服务层完整 |
| CP-3 | 任务 2.2 后 | ViewModel 完整 |
| CP-4 | 任务 3.4 后 | 菜单栏可运行 |
| CP-5 | 任务 4.2 后 | 设置面板可运行 |
| CP-6 | 任务 5.2 后 | 全功能集成验证 |
