# 设置界面标签页切换自适应优化

## 摘要

当用户在设置面板切换标签页（一般设置 ↔ 同步与集成）时，仅内容区域（选项部分）执行切换动画，标题和标签页切换器保持静止不动。

## 当前状态分析

**文件**: `Sources/BearTodoMenuBar/Views/SettingsView.swift`

当前布局结构：

```
VStack(spacing: 0)
├── Header VStack（标题 + 副标题）          ← .staggeredEntrance(0)
├── tabSwitcher                              ← .staggeredEntrance(1)
├── ZStack（内容区域，条件渲染）             ← .staggeredEntrance(2)
│   ├── if general: generalTabContent        ← 带 .transition(.asymmetric(...))
│   └── if sync: syncTabContent              ← 带 .transition(.asymmetric(...))
│   .animation(.spring(...), value: selectedTab)  ← 关键动画声明
└── Bottom HStack（GitHub + Cancel/Save）    ← .staggeredEntrance(3)
```

**问题根因**：

第 103 行的 `.animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTab)` 绑定在内容区域的 ZStack 上。当 `selectedTab` 变化时，`body` 整体重计算。由于 VStack 内部子视图的高度变化（general 和 sync 标签页内容高度不同），SwiftUI 的布局系统可能会将动画传播到兄弟视图（header、tabSwitcher），导致标题和标签页切换器在垂直方向上产生位移动画。

`staggeredEntrance` 修饰符使用 `.animation(value: animate)` 绑定，`animateContent` 仅在 `onAppear` 时设为 `true` 后不再变化，因此不是重复动画的原因。

## 修改方案

### 唯一的修改文件

`Sources/BearTodoMenuBar/Views/SettingsView.swift`

### 修改内容

在 Header VStack 和 tabSwitcher 上添加 `.animation(nil, value: selectedTab)`，显式禁止它们响应 `selectedTab` 变化时的任何隐式动画。

**修改点 1 — Header VStack（约第 62-74 行）**：

在 Header 的 `VStack` 上追加 `.animation(nil, value: selectedTab)`：

```swift
VStack(alignment: .leading, spacing: 4) {
    Text(L10n.settings)
        .font(.title)
        .fontWeight(.bold)
    Text(L10n.settingsDescription)
        .font(.subheadline)
        .foregroundStyle(.secondary)
}
.frame(maxWidth: .infinity, alignment: .leading)
.padding(.bottom, 16)
.staggeredEntrance(0, animate: animateContent)
.animation(nil, value: selectedTab)  // 新增：禁止标签页切换时 Header 动画
```

**修改点 2 — tabSwitcher（约第 76-79 行）**：

在 tabSwitcher 上追加 `.animation(nil, value: selectedTab)`：

```swift
tabSwitcher
    .padding(.bottom, 16)
    .staggeredEntrance(1, animate: animateContent)
    .animation(nil, value: selectedTab)  // 新增：禁止标签页切换时 tabSwitcher 位置动画
```

> **注意**：`tabSwitcher` 内部的胶囊选中效果使用 `withAnimation(.spring(...))` 包裹 `selectedTab = tab`，这是显式动画调用，不受 `.animation(nil, value:)` 影响。选中状态的视觉变化正常工作。

### 逻辑说明

- `.animation(nil, value: selectedTab)` 的含义是：当 `selectedTab` 变化时，禁用此视图及其子视图的隐式动画。
- Header 不依赖 `selectedTab`，添加此修饰符确保即使 VStack 整体布局变化，Header 也保持静止。
- tabSwitcher 依赖 `selectedTab`（选中高亮），但内部的选中动画是显式 `withAnimation` 调用，不受外层 `.animation(nil, value:)` 影响。
- 内容区域 ZStack 的 `.animation(.spring(...), value: selectedTab)` 保持不变，确保标签页内容切换有平滑的滑入/滑出效果。

## 验证方式

1. `swift build` 编译通过
2. 运行 App，打开设置面板
3. 在"一般设置"和"同步与集成"标签页之间反复切换
4. 预期行为：
   - 标题"设置"和副标题文字保持静止，无位移/闪烁
   - 标签页切换器的位置保持静止（仅选中胶囊的玻璃效果动画变化）
   - 下方选项区域有平滑的左右滑动切换动画
