import AppKit

enum Step {
    /// One actuation through the private actuator, by actuation ID.
    case pulse(Int32)
    /// One actuation through the public NSHapticFeedbackManager API.
    case system(NSHapticFeedbackManager.FeedbackPattern)
    /// Wait in milliseconds.
    case wait(Double)
}

struct PatternError: Error {
    let message: String
}

/// Tiny pattern language so patterns can be typed, tweaked and shared as text.
///
///   t        one tap                      t@6      one tap with actuation ID 6
///   b20/12   burst: 20 pulses 12 ms apart b20/12@4 same, with actuation ID 4
///   p150     pause 150 ms
///
/// Tokens are separated by spaces. A burst includes its trailing interval, so
/// back-to-back bursts run continuously. Taps have no trailing gap.
enum PatternParser {
    static func parse(_ text: String, defaultID: Int32) throws -> [Step] {
        let tokens = text.lowercased()
            .split(whereSeparator: { $0 == " " || $0 == "," || $0 == "\n" })
            .map(String.init)
        guard !tokens.isEmpty else { throw PatternError(message: "Pattern is empty") }

        var steps: [Step] = []
        for token in tokens {
            let parts = token.split(separator: "@", omittingEmptySubsequences: false)
            guard parts.count <= 2 else { throw PatternError(message: "Too many @ in \"\(token)\"") }
            var id = defaultID
            if parts.count == 2 {
                guard let parsed = Int32(parts[1]), parsed > 0 else {
                    throw PatternError(message: "Bad actuation ID in \"\(token)\"")
                }
                id = parsed
            }
            let body = String(parts[0])
            guard let kind = body.first else { throw PatternError(message: "Empty token") }
            let rest = String(body.dropFirst())

            switch kind {
            case "t":
                guard rest.isEmpty else { throw PatternError(message: "Tap takes no number: \"\(token)\"") }
                steps.append(.pulse(id))
            case "p":
                guard let ms = Double(rest), ms >= 0, ms <= 60_000 else {
                    throw PatternError(message: "Pause needs milliseconds, e.g. p150: \"\(token)\"")
                }
                steps.append(.wait(ms))
            case "b":
                let nums = rest.split(separator: "/")
                guard nums.count == 2,
                      let count = Int(nums[0]), count >= 1, count <= 2000,
                      let interval = Double(nums[1]), interval >= 1, interval <= 5000
                else {
                    throw PatternError(message: "Burst is bCOUNT/INTERVAL, e.g. b20/12: \"\(token)\"")
                }
                for _ in 0..<count {
                    steps.append(.pulse(id))
                    steps.append(.wait(interval))
                }
            default:
                throw PatternError(message: "Unknown token \"\(token)\" (use t, bN/MS, pMS)")
            }
        }
        return steps
    }
}

struct Preset: Identifiable {
    let name: String
    let pattern: String
    var id: String { name }
}

enum Presets {
    static let small: [Preset] = [
        Preset(name: "Tick", pattern: "t@1"),
        Preset(name: "Soft double", pattern: "t@2 p110 t@2"),
        Preset(name: "Flutter", pattern: "b6/14@1"),
        Preset(name: "Nudge", pattern: "b4/20@3"),
    ]

    static let big: [Preset] = [
        Preset(name: "Thump", pattern: "t@6"),
        Preset(name: "Double thump", pattern: "t@6 p130 t@6"),
        Preset(name: "Triple thump", pattern: "t@6 p130 t@6 p130 t@6"),
        Preset(name: "Short buzz", pattern: "b12/10@6"),
        Preset(name: "Phone buzz", pattern: "b40/10@6"),
        Preset(name: "Long buzz", pattern: "b100/10@6"),
    ]

    static let sequences: [Preset] = [
        Preset(name: "Message", pattern: "b22/10@6 p140 b22/10@6"),
        Preset(name: "Incoming call", pattern: "b70/11@6 p450 b70/11@6 p450 b70/11@6"),
        Preset(name: "Heartbeat", pattern: "t@6 p150 t@4 p650 t@6 p150 t@4 p650 t@6 p150 t@4"),
        Preset(name: "Ramp up", pattern: "b8/14@1 b8/14@2 b8/14@3 b8/14@4 b8/14@5 b10/14@6"),
        Preset(name: "Ramp down", pattern: "b10/14@6 b8/14@5 b8/14@4 b8/14@3 b8/14@2 b8/14@1"),
        Preset(name: "Accelerate", pattern: "t@6 p320 t@6 p240 t@6 p170 t@6 p120 t@6 p80 t@6 p50 t@6 p30 b14/12@6"),
        Preset(name: "Purr", pattern: "b30/32@4"),
        Preset(name: "Rattle", pattern: "b50/6@5"),
        Preset(name: "Alarm", pattern: "b18/9@6 p90 b18/9@6 p90 b18/9@6 p500 b18/9@6 p90 b18/9@6 p90 b18/9@6"),
        Preset(name: "SOS", pattern: "t@6 p120 t@6 p120 t@6 p320 b18/10@6 p140 b18/10@6 p140 b18/10@6 p320 t@6 p120 t@6 p120 t@6"),
    ]
}
