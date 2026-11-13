import Foundation
import Darwin

/// Headless use, for scripts and hooks:
///
///   buzz --play "b40/10@6"              buzz now
///   buzz --play "b40/10@6" --hold 600   buzz now; if nothing was touching the pad,
///                                             buzz again on the next touch within 600 s
///
/// Only one --hold waiter is kept alive at a time: a newer one replaces the older.
enum CommandLinePlayer {
    static func runIfRequested() {
        let args = CommandLine.arguments
        guard let playIndex = args.firstIndex(of: "--play") else { return }
        guard playIndex + 1 < args.count else { fail("--play needs a pattern, e.g. --play \"b40/10@6\"") }

        var holdSeconds = 0.0
        if let holdIndex = args.firstIndex(of: "--hold") {
            guard holdIndex + 1 < args.count, let value = Double(args[holdIndex + 1]), value >= 0 else {
                fail("--hold needs a number of seconds")
            }
            holdSeconds = value
        }

        let steps: [Step]
        do {
            steps = try PatternParser.parse(args[playIndex + 1], defaultID: 6)
        } catch let error as PatternError {
            fail(error.message)
        } catch {
            fail("could not parse pattern")
        }

        guard let device = Actuator.devices().first else { fail("no haptic trackpad found") }
        guard let actuator = Actuator(deviceID: device.id), actuator.openResult == 0 else {
            fail("could not open the trackpad actuator")
        }

        let holding = holdSeconds > 0 && TouchMonitor.shared.start()
        if holding { replaceEarlierWaiter() }

        DispatchQueue.global(qos: .userInteractive).async {
            if holding { usleep(150_000) } // give contact frames a moment to arrive
            let touchedAtStart = holding && TouchMonitor.shared.isTouching
            play(steps, on: actuator)

            if holding && !touchedAtStart {
                let deadline = DispatchTime.now().uptimeNanoseconds + UInt64(holdSeconds * 1_000_000_000)
                while DispatchTime.now().uptimeNanoseconds < deadline {
                    if TouchMonitor.shared.isTouching {
                        usleep(150_000)
                        play(steps, on: actuator)
                        break
                    }
                    usleep(10_000)
                }
            }
            exit(0)
        }

        // Keep the main run loop alive for the multitouch callbacks.
        while true { CFRunLoopRunInMode(.defaultMode, 1, false) }
    }

    private static func play(_ steps: [Step], on actuator: Actuator) {
        var deadline = DispatchTime.now().uptimeNanoseconds
        for step in steps {
            switch step {
            case .pulse(let id):
                actuator.actuate(id)
            case .wait(let ms):
                deadline += UInt64(ms * 1_000_000)
                let now = DispatchTime.now().uptimeNanoseconds
                if deadline > now { usleep(UInt32((deadline - now) / 1000)) }
            case .system:
                break
            }
        }
    }

    /// Stops an earlier `--hold` process that is still waiting, so queued buzzes don't pile up.
    private static func replaceEarlierWaiter() {
        let pidFile = NSTemporaryDirectory() + "buzz-hold.pid"
        if let text = try? String(contentsOfFile: pidFile, encoding: .utf8),
           let pid = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)),
           pid != getpid() {
            var buffer = [CChar](repeating: 0, count: 4096)
            if proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0,
               String(cString: buffer).hasSuffix("/buzz") {
                kill(pid, SIGTERM)
            }
        }
        try? "\(getpid())".write(toFile: pidFile, atomically: true, encoding: .utf8)
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write("buzz: \(message)\n".data(using: .utf8)!)
        exit(2)
    }
}
