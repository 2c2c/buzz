import SwiftUI

/// The default window: a prompt to paste into a coding agent.
struct PromptView: View {
    @EnvironmentObject private var player: HapticPlayer
    let openPlayground: () -> Void

    @State private var copied = false
    private let prompt = AgentPrompt.current

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Buzz")
                        .font(.title2.bold())
                    Text("Trackpad buzzes as silent alerts from your coding agent.")
                        .foregroundStyle(.secondary)
                }
            }

            Text("Copy this prompt and paste it into your agent. It explains what Buzz can do and asks the agent to add it to its alerts.")
                .fixedSize(horizontal: false, vertical: true)

            if let note = prompt.note {
                Label(note, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView {
                Text(prompt.text)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(height: 320)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))

            HStack {
                Button("Test Buzz") {
                    player.play(pattern: "b40/10@6", defaultID: 6, name: "Test buzz")
                }
                .help("Plays the 0.4 second buzz. Keep a finger on the trackpad to feel it.")
                Button("Open Playground") { openPlayground() }
                    .help("Try every pulse, preset and pattern.")
                Spacer()
                Button(copied ? "Copied" : "Copy Prompt") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(prompt.text, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                }
                .keyboardShortcut(.defaultAction)
            }

            if !player.deviceStatus.isEmpty && player.devices.isEmpty {
                Text(player.deviceStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 600)
    }
}
