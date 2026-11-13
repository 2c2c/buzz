import SwiftUI

enum LaunchMode {
    /// Default: the small window with the copy-paste agent prompt.
    case prompt
    /// `--playground`: the full pattern lab.
    case playground

    static var current: LaunchMode = .prompt
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when launched as a bare executable (swift run) rather than a .app bundle.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

struct BuzzApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var player = HapticPlayer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(player)
        }
        .windowResizability(.contentSize)
    }
}

struct RootView: View {
    @State private var showPlayground = LaunchMode.current == .playground

    var body: some View {
        Group {
            if showPlayground {
                ContentView(showPrompt: { showPlayground = false })
            } else {
                PromptView(openPlayground: { showPlayground = true })
            }
        }
        .navigationTitle(showPlayground ? "Buzz Playground" : "Buzz")
    }
}

/// `buzz --selftest` checks the actuator path without opening a window.
enum SelfTest {
    static func run() {
        print("framework loaded: \(Actuator.frameworkAvailable)")
        let devices = Actuator.devices()
        print("haptic trackpads: \(devices.count)")
        for device in devices {
            print("  \(device.name) id=\(device.id)")
            guard let actuator = Actuator(deviceID: device.id) else {
                print("    could not create actuator")
                continue
            }
            print(String(format: "    open -> 0x%08X", UInt32(bitPattern: actuator.openResult)))
            for id in Actuator.knownIDs {
                let result = actuator.actuate(id)
                print(String(format: "    actuate id %2d -> 0x%08X", id, UInt32(bitPattern: result)))
                usleep(250_000)
            }
        }
    }
}
