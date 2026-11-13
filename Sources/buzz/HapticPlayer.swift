import AppKit
import Combine

private final class CancelFlag {
    private let lock = NSLock()
    private var value = false

    var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return value
    }

    func cancel() {
        lock.lock(); value = true; lock.unlock()
    }

    /// Sleeps until an absolute uptime deadline, waking early if cancelled.
    /// Returns false when cancelled.
    func sleep(until deadline: UInt64) -> Bool {
        while true {
            if isCancelled { return false }
            let now = DispatchTime.now().uptimeNanoseconds
            if now >= deadline { return true }
            let remaining = deadline - now
            usleep(UInt32(min(remaining, 20_000_000) / 1000))
        }
    }

    func sleep(ms: Double) -> Bool {
        sleep(until: DispatchTime.now().uptimeNanoseconds + UInt64(max(ms, 0) * 1_000_000))
    }
}

final class HapticPlayer: ObservableObject {
    @Published var devices: [TrackpadDevice] = []
    @Published var selectedDevice: UInt64? {
        didSet { if selectedDevice != oldValue { openSelected() } }
    }
    @Published var delaySeconds = 0
    @Published var loop = false
    @Published var loopGapSeconds = 2.0
    @Published var isPlaying = false
    @Published var status = "Ready"
    @Published var deviceStatus = ""

    /// Extra arguments passed to every private actuation (meaning undocumented).
    @Published var argFloat1: Double = 0
    @Published var argFloat2: Double = 2

    /// Deferred delivery: hold the pattern until something is touching the pad.
    @Published var waitForTouch = false
    /// Pause between touch-down and the buzz, so it doesn't blur into the touch itself.
    @Published var settleMs = 150.0
    @Published var isTouching = false
    @Published var touchMonitorAvailable = false

    private var actuator: Actuator?
    private var current: CancelFlag?
    private var touchTimer: Timer?

    init() {
        refreshDevices()
        touchMonitorAvailable = TouchMonitor.shared.start()
        if touchMonitorAvailable {
            touchTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                let touching = TouchMonitor.shared.isTouching
                if self?.isTouching != touching { self?.isTouching = touching }
            }
        }
    }

    func refreshDevices() {
        devices = Actuator.devices()
        if let selected = selectedDevice, devices.contains(where: { $0.id == selected }) {
            openSelected()
        } else {
            let pick = devices.first?.id
            if pick == selectedDevice { openSelected() } else { selectedDevice = pick }
        }
    }

    private func openSelected() {
        stop()
        actuator = nil
        guard Actuator.frameworkAvailable else {
            deviceStatus = "MultitouchSupport framework could not be loaded"
            return
        }
        guard let id = selectedDevice else {
            deviceStatus = "No haptic trackpad found"
            return
        }
        guard let opened = Actuator(deviceID: id) else {
            deviceStatus = "Could not create an actuator for this device"
            return
        }
        actuator = opened
        deviceStatus = opened.openResult == 0
            ? "Actuator open"
            : String(format: "Actuator open failed (0x%08X)", UInt32(bitPattern: opened.openResult))
    }

    func play(pattern: String, defaultID: Int32, name: String) {
        do {
            play(try PatternParser.parse(pattern, defaultID: defaultID), name: name)
        } catch let error as PatternError {
            status = error.message
        } catch {
            status = "Could not parse pattern"
        }
    }

    func play(_ steps: [Step], name: String) {
        stop()

        let needsActuator = steps.contains { if case .pulse = $0 { return true } else { return false } }
        if needsActuator && actuator == nil {
            status = "No actuator available: \(deviceStatus)"
            return
        }

        let flag = CancelFlag()
        current = flag
        isPlaying = true

        let actuator = self.actuator
        let delay = delaySeconds
        let loop = self.loop
        let gapMs = loopGapSeconds * 1000
        let f1 = Float(argFloat1)
        let f2 = Float(argFloat2)
        let holdForTouch = waitForTouch && touchMonitorAvailable
        let settle = settleMs

        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            var lastError: Int32 = 0
            var cancelled = false
            var heldSeconds = 0.0

            if delay > 0 {
                for remaining in stride(from: delay, to: 0, by: -1) {
                    self?.post(flag, "\(name) in \(remaining)…")
                    if !flag.sleep(ms: 1000) { cancelled = true; break }
                }
            }

            var round = 0
            while !cancelled {
                round += 1

                if holdForTouch && !TouchMonitor.shared.isTouching {
                    self?.post(flag, "\(name) queued, waiting for a touch…")
                    let began = DispatchTime.now().uptimeNanoseconds
                    while !TouchMonitor.shared.isTouching {
                        if !flag.sleep(ms: 8) { cancelled = true; break }
                    }
                    if cancelled { break }
                    heldSeconds = Double(DispatchTime.now().uptimeNanoseconds - began) / 1_000_000_000
                    if !flag.sleep(ms: settle) { cancelled = true; break }
                }

                self?.post(flag, loop ? "Playing \(name) (round \(round))" : "Playing \(name)")

                var deadline = DispatchTime.now().uptimeNanoseconds
                for step in steps {
                    if flag.isCancelled { cancelled = true; break }
                    switch step {
                    case .pulse(let id):
                        let result = actuator?.actuate(id, f1: f1, f2: f2) ?? -1
                        if result != 0 { lastError = result }
                    case .system(let pattern):
                        DispatchQueue.main.async {
                            NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
                        }
                    case .wait(let ms):
                        deadline += UInt64(ms * 1_000_000)
                        if !flag.sleep(until: deadline) { cancelled = true }
                    }
                    if cancelled { break }
                }

                if cancelled || !loop { break }
                if !flag.sleep(ms: gapMs) { cancelled = true }
            }

            let wasCancelled = cancelled
            let errorCode = lastError
            let held = heldSeconds
            DispatchQueue.main.async {
                guard let self, self.current === flag else { return }
                self.current = nil
                self.isPlaying = false
                if errorCode != 0 {
                    self.status = String(format: "\(name): actuator returned 0x%08X", UInt32(bitPattern: errorCode))
                } else {
                    if wasCancelled {
                        self.status = "Stopped"
                    } else if held > 0 {
                        self.status = String(format: "Played \(name) after holding %.1f s for a touch", held)
                    } else {
                        self.status = "Played \(name)"
                    }
                }
            }
        }
    }

    func stop() {
        guard let flag = current else { return }
        flag.cancel()
        current = nil
        isPlaying = false
        status = "Stopped"
    }

    private func post(_ flag: CancelFlag, _ text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.current === flag else { return }
            self.status = text
        }
    }
}
