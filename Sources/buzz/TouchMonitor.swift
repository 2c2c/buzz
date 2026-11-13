import Foundation

/// Watches raw trackpad contact frames (private MultitouchSupport API) so we know
/// whether anything is resting on the pad right now. Fingers and palms both count.
final class TouchMonitor {
    static let shared = TouchMonitor()

    private typealias CreateListFn = @convention(c) () -> UnsafeMutableRawPointer?
    private typealias FrameCallback = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32
    private typealias RegisterFn = @convention(c) (UnsafeRawPointer, FrameCallback) -> Void
    private typealias StartFn = @convention(c) (UnsafeRawPointer, Int32) -> Void

    private let lock = NSLock()
    private var contacts: Int32 = 0
    private var lastFrame: UInt64 = 0
    private var deviceList: CFArray?

    private(set) var isRunning = false

    /// Frames only arrive while something is on the pad, so a stale frame means "lifted".
    private let staleAfter: UInt64 = 200_000_000

    var isTouching: Bool {
        lock.lock(); defer { lock.unlock() }
        return contacts > 0 && DispatchTime.now().uptimeNanoseconds - lastFrame < staleAfter
    }

    fileprivate func record(contacts count: Int32) {
        lock.lock()
        contacts = count
        lastFrame = DispatchTime.now().uptimeNanoseconds
        lock.unlock()
    }

    /// Starts monitoring every multitouch device. Returns false if the private API is unavailable.
    @discardableResult
    func start() -> Bool {
        if isRunning { return true }
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let handle = dlopen(path, RTLD_LAZY),
              let createSym = dlsym(handle, "MTDeviceCreateList"),
              let registerSym = dlsym(handle, "MTRegisterContactFrameCallback"),
              let startSym = dlsym(handle, "MTDeviceStart")
        else { return false }

        let createList = unsafeBitCast(createSym, to: CreateListFn.self)
        let register = unsafeBitCast(registerSym, to: RegisterFn.self)
        let startDevice = unsafeBitCast(startSym, to: StartFn.self)

        guard let raw = createList() else { return false }
        let list = Unmanaged<CFArray>.fromOpaque(raw).takeRetainedValue()
        let count = CFArrayGetCount(list)
        guard count > 0 else { return false }

        for index in 0..<count {
            guard let device = CFArrayGetValueAtIndex(list, index) else { continue }
            register(device, touchFrameCallback)
            startDevice(device, 0)
        }
        deviceList = list // keep the devices alive for the life of the app
        isRunning = true
        return true
    }
}

private let touchFrameCallback: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32 = { _, _, count, _, _ in
    TouchMonitor.shared.record(contacts: count)
    return 0
}
