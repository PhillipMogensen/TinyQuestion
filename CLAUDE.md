# CLAUDE.md — TinyQuestion

A native macOS overlay app for asking quick questions to a local Ollama instance. Single-window, summoned by a global hotkey, ephemeral by design.

The original brainstorming session and locked design decisions live at `~/.claude/plans/i-have-an-idea-sunny-deer.md`. **Read that first** if you're picking this up cold — it captures the *why* behind every choice and the explicit out-of-scope list.

## Quick commands

```sh
# Regenerate the Xcode project (always do this after adding/removing/renaming source files)
xcodegen generate

# Build (Debug)
xcodebuild -project TinyQuestion.xcodeproj -scheme TinyQuestion -configuration Debug -derivedDataPath build build

# Launch the built app
open build/Build/Products/Debug/TinyQuestion.app

# Kill any running instance (do this before relaunching to pick up a rebuild)
pkill -f TinyQuestion

# Quick rebuild + relaunch
pkill -f TinyQuestion 2>/dev/null; xcodegen generate && \
  xcodebuild -project TinyQuestion.xcodeproj -scheme TinyQuestion -configuration Debug -derivedDataPath build build 2>&1 | tail -5 && \
  open build/Build/Products/Debug/TinyQuestion.app
```

The build dir (`build/`), `*.xcodeproj/`, `Info.plist`, and SPM metadata are gitignored. **`project.yml` is the source of truth** for project structure — the `.xcodeproj` is regenerated.

Default summon hotkey: **⌥⌘J**. ⌘, while overlay is open → settings. Esc → dismiss + clear (or, in settings, return to chat).

## Architecture at a glance

Pure-AppKit lifecycle (no SwiftUI App protocol — see "Gotchas" for why), AppDelegate-driven, single floating `NSPanel`. Ollama via direct HTTP to `localhost:11434`. State is in-memory only; user settings persist via `UserDefaults`.

### File map

```
TinyQuestion/
  TinyQuestionApp.swift     # @main entry — manual NSApplication.run() loop
  AppDelegate.swift         # Owns panel, hotkey manager, observation tracking for hotkey rebind
  Window/
    OverlayPanel.swift      # NSPanel subclass: nonactivating, floating, hidesOnDeactivate=false
    HotkeyManager.swift     # Wraps HotKey package; takes carbon keycode + modifiers
  Views/
    OverlayView.swift       # Root SwiftUI view; toggles between Conversation and Settings
    ConversationView.swift  # Message list + input + model picker; ⌘, → settings, Esc → dismiss
    MessageView.swift       # One bubble; user = plain Text, assistant = MarkdownContent
    MarkdownContent.swift   # Splits on ``` fences; AttributedString for inline; styled blocks for code
    ModelPickerView.swift   # Inline Menu of installed models; calls /api/tags
    SettingsView.swift      # System prompt + model + hotkey; Esc → back to chat
    HotkeyCaptureView.swift # NSEvent local monitor for keyDown; requires a modifier
  Services/
    OllamaClient.swift      # listModels (/api/tags), streamChat (/api/chat, NDJSON via URLSession.bytes)
    AppSettings.swift       # @Observable, UserDefaults-backed (NOT named `Settings` — see Gotchas)
  Models/
    ChatMessage.swift       # { role, content } — used as both wire format and UI state
    Conversation.swift      # @Observable; owns the streaming Task; clear() cancels in-flight stream
