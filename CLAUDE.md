# BearTodoMenuBar

macOS menu bar app that syncs Bear note checkboxes with system Reminders.

## Build & Run

```bash
# Build release .app bundle (auto-creates code signing cert)
./scripts/build-app.sh

# Build, install to /Applications, and launch
./scripts/run.sh

# Build and run from build directory (no install)
./scripts/run-local.sh

# Debug build only
swift build
```

## Project Architecture

```
Sources/BearTodoMenuBar/
├── BearTodoMenuBarApp.swift   # @main, AppDelegate, settings window
├── MenuBarController.swift    # Status item, menu building, refresh orchestration
├── Models/TodoItem.swift      # TodoItem, NoteTodos, SystemReminderItem
├── Services/
│   ├── BearService.swift      # Bear API: fetch/open notes via x-callback-url
│   ├── BearFileWatcher.swift  # FSEvents watcher for Bear database changes
│   ├── ReminderService.swift  # EventKit: sync todos with system Reminders
│   ├── TodoParser.swift       # Parse `- [ ]` / `- [x]` syntax from note text
│   ├── XCallbackClient.swift  # x-callback-url client for Bear interop
│   └── L10n.swift             # i18n strings (Chinese/English)
├── Utils/
│   ├── KeychainStorage.swift  # Keychain persistence for flags & token
│   ├── BearBookmarkManager.swift  # Security-scoped bookmark for Bear DB
│   └── Debounce.swift         # Debounce utility for event coalescing
└── Views/SettingsView.swift   # Settings panel UI
```

## Coding Conventions

- **SwiftUI + AppKit hybrid**: SwiftUI `@main` entry, AppKit `NSMenu` for menu bar
- **No async/await for Bear API**: uses closure-based callbacks via x-callback-url
- **Code signing**: use persistent self-signed cert `BearTodo Developer`. Never ad-hoc sign (resets TCC permissions).
- **i18n**: all user-facing strings in `L10n.swift` (Chinese + English)
- **Keychain over UserDefaults**: persistence that survives reinstall goes in `KeychainStorage` (token, sync flags, launch-at-login)
- **Menu rebuilds on every open** via `NSMenuDelegate.menuWillOpen` for freshness
- **Debounce + app-switch**: leaving Bear/Reminders cancels debounce and refreshes immediately
- **No mock data in production code**. Mock only for local debug via unified entry. Must be in `.gitignore`.
- **Prefer Edit over Write** for existing files. Write only for new files or full rewrites.
- **No comments by default**. Add only when the WHY is non-obvious.

## Development Workflow

1. **Analysis layer** — UI changes (text, icons, colors) go direct to execution. Major refactors/multi-tasks go through planning.
2. **Planning layer** — orchestrate flow and produce/update global flowcharts.
3. **Task layer** — maintain task_plan.md / progress.md / findings.md. Update todo after each completed task.
4. **Execution layer** — four-step loop: propose → user confirms → apply → archive.
5. **Granularity** — decompose tasks into `<files>` / `<action>` / `<verify>` before starting.
6. **Sub-agents** — complex problems (more than 1 file, needs review/research/parallel analysis) must use sub-agents to keep main context clean.
7. **Self-evolution** — immediately save corrections to lessons.md. Review lessons.md before starting new tasks.

## Core Behaviors

1. **First principles** — start from raw requirements. Stop when motivation is unclear. Correct non-optimal paths immediately.
2. **Surface assumptions** — state assumptions about requirements/architecture before implementing non-trivial work.
3. **Manage confusion** — when encountering inconsistencies, stop and clarify. Do not silently guess.
4. **Push back on bad approaches** — explain concrete costs, propose alternatives, accept overrides when fully informed.
5. **Enforce simplicity** — fewer lines, fewer abstractions. Three similar lines beat a premature abstraction.
6. **Maintain scope discipline** — touch only what the task requires. No unsolicited refactoring.
7. **Verify, don't assume** — a task is not complete until verified (build, tests, runtime behavior).
8. **Let it crash** — surface problems early. No degraded fallbacks, patches, or non-rigid post-processing.

## Output Rules

- **Conclusion first** — give the answer and fix directly. No background re-reading.
- **Table format** — use Markdown tables for reviews, comparisons, multi-item tasks.
- **Chinese** — always communicate in Chinese.
- **Strict closure** — end each response by naming the skill used.
- **No permission-seeking for task execution** — ask about requirements and intent, not whether to execute.

## Skill Discovery

```
Vague idea/need refinement?        → idea-refine
New project/feature/change?        → spec-driven-development
Have a spec, need tasks?           → planning-and-task-breakdown
Implementing code?                 → incremental-implementation
  ├── UI work?                     → frontend-ui-engineering
  ├── API work?                    → api-and-interface-design
  └── Need doc-verified code?      → source-driven-development
Writing/running tests?             → test-driven-development
Something broke?                   → debugging-and-error-recovery
Reviewing code?                    → code-review-and-quality
  ├── Security concerns?           → security-and-hardening
  └── Performance concerns?        → performance-optimization
Committing/branching?              → git-workflow-and-versioning
CI/CD pipeline work?               → ci-cd-and-automation
Writing docs/ADRs?                 → documentation-and-adrs
Deploying/launching?               → shipping-and-launch
```

## Available MCP / Tools

- context-7-mcp: fetch current docs for libraries, frameworks, SDKs
- github-mcp: GitHub operations
