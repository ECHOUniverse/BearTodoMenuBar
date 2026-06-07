# 语言设置改为 macOS 26 Liquid Glass 风格切换器

## 摘要

将设置面板中"一般设置"标签页下的语言选择器从标准 `Picker(.segmented)` 替换为与标签页切换器一致的 Liquid Glass 胶囊风格。

## 当前状态

**文件**: `Sources/BearTodoMenuBar/Views/SettingsView.swift` 第 218-226 行

```swift
Picker("", selection: $draftLanguage) {
    ForEach(Language.allCases, id: \.self) { lang in
        Text(lang.displayName).tag(lang)
    }
}
.pickerStyle(.segmented)
.onChange(of: draftLanguage) { lang in
    l10n.language = lang
}
```

语言选项（`L10n.swift` `Language` 枚举）：自动（跟随系统）、简体中文、English — 3 个选项，纯文字无图标。

## 参考模板

tabSwitcher 的 Liquid Glass 实现（第 140-201 行）：

- macOS 26+: `GlassEffectContainer` + `HStack` + 每个选项一个 `Button`，选中项 `.glassEffect(.regular.interactive(), in: Capsule())` + `.glassEffectID`
- macOS 26 以下: 回退到 `Picker(.segmented)`
- 外层 `.ultraThinMaterial` Capsule 背景 + 描边

## 修改方案

### 唯一修改文件

`Sources/BearTodoMenuBar/Views/SettingsView.swift`

### 修改点：语言选择器 (`generalTabContent` 内第一个 `GlassCard`)

将第 218-226 行的 `Picker` 替换为与 tabSwitcher 风格一致的 Liquid Glass 胶囊切换器。

**实现细节**:

1. 为语言选项添加 `@Namespace private var languageNamespace`（新增属性，约第 37 行 `tabNamespace` 旁边）
2. 新建 `languageSwitcher` 计算属性（`@ViewBuilder`），结构与 `tabSwitcher` 一致：
   - macOS 26+: `GlassEffectContainer` + `HStack` + `ForEach(Language.allCases)` 渲染 `Button`
   - 选中项：`.glassEffect(.regular.interactive(), in: Capsule())` + `.glassEffectID(lang.rawValue, in: languageNamespace)`
   - 未选中项：仅 `.glassEffectID(lang.rawValue, in: languageNamespace)`
   - 外层：`.padding(4)` + Capsule `.ultraThinMaterial` 背景 + 描边
   - 点击时：`withAnimation` 更新 `draftLanguage` + 调用 `l10n.language = lang`
   - macOS 26 以下: 保持现有 `Picker(.segmented)` 作为回退
3. 原 `Picker` 占位处调用 `languageSwitcher`

**注意**：tabSwitcher 有图标（`tab.icon`），语言切换器只需文字（`lang.displayName`），按钮内仅 `Text`，无需 `Image`。

## 验证

1. `swift build` 编译通过
2. macOS 26 上运行，打开设置面板 → 一般设置
3. 语言切换器显示为 Liquid Glass 胶囊风格，与标签页切换器视觉一致
4. 点击各选项切换流畅，选中高亮动画正常
5. 语言即时切换生效
6. macOS 26 以下系统回退到标准 segmented Picker
