# Bear Todo Menu Bar

[<img src="https://img.shields.io/badge/Swift-5.9-orange.svg?style=flat-square">](#)
[<img src="https://img.shields.io/badge/macOS-13.0+-blue.svg?style=flat-square">](#)
[<img src="https://img.shields.io/github/license/ECHOUniverse/BearTodoMenuBar.svg?style=flat-square">](https://github.com/ECHOUniverse/BearTodoMenuBar/blob/main/LICENSE)
[<img src="https://img.shields.io/github/v/release/ECHOUniverse/BearTodoMenuBar.svg?style=flat-square">](https://github.com/ECHOUniverse/BearTodoMenuBar/releases)
[<img src="https://github.com/ECHOUniverse/BearTodoMenuBar/actions/workflows/build.yml/badge.svg?style=flat-square">](https://github.com/ECHOUniverse/BearTodoMenuBar/actions/workflows/build.yml)

A macOS menu bar utility that automatically reads unchecked todo items from your [Bear](https://bear.app/) notes and displays them in the menu bar. Click any todo to mark it complete in Bear — styled like system Reminders with red circle indicators.

> [中文文档 (Chinese) →](README_CN.md)

## Features

- Pull all notes containing checkboxes (`- [ ]` and `- [x]`) from Bear
- Display pending and completed todos grouped by note in the menu bar
- **Mark todos complete/incomplete** — click a red/green circle to toggle `- [ ]` / `- [x]` directly in Bear
- **Bidirectional Reminders sync** — Bear todos automatically sync to a dedicated calendar in system Reminders, with conflict resolution based on last-modified timestamps
- **System Reminders display** — show uncompleted system reminders grouped by Today / Tomorrow / Scheduled / Unscheduled
- **Click to open** — open the corresponding Bear note or Reminders.app item
- **Pause / Resume sync** — toggle to temporarily stop automatic refresh
- **Configurable sync interval** — set debounce delay from immediate to 7 seconds
- **Launch at login** — optionally start automatically on system login
- **i18n support** — English and Simplified Chinese, auto-detected from system locale
- Auto-refresh by monitoring Bear database changes in real time (requires database access authorization)

## Download & Installation

### Option 1: Homebrew (Recommended)

```bash
brew tap ECHOUniverse/bear-tap
brew install --cask bear-todo-menu-bar
```

To upgrade:

```bash
brew update && brew upgrade --cask bear-todo-menu-bar
```

### Option 2: Download from Release

Go to [Releases](https://github.com/ECHOUniverse/BearTodoMenuBar/releases) and download the latest `BearTodoMenuBar.dmg` or `BearTodoMenuBar.zip`. Open the DMG and drag the `.app` into `/Applications`, or unzip the zip and do the same.

### Option 3: Build from Source

```bash
# 1. Clone the repo
git clone https://github.com/ECHOUniverse/BearTodoMenuBar.git
cd BearTodoMenuBar

# 2. Build
swift build

# 3. Package into .app
./scripts/build-app.sh

# 4. Run locally (without installing to /Applications)
./scripts/run-local.sh

# 5. Or install system-wide
./scripts/run.sh
```

## First-Time Setup

After launching the app for the first time, click the menu bar icon → **Settings...** and authorize database access to enable auto-refresh:

### Authorize Database Access

1. Click **Authorize Access** in the Settings window
2. In the file picker, select Bear's **Application Data** folder (usually `~/Library/Group Containers/9K3BFM6K6M.net.shinyfrog.bear/Application Data`)
3. Click **Authorize Access**

Optionally, enable **Reminders Sync** to automatically mirror todos in system Reminders. Once authorized, the app will monitor database changes in real time and automatically refresh the menu bar content.

## System Requirements

| Item | Requirement |
|------|-------------|
| OS | macOS 13.0+ |
| Swift | 5.9+ |
| Dependency | [Bear](https://bear.app/) |

## Project Structure

```
.
├── Package.swift
├── Sources/BearTodoMenuBar/
│   ├── BearTodoMenuBarApp.swift     # @main, AppDelegate, settings window
│   ├── Info.plist
│   ├── Models/TodoItem.swift        # Data models
│   ├── Services/
│   │   ├── BearService.swift        # bearcli wrapper
│   │   ├── BearFileWatcher.swift    # Database change monitoring
│   │   ├── ReminderService.swift    # EventKit bidirectional sync
│   │   ├── TodoParser.swift         # Checkbox syntax parser
│   │   └── L10n.swift               # i18n (Chinese/English)
│   ├── Utils/
│   │   ├── KeychainStorage.swift    # Persistent settings
│   │   ├── BearBookmarkManager.swift # Security-scoped bookmark
│   │   ├── MenuBarViewModel.swift   # ViewModel: refresh & sync orchestration
│   │   └── Debounce.swift           # Debounce utility
│   └── Views/
│       ├── MenuBarContent.swift     # Menu bar layout
│       ├── BearTodoMenuItemView.swift  # Bear todo row
│       ├── ReminderMenuItemView.swift  # Reminder row
│       ├── DesignComponents.swift   # Shared UI components
│       └── SettingsView.swift       # Settings panel
├── scripts/                         # Build, run, install scripts
├── resources/                       # App icon
└── README.md
```

## Technical Notes

- Uses Bear's [bearcli](https://bear.app/) to fetch and edit note data
- Uses EventKit to sync Bear todos bidirectionally with a dedicated calendar in system Reminders, with conflict resolution based on last-modified timestamps
- Uses `DispatchSourceFileSystemObject` to monitor `database.sqlite` file changes for real-time auto-refresh
- Uses Security-Scoped Bookmark to persist database directory access permissions
- Uses SwiftUI spring animations and staggered entrance effects for menu bar UI

## Issue Reporting

Encountered a problem? Please submit feedback via [GitHub Issues](https://github.com/ECHOUniverse/BearTodoMenuBar/issues) and provide as much of the following information as possible:

- macOS version
- Bear version
- App version number
- Steps to reproduce

## Contributing

Pull requests are welcome! Before submitting, please make sure:

1. The code compiles with `swift build`
2. You follow the existing code style (check with `swift-format`)
3. You update the README if the functionality changes

## License

[MIT](LICENSE)
