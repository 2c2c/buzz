import Foundation
import IOKit

/// A trackpad that reports haptic actuation support.
struct TrackpadDevice: Identifiable, Hashable {
    let id: UInt64
    let name: String
    let builtIn: Bool
}

/// Thin wrapper over the private MultitouchSupport actuator calls.
/// Symbols are resolved at runtime so no bridging header or private linking is needed.
final class Actuator {
    private typealias CreateFn = @convention(c) (UInt64) -> UnsafeMutableRawPointer?
    private typealias OpenFn = @convention(c) (UnsafeMutableRawPointer) -> Int32
    private typealias CloseFn = @convention(c) (UnsafeMutableRawPointer) -> Int32
    private typealias ActuateFn = @convention(c) (UnsafeMutableRawPointer, Int32, UInt32, Float, Float) -> Int32

    private struct Symbols {
        let create: CreateFn
        let open: OpenFn
        let close: CloseFn
        let actuate: ActuateFn
    }

    private static let symbols: Symbols? = {
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let handle = dlopen(path, RTLD_LAZY),
              let create = dlsym(handle, "MTActuatorCreateFromDeviceID"),
              let open = dlsym(handle, "MTActuatorOpen"),
              let close = dlsym(handle, "MTActuatorClose"),
              let actuate = dlsym(handle, "MTActuatorActuate")
        else { return nil }
        return Symbols(
            create: unsafeBitCast(create, to: CreateFn.self),
            open: unsafeBitCast(open, to: OpenFn.self),
            close: unsafeBitCast(close, to: CloseFn.self),
            actuate: unsafeBitCast(actuate, to: ActuateFn.self)
        )
    }()

    static var frameworkAvailable: Bool { symbols != nil }

    /// Actuation IDs other tools have found to produce feedback.
    static let knownIDs: [Int32] = [1, 2, 3, 4, 5, 6, 15, 16]

    private let ref: UnsafeMutableRawPointer
    let openResult: Int32

    init?(deviceID: UInt64) {
        guard let s = Actuator.symbols, let ref = s.create(deviceID) else { return nil }
        self.ref = ref
        self.openResult = s.open(ref)
    }

    deinit {
        if let s = Actuator.symbols {
            _ = s.close(ref)
        }
        Unmanaged<AnyObject>.fromOpaque(ref).release()
    }

    /// Fires one actuation. Returns the IOReturn code (0 = success).
    @discardableResult
    func actuate(_ id: Int32, arg: UInt32 = 0, f1: Float = 0, f2: Float = 2) -> Int32 {
        guard let s = Actuator.symbols else { return -1 }
        return s.actuate(ref, id, arg, f1, f2)
    }

    static func devices() -> [TrackpadDevice] {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("AppleMultitouchDevice")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        var found: [TrackpadDevice] = []
        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 { break }
            defer { IOObjectRelease(service) }

            var unmanaged: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &unmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let props = unmanaged?.takeRetainedValue() as? [String: Any],
                  (props["ActuationSupported"] as? Bool) == true,
                  let id = (props["Multitouch ID"] as? NSNumber)?.uint64Value
            else { continue }

            let builtIn = (props["MT Built-In"] as? Bool) ?? false
            let product = props["Product"] as? String
            let name = product ?? (builtIn ? "Built-in Trackpad" : "External Trackpad")
            found.append(TrackpadDevice(id: id, name: builtIn ? "\(name) (built-in)" : name, builtIn: builtIn))
        }
        return found.sorted { $0.builtIn && !$1.builtIn }
    }
}
