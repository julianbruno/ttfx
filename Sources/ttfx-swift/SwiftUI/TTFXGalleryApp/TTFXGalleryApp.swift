import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct TTFXGalleryApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(TTFXGalleryAppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup("TTFX Gallery") {
            TTFXGalleryRootView()
                #if os(macOS)
                .onAppear {
                    TTFXGalleryAppDelegate.bringToFront()
                }
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1120, height: 760)
        .defaultPosition(.center)
        #endif
    }
}

#if os(macOS)
@MainActor
final class TTFXGalleryAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.bringToFront()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    static func bringToFront() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
#endif

