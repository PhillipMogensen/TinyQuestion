import AppKit

@main
struct TinyQuestionMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
        // app.run() blocks until termination; `delegate` stays in scope
        // so NSApp.delegate's weak reference remains valid.
    }
}
