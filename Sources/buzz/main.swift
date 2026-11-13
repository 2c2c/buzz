import Foundation

// Entry point. Headless flags are handled here, before any AppKit setup, so a
// buzz fired from a hook never shows a Dock icon or a window.

let usage = """
Buzz: vibrate the Mac trackpad as a silent alert.

  buzz                           show the agent setup prompt
  buzz --playground              open the playground with every pattern and control
  buzz --play PATTERN            buzz now
  buzz --play PATTERN --hold N   buzz now; if nothing was touching the trackpad,
                                 buzz again on the next touch within N seconds
  buzz --prompt                  print the agent setup prompt
  buzz --selftest                check the trackpad actuator
  buzz --help                    show this help

Pattern tokens, separated by spaces:
  t        one tap
  bN/MS    burst of N pulses, MS milliseconds apart (b40/10 is a 0.4 s buzz)
  pMS      pause for MS milliseconds
  @ID      optional suffix on t or b choosing the pulse type: 1-6, 15 or 16 (default 6)

Examples:
  buzz --play "b40/10@6"
  buzz --play "b22/10@6 p140 b22/10@6" --hold 600
"""

let knownFlags: Set<String> = ["--playground", "--play", "--hold", "--prompt", "--selftest", "--help", "-h"]
let arguments = Array(CommandLine.arguments.dropFirst())

if arguments.contains("--help") || arguments.contains("-h") {
    print(usage)
    exit(0)
}

// Finder and `open` can pass single-dash system arguments; only double-dash flags are ours.
if let unknown = arguments.first(where: { $0.hasPrefix("--") && !knownFlags.contains($0) }) {
    FileHandle.standardError.write("buzz: unknown option \(unknown)\n\n\(usage)\n".data(using: .utf8)!)
    exit(2)
}

if arguments.contains("--selftest") {
    SelfTest.run()
    exit(0)
}

if arguments.contains("--prompt") {
    print(AgentPrompt.current.text)
    exit(0)
}

if arguments.contains("--hold") && !arguments.contains("--play") {
    FileHandle.standardError.write("buzz: --hold only applies together with --play\n".data(using: .utf8)!)
    exit(2)
}

CommandLinePlayer.runIfRequested() // does not return when --play is present

LaunchMode.current = arguments.contains("--playground") ? .playground : .prompt
BuzzApp.main()
