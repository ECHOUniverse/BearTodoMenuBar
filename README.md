# Bear Todo Menu Bar

[<img src="https://img.shields.io/badge/Swift-5.9-orange.svg?style=flat-square">](#)
[<img src="https://img.shields.io/badge/macOS-13.0+-blue.svg?style=flat-square">](#)
[<img src="https://img.shields.io/github/license/ECHOUniverse/BearTodoMenuBar.svg?style=flat-square">](https://github.com/ECHOUniverse/BearTodoMenuBar/blob/main/LICENSE)
[<img src="https://img.shields.io/github/v/release/ECHOUniverse/BearTodoMenuBar.svg?style=flat-square">](https://github.com/ECHOUniverse/BearTodoMenuBar/releases)
[<img src="https://github.com/ECHOUniverse/BearTodoMenuBar/actions/workflows/build.yml/badge.svg?style=flat-square">](https://github.com/ECHOUniverse/BearTodoMenuBar/actions/workflows/build.yml)

A macOS menu bar utility that automatically reads unchecked todo items from your [Bear](https://bear.app/) notes and displays them in the menu bar. Click any todo to jump directly back to the corresponding note in Bear.

> [中文文档 (Chinese) →](README_CN.md)

## Features

- Pull all notes containing unchecked checkboxes (`- [ ]`) from Bear
- Display todo items grouped by note in the menu bar
- Click a todo to open the corresponding note in Bear
- Auto-refresh by monitoring Bear database changes (requires database access authorization)
- Communicates with Bear via x-callback-url; no data ever leaves your device

## Download & Installation

### Option 1: Download from Release (Recommended)

Go to [Releases](https://github.com/ECHOUniverse/BearTodoMenuBar/releases) and download the latest `BearTodoMenuBar.zip`. Unzip it and drag the `.app` into `/Applications`.

### Option 2: Build from Source

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

After launching the app for the first time, click the menu bar icon → **Settings...** and complete the following two steps to get full functionality:

### 1. Configure API Token

1. Open the Bear app
2. Click **Help → API Token** in the menu bar
3. Copy the generated Token
4. Paste it into the **Bear API Token** field in the app and click Save

> **Note**: The Token is used by Bear for x-callback-url communication. Please keep it safe.

### 2. Authorize Database Access

To allow the app to automatically refresh the todo list after you edit Bear notes, you need to authorize access to Bear's database folder:

1. Click **Authorize Access to Bear Database** in the Settings window
2. In the file picker that appears, select Bear's **Application Data** folder (usually located at `~/Library/Group Containers/9K3BFM6K6M.net.shinyfrog.bear/Application Data`)
3. Click **Authorize Access**

Once authorized, the app will monitor database changes in real time and automatically refresh the menu bar content.

## System Requirements

| Item | Requirement |
|------|-------------|
| OS | macOS 13.0+ |
| Swift | 5.9+ |
| Dependency | [Bear](https://bear.app/) |

## Project Structure

```
.
├── Package.swift           # Swift Package Manager config
├── Sources/                # Source code
│   └── BearTodoMenuBar/
│       ├── BearTodoMenuBarApp.swift
│       ├── MenuBarController.swift
│       ├── Views/
│       ├── Services/
│       ├── Models/
│       └── Utils/
├── scripts/
│   ├── build-app.sh        # Build .app bundle
│   ├── run-local.sh        # Run locally (no install)
│   └── run.sh              # Build and install to /Applications
├── resources/              # Icons, etc.
└── README.md
```

## Technical Notes

- Uses Bear's [x-callback-url](https://bear.app/xcallbackurl/) to fetch note data
- Uses `DispatchSourceFileSystemObject` to monitor `database.sqlite` file changes for auto-refresh
- Uses Security-Scoped Bookmark to persist database directory access permissions

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
