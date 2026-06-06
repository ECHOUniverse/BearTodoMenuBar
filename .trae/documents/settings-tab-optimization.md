# 设置界面优化：两栏布局改为 Liquid Glass 标签页切换

## 摘要

将当前 SettingsView 的左右两栏布局（通用 / 同步与集成）改为顶部居中 Liquid Glass 标签页切换 + 单栏内容区域。标签切换器使用 macOS 26 的 `GlassEffectContainer` + `.buttonStyle(.glass)` API。

***

## 当前状态分析

### 现有布局（[SettingsView.swift](file:///Volumes/WD-1T/00_Workspace/00_Active/CodeProject/Bear_Todo_Menubar/Sources/BearTodoMenuBar/Views/SettingsView.swift)）

```
┌──────────────────────────────────────────────┐
│  标题 + 描述                                  │
├───────────────────────┬──────────────────────┤
│  一般设置              │  同步与集成            │
│  ├─ 语言选择           │  ├─ 系统提醒事项        │
│  ├─ 开机启动           │  ├─ 同步间隔            │
│  ├─ 显示已完成事项      │  ├─ 数据库访问授权      │
├───────────────────────┴──────────────────────┤
│  GitHub Icon    [取消] [保存]                 │
└──────────────────────────────────────────────┘
```

* 两栏使用 `HStack(alignment: .top, spacing: 20)` + `Rectangle` 分隔线

* 左栏 sectionHeader: `L10n.generalSettings`（"一般设置" / "General"）

* 右栏 sectionHeader: `L10n.syncIntegration`（"同步与集成" / "Sync & Integration"）

* 每栏内用 `GlassCard` 包裹各组设置项

* 底部有 GitHub 链接 + 取消/保存按钮

* `staggeredEntrance` 动画参数为 (0, 1, 2, 3)

### 目标布局

```
┌──────────────────────────────────────────────┐
│  标题 + 描述                                  │
│                                              │
│          ┌──────────┬──────────┐             │
│          │  一般设置  │ 同步与集成 │             │
│          └──────────┴──────────┘             │
│          (Liquid Glass 标签页切换器)           │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │  当前选中标签页的内容（GlassCard 列表）    │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  GitHub Icon                  [取消] [保存]   │
└──────────────────────────────────────────────┘
```

***

## 修改计划

### 文件变更清单

| 文件                                                     | 操作   | 说明                             |
| ------------------------------------------------------ | ---- | ------------------------------ |
| `Sources/BearTodoMenuBar/Views/SettingsView.swift`     | 编辑   | 主要修改：两栏改标签页                    |
| `Sources/BearTodoMenuBar/Views/DesignComponents.swift` | 可能编辑 | 如需提取 LiquidGlassTabSwitcher 组件 |
| `Sources/BearTodoMenuBar/Services/L10n.swift`          | 不修改  | 所需 key 已存在                     |

### 1. SettingsView\.swift — 核心重构

#### 1.1 新增 Tab 枚举

```swift
private enum SettingsTab: String, CaseIterable {
    case general
    case sync

    var title: String {
        switch self {
        case .general: return L10n.generalSettings
        case .sync: return L10n.syncIntegration
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .sync: return "arrow.triangle.2.circlepath"
        }
    }
}
```

#### 1.2 新增状态变量

```swift
@State private var selectedTab: SettingsTab = .general
@Namespace private var tabNamespace
```

#### 1.3 替换两栏 HStack 为标签页结构

将原来的 `HStack(alignment: .top, spacing: 20) { ... }`（含左右栏和分隔线）替换为：

```swift
// Liquid Glass 标签页切换器（顶部居中）
GlassEffectContainer(spacing: 0) {
    HStack(spacing: 0) {
        ForEach(SettingsTab.allCases, id: \.self) { tab in
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    selectedTab = tab
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 13, weight: .medium))
                    Text(tab.title)
                        .font(.callout)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .buttonStyle(selectedTab == tab ? .glassProminent : .glassBorderless)
            .glassEffect(.regular.interactive(), in: Capsule())
            .glassEffectID(tab.rawValue, in: tabNamespace)
        }
    }
}
.frame(maxWidth: .infinity)
.padding(.bottom, 16)

// 内容区域
VStack(alignment: .leading, spacing: 8) {
    switch selectedTab {
    case .general:
        generalTabContent
    case .sync:
        syncTabContent
    }
}
.frame(maxWidth: .infinity)
```

