# Bear Todo Menu Bar

[<img src="https://img.shields.io/badge/Swift-5.9-orange.svg?style=flat-square">](#)
[<img src="https://img.shields.io/badge/macOS-13.0+-blue.svg?style=flat-square">](#)
[<img src="https://img.shields.io/github/license/ECHOUniverse/BearTodoMenuBar.svg?style=flat-square">](https://github.com/ECHOUniverse/BearTodoMenuBar/blob/main/LICENSE)
[<img src="https://img.shields.io/github/v/release/ECHOUniverse/BearTodoMenuBar.svg?style=flat-square">](https://github.com/ECHOUniverse/BearTodoMenuBar/releases)
[<img src="https://github.com/ECHOUniverse/BearTodoMenuBar/actions/workflows/build.yml/badge.svg?style=flat-square">](https://github.com/ECHOUniverse/BearTodoMenuBar/actions/workflows/build.yml)

一个 macOS 菜单栏小工具，自动读取 [Bear](https://bear.app/) 笔记中未勾选的待办事项，并展示在菜单栏中。点击即可在 Bear 中标记完成——使用红色圆圈指示器，风格参考系统提醒事项。

> [English Documentation →](README.md)

## 功能

- 从 Bear 中拉取所有包含复选框（`- [ ]` 和 `- [x]`）的笔记
- 在菜单栏中按笔记分组展示待办和已完成事项
- **一键标记完成/未完成** — 点击红色/绿色圆圈直接在 Bear 中切换 `- [ ]` / `- [x]`
- **双向提醒事项同步** — Bear 待办自动同步到系统提醒事项的专用日历，基于最后修改时间戳解决冲突
- **系统提醒事项展示** — 按今天 / 明天 / 计划 / 未安排分组显示未完成的系统提醒事项
- **点击打开** — 打开对应的 Bear 笔记或系统提醒事项
- **暂停/恢复同步** — 一键开关，临时停止自动刷新
- **可配置同步间隔** — 防抖延迟从即时到 7 秒
- **开机启动** — 可选登录时自动启动
- **多语言支持** — 英文和简体中文，随系统语言自动切换
- 实时监控 Bear 数据库变化自动刷新（需授权数据库访问）

## 下载与安装

### 方式一：Homebrew（推荐）

```bash
brew tap ECHOUniverse/bear-tap
brew install --cask bear-todo-menu-bar
```

升级：

```bash
brew update && brew upgrade --cask bear-todo-menu-bar
```

### 方式二：从 Release 下载

前往 [Releases](https://github.com/ECHOUniverse/BearTodoMenuBar/releases) 下载最新版本的 `BearTodoMenuBar.dmg` 或 `BearTodoMenuBar.zip`。打开 DMG 将 `.app` 拖入 `/Applications`，或解压 zip 后同样操作即可。

### 方式三：从源码构建

```bash
# 1. 克隆项目
git clone https://github.com/ECHOUniverse/BearTodoMenuBar.git
cd BearTodoMenuBar

# 2. 构建
swift build

# 3. 打包成 .app
./scripts/build-app.sh

# 4. 本地运行（不安装到 /Applications）
./scripts/run-local.sh

# 5. 或安装到系统
./scripts/run.sh
```

## 首次配置

应用第一次启动后，点击菜单栏图标 →「设置...」，授权数据库访问即可启用自动刷新：

### 授权数据库访问

1. 在设置窗口中点击「授权访问」
2. 在弹出的文件选择器中，选中 Bear 的 Application Data 文件夹（路径通常为 `~/Library/Group Containers/9K3BFM6K6M.net.shinyfrog.bear/Application Data`）
3. 点击「授权访问」

可选启用「提醒事项同步」，将待办自动镜像到系统提醒事项。授权成功后，应用会实时监控数据库变化并自动刷新菜单栏内容。

## 系统要求

| 项目 | 要求 |
|------|------|
| 操作系统 | macOS 13.0+ |
| Swift | 5.9+ |
| 依赖应用 | [Bear](https://bear.app/) |

## 项目结构

```
.
├── Package.swift
├── Sources/BearTodoMenuBar/
│   ├── BearTodoMenuBarApp.swift     # @main，AppDelegate，设置窗口
│   ├── Info.plist
│   ├── Models/TodoItem.swift        # 数据模型
│   ├── Services/
│   │   ├── BearService.swift        # bearcli 封装
│   │   ├── BearFileWatcher.swift    # 数据库变化监控
│   │   ├── ReminderService.swift    # EventKit 双向同步
│   │   ├── TodoParser.swift         # 复选框语法解析
│   │   └── L10n.swift               # 国际化（中文/英文）
│   ├── Utils/
│   │   ├── KeychainStorage.swift    # 持久化配置存储
│   │   ├── BearBookmarkManager.swift # Security-Scoped Bookmark
│   │   ├── MenuBarViewModel.swift   # ViewModel：刷新与同步编排
│   │   └── Debounce.swift           # 防抖工具
│   └── Views/
│       ├── MenuBarContent.swift     # 菜单栏布局
│       ├── BearTodoMenuItemView.swift  # Bear 待办行
│       ├── ReminderMenuItemView.swift  # 系统提醒行
│       ├── DesignComponents.swift   # 共享 UI 组件
│       └── SettingsView.swift       # 设置面板
├── scripts/                         # 构建、运行、安装脚本
├── resources/                       # 应用图标
└── README.md
```

## 技术说明

- 使用 Bear 的 [bearcli](https://bear.app/) 获取和编辑笔记数据
- 使用 EventKit 将 Bear 待办双向同步到系统提醒事项的专用日历，基于最后修改时间戳解决冲突
- 使用 `DispatchSourceFileSystemObject` 监听 `database.sqlite` 文件变化实现实时自动刷新
- 使用 Security-Scoped Bookmark 持久化数据库目录访问权限
- 使用 SwiftUI spring 动画和交错入场效果美化菜单栏界面

## 问题反馈

遇到问题？请通过 [GitHub Issues](https://github.com/ECHOUniverse/BearTodoMenuBar/issues) 提交反馈，并尽量提供以下信息：

- macOS 版本
- Bear 版本
- 应用版本号
- 复现步骤

## 贡献

欢迎提交 Pull Request！在提交前请确保：

1. 代码可以通过 `swift build` 编译
2. 遵循现有的代码风格（可通过 `swift-format` 检查）
3. 如有功能变更，请同步更新 README

## License

[MIT](LICENSE)