project.yml                 # xcodegen spec — source of truth
```

### Data flow

1. Hotkey fires → `AppDelegate.toggle()` shows or hides the panel.
2. User types in `ConversationView` → `Conversation.send(...)` builds `[system, ...history, user]`, appends an empty assistant `ChatMessage`, kicks off a streaming `Task`.
3. `OllamaClient.streamChat` reads `URLSession.bytes(for:).lines`, JSON-decodes each NDJSON chunk, yields `message.content` deltas via `AsyncThrowingStream`.
4. The send-task accumulates deltas into the assistant message's `content`; SwiftUI auto-renders the streaming text and `ConversationView` auto-scrolls.
5. On `Esc` → `Conversation.clear()` cancels the Task, empties messages, and `AppDelegate.dismiss()` orders the panel out.
6. Hotkey re-registration: `AppDelegate.observeHotkeyChanges()` uses `withObservationTracking` (one-shot, re-arms after each fire) on `AppSettings.hotkeyKeyCode/Modifiers`.

### State ownership

- `Conversation` is created once in `AppDelegate` and lives for the app lifetime; `clear()` resets it but the instance stays.
- `AppSettings` likewise — read once at launch, persisted writes go through `didSet`.
- `OllamaClient` is a value type, instantiated once.
- The `OverlayPanel`'s `NSHostingView` holds the SwiftUI tree; `OverlayView` receives those three as `@Bindable` / `let`.

## Key invariants — don't break these

- **`LSUIElement = true`** in `project.yml`. The app must never appear in Dock or app switcher.
- **No SwiftUI App protocol.** `@main` is on `TinyQuestionMain` (a `struct` with `static func main()`) which calls `NSApplication.shared.run()` directly. Do not switch to `App { ... Settings { ... } }` — that auto-binds ⌘, to a separate Settings window and breaks the in-overlay settings (see Gotchas).
- **Panel is non-activating.** `OverlayPanel.styleMask` includes `.nonactivatingPanel`; `hidesOnDeactivate = false`; `level = .floating`. Survives ⌘-Tab.
- **Conversation is ephemeral.** No persistence layer. `clear()` must remain truly destructive. Don't add a history file without re-discussing scope.
- **xcodegen is source of truth.** Don't hand-edit `TinyQuestion.xcodeproj`; if you add a Swift file, run `xcodegen generate` before building.
- **Sandbox is OFF** (`ENABLE_APP_SANDBOX: NO`) so we can hit `localhost:11434`. If you ever turn it on, add `com.apple.security.network.client` entitlement.
- **macOS 14+ deployment target.** Code uses `@Observable`, modern `AttributedString` markdown, `.onKeyPress` — none of which exist below 14.

## Common changes

### Add a new persisted setting
1. Add a stored property + `Keys.foo` constant in `Services/AppSettings.swift`.
2. Add init logic that reads from `UserDefaults` with a default fallback.
3. `didSet` writes back. That's the whole storage layer.
4. Surface in `Views/SettingsView.swift` as a new section.

### Add a new top-level view in the overlay
1. Create the SwiftUI view in `Views/`.
2. Wire a switch in `OverlayView` (currently a 2-state `@State Bool showingSettings` — extend to an enum if you add a third).
3. Run `xcodegen generate`.

### Change the default hotkey
Edit `AppSettings.defaultHotkeyKeyCode` (UInt32 carbon keycode) and `AppSettings.defaultHotkeyModifiers` (`NSEvent.ModifierFlags`). Existing users have it stored in `UserDefaults` — only affects fresh installs unless they reset.

### Add a new Ollama-API field (e.g., `temperature`, `num_ctx`)
Edit `OllamaClient.ChatRequest` (the private `Encodable` struct). If user-tunable, route through `AppSettings`.

## Gotchas

- **`Settings` is a SwiftUI scene name.** Our settings class is named `AppSettings` for that reason. If you rename it back to `Settings`, `TinyQuestionApp.swift` (or anything that ever reintroduces a SwiftUI App body with `Settings { ... }`) will collide.
- **The SwiftUI App protocol auto-binds ⌘,.** Even `Settings { EmptyView() }` registers a Settings menu item that intercepts ⌘, before our `.onKeyPress` handler fires. That's why we run a manual `NSApplication.run()` loop. If you ever migrate back to `@main App`, the ⌘, → in-overlay settings flow will silently break (a blank window opens instead).
- **`@NSApplicationDelegateAdaptor` is gone too** — `AppDelegate` is instantiated directly in `TinyQuestionMain.main()` and assigned via `app.delegate = delegate`. `NSApp.delegate` is `weak`; the local `delegate` var stays alive because `app.run()` blocks until termination.
- **`withObservationTracking` is one-shot.** `AppDelegate.observeHotkeyChanges` re-calls itself inside the `onChange` closure to re-arm. If you forget to re-arm, the hotkey only updates once.
- **`xcodegen generate` must run after adding/removing/renaming files.** The build will fail with "cannot find type 'X' in scope" if you forget. The error makes it look like a Swift problem — it's actually a missing project membership.
- **HotKey keycode mapping.** `Key(carbonKeyCode: UInt32(event.keyCode))` works because both use Carbon virtual keycodes (e.g. J = 38, Space = 49). Don't try to translate to `keyEquivalent` strings.
- **Streaming task lifetime.** `Conversation.streamingTask` is `@ObservationIgnored` to avoid spurious view re-renders on task assignment. Keep it that way.
- **Markdown parsing during streaming.** `MarkdownContent.parse` flushes an unclosed ``` fence as a code block, so partial fences mid-stream still render. Don't "fix" this to be strict.
- **First launch with Ollama down** — model picker shows "Ollama unreachable" and the persisted default (`phi4-mini:latest`) is sent on submit, which surfaces a friendly inline error. Don't add a startup blocker; the app should still launch.

## Out of scope (don't add without re-brainstorming)

These were explicitly ruled out in the design phase. If a future request implies adding them, surface the conflict before implementing:

- Conversation history / persistence
- Cloud LLM fallback
- Voice input
- Multi-window or multiple concurrent conversations
- Auto-update mechanism
- Menu bar icon
- Settings sync across devices
- Telemetry of any kind

## References

- **Original plan & design rationale:** `~/.claude/plans/i-have-an-idea-sunny-deer.md`
- **Ollama API docs:** https://github.com/ollama/ollama/blob/main/docs/api.md
- **HotKey package:** https://github.com/soffes/HotKey
- **xcodegen reference:** https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md