#### 1.4 提取内容为计算属性

将原左栏内容提取为 `generalTabContent`：

```swift
@ViewBuilder
private var generalTabContent: some View {
    // 语言选择 GlassCard
    // 开机启动 GlassCard
    // 显示已完成事项 GlassCard
}
```

将原右栏内容提取为 `syncTabContent`：

```swift
@ViewBuilder
private var syncTabContent: some View {
    // 系统提醒事项 GlassCard
    // 同步间隔 GlassCard
    // 数据库访问授权 GlassCard
}
```

#### 1.5 调整 staggeredEntrance 动画索引

原来 Header(0), 左栏(1), 分隔线/右栏(2), 底部(3)。改为：

* Header: `staggeredEntrance(0, animate: animateContent)`

* Tab 切换器: `staggeredEntrance(1, animate: animateContent)`

* 内容区（整体）: `staggeredEntrance(2, animate: animateContent)` — 内容区整体用 `Group` 包裹以支持条件过渡

* 底部按钮栏: `staggeredEntrance(3, animate: animateContent)`

#### 1.6 移除的不再需要

* `sectionHeader()` 方法（标签页本身就是标题，不再需要 section header）

* `Rectangle()` 分隔线

* 左右栏各自的 `.frame(maxWidth: .infinity)`

#### 1.7 内容过渡动画

为内容区域添加切换动画：

```swift
VStack(alignment: .leading, spacing: 8) {
    switch selectedTab {
    case .general:
        generalTabContent
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .leading)),
                removal: .opacity.combined(with: .move(edge: .trailing))
            ))
    case .sync:
        syncTabContent
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .trailing)),
                removal: .opacity.combined(with: .move(edge: .leading))
            ))
    }
}
.animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTab)
```

### 2. DesignComponents.swift — 可选提取

如果标签切换器足够通用，可提取为独立组件 `LiquidGlassTabSwitcher`。但考虑到只有两个标签且逻辑简单，**保持在 SettingsView 内联更简洁**。本次不做提取。

***

## 假设与决策

1. **使用自定义 GlassEffectContainer 而非原生 TabView**：原生 macOS TabView 的 `.automatic` 样式将分段选择器放在 toolbar 区域，不符合"顶部中间位置"的定位需求。自定义 `GlassEffectContainer` + `.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)` 可以精确控制位置和样式。

2. **遵守 Liquid Glass 设计规则**：

   * 标签切换器使用 Glass（导航层）✓

   * 内容区域不使用 Glass（内容层）✓ — `GlassCard` 使用 `.ultraThinMaterial` 而非 `.glassEffect()`

   * 同一界面不混用 Regular 和 Clear Glass ✓ — 全部使用 `.glassProminent` / `.glassBorderless`（同属 Regular 系列）

3. **两个标签分别对应原来的左右两栏**：

   * "一般设置" = 语言 + 开机启动 + 显示已完成事项

   * "同步与集成" = 系统提醒事项 + 同步间隔 + 数据库访问授权

4. **底部按钮栏保持不变**：GitHub 图标 + 取消/保存 位置和逻辑不变。

5. **窗口尺寸不变**：`minWidth: 560, idealWidth: 640, minHeight: 480`，实际高度 540 可能微调为 500 左右（单栏内容更紧凑）。

***

## 验证步骤

1. `swift build` — 编译通过
2. 运行应用 → 打开设置窗口
3. 验证：

   * 标签切换器显示在顶部居中位置

   * Liquid Glass 效果正常（选中标签 `.glassProminent`，未选中 `.glassBorderless`）

   * 点击标签切换内容，有弹簧动画过渡

   * 两个标签页的内容完整显示，无遗漏

   * 底部取消/保存按钮功能正常

   * 语言切换、开机启动、同步开关等交互正常
4. 窗口尺寸合适（无横向或纵向溢出）

