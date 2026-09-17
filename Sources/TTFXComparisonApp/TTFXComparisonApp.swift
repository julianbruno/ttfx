import SwiftUI
import AppKit

@main
struct TTFXComparisonApp: App {
    @NSApplicationDelegateAdaptor(ComparisonAppDelegate.self) private var delegate
    var body: some Scene {
        WindowGroup("TTFX Video Comparison") {
            ComparisonRootView()
        }
        .defaultSize(width: 1240, height: 790)
    }
}

@MainActor final class ComparisonAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
