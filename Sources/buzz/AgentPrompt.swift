import Foundation

/// The copy-paste prompt that tells a coding agent what Buzz does and
/// asks it to wire the buzz into its harness as an alert.
struct AgentPrompt {
    /// Path the prompt tells the agent to run.
    let executablePath: String
    /// Shown above the prompt when the path is an assumption rather than where we are running from.
    let note: String?

    static let applicationsPath = "/Applications/Buzz.app/Contents/MacOS/buzz"

    static var current: AgentPrompt {
        let bundlePath = Bundle.main.bundlePath
        // From the disk image, or a quarantined copy macOS runs from a temporary
        // location, the real path would stop existing. Point at Applications instead.
        if bundlePath.hasPrefix("/Volumes/") || bundlePath.contains("/AppTranslocation/") {
            return AgentPrompt(
                executablePath: applicationsPath,
                note: "Move Buzz to your Applications folder before using this prompt. It assumes the app lives there."
            )
        }
        let path = Bundle.main.executableURL?.resolvingSymlinksInPath().path ?? CommandLine.arguments[0]
        return AgentPrompt(executablePath: path, note: nil)
    }

    var text: String {
        """
        Buzz is a macOS command-line tool that vibrates the trackpad, like a phone on vibrate. Add it to this agent harness as a silent alert.

        Command:
          "\(executablePath)" --play "PATTERN"

        Pattern tokens, separated by spaces:
          t        one tap
          bN/MS    a burst of N pulses, MS milliseconds apart
          pMS      a pause of MS milliseconds
          @ID      optional suffix on t or b selecting the pulse type (1-6, 15 or 16; default 6)

        Suggested patterns:
          Finished and waiting for me:      b40/10@6
          Needs my input or a permission:   b22/10@6 p140 b22/10@6

        Behavior:
          - Needs no permissions or network access, opens no window, and exits by itself.
          - Exits non-zero if the pattern is invalid or no haptic trackpad is found.
          - Adding --hold N repeats the buzz on the next trackpad touch within N seconds if the trackpad was not being touched. This is optional.

        Please:
          1. Find how this harness runs commands on events such as finishing a turn, asking for input or a permission, and completing a long task.
          2. Add the buzz command to each of those events, using a different pattern for "finished" and "needs input".
          3. Run it in the background with output discarded, for example by ending the command with: </dev/null >/dev/null 2>&1 &
          4. Keep any alerts I already have and add the buzz alongside them.
          5. Show me the change before editing any configuration file, then run one buzz so I can confirm it works.
        """
    }
}
