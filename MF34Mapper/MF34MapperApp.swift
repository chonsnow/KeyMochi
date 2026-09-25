import SwiftUI
import AppKit

@main
struct MF34MapperApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // macOS 메뉴바의 [About KeyMochi / About MF34Mapper] 메뉴를 커스텀 기믹 창으로 교체
            CommandGroup(replacing: .appInfo) {
                Button("About KeyMochi") {
                    showCustomAboutWindow()
                }
            }
        }
    }
}

// MARK: - 커스텀 About 윈도우 컨트롤러 (중복 창 방지 싱글톤)
private var aboutBoxWindowController: NSWindowController?

func showCustomAboutWindow() {
    if let controller = aboutBoxWindowController, let window = controller.window {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return
    }
    
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 320, height: 260),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false
    )
    window.title = "About KeyMochi"
    window.titlebarAppearsTransparent = true
    window.center()
    window.isReleasedWhenClosed = false
    window.contentView = NSHostingView(rootView: AboutView())
    
    let controller = NSWindowController(window: window)
    aboutBoxWindowController = controller
    controller.showWindow(nil)
    NSApp.activate(ignoringOtherApps: true)
}
