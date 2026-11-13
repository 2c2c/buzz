import Foundation

/// The copy-paste prompt that teaches a coding agent what Buzz does and
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
        I have Buzz installed. It is a small macOS command-line tool that vibrates the MacBook trackpad, like a phone on vibrate. I want you to add it to this agent harness as an alert, so I can tell when you need me or have finished while my sound is off.

        The binary is at:
          \(executablePath)

        How to run it:
          "\(executablePath)" --play "PATTERN"
          "\(executablePath)" --play "PATTERN" --hold 600

        The first form buzzes once, right now. The second also buzzes now, and if nothing was touching the trackpad at that moment it buzzes again the next time the trackpad is touched, for up to 600 seconds. Use the second form for alerts, because the buzz can only be felt with a hand on the trackpad.

        Pattern syntax, tokens separated by spaces:
          t        one tap
          bN/MS    a burst of N pulses, MS milliseconds apart (b40/10 is a 0.4 second buzz)
          pMS      pause for MS milliseconds
          @ID      optional suffix on t or b picking the pulse type (1-6, 15 or 16; default 6)

        Suggested patterns:
          Finished a task or a turn:        b40/10@6
          Needs my input or a permission:   b22/10@6 p140 b22/10@6
          Small acknowledgement:            t@6 p130 t@6

        Facts you can rely on:
          - It needs no permissions and no network access, opens no window, and exits by itself.
          - It exits 0 on success and non-zero if the pattern is invalid or no haptic trackpad is found.
          - A newer --hold call replaces an older one that is still waiting, so alerts do not pile up.
          - It only works on Macs with a Force Touch trackpad or a Magic Trackpad with haptics.

        What I want you to do:
          1. Find how this harness runs commands on events, such as hooks or notification settings. The events I care about are: you finished and are waiting for me, you need a permission or an answer, and a long-running task completed.
          2. Add a command for each of those events that runs the buzz with --hold 600. Use a different pattern for "finished" and "needs input" so I can tell them apart.
          3. Run it in the background so it never delays you, with output discarded, for example by ending the command with: </dev/null >/dev/null 2>&1 &
          4. Keep any alert sounds or notifications I already have. Add the buzz alongside them.
          5. Show me the exact change and where it goes before you edit any configuration file.
          6. After installing, run one buzz command yourself and ask me to confirm that I felt it.
        """
    }
}
