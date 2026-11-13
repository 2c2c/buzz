import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var player: HapticPlayer
    var showPrompt: () -> Void = {}

    @State private var burstCount = 30.0
    @State private var burstInterval = 10.0
    @State private var burstID: Int32 = 6
    @State private var customPattern = "b22/10@6 p140 b22/10@6"
    @State private var rawID = 7
    @State private var showAdvanced = false

    private let columns = [GridItem(.adaptive(minimum: 118), spacing: 8)]

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    singlePulses
                    presetSection("Small", note: "Light, brief. Could suit low-priority sounds.", presets: Presets.small)
                    presetSection("Big", note: "Strongest single hits and sustained buzzes.", presets: Presets.big)
                    presetSection("Sequences", note: "Rhythms that could identify a kind of event.", presets: Presets.sequences)
                    burstBuilder
                    customSection
                    advancedSection
                }
                .padding(16)
            }
        }
        .frame(width: 620, height: 780)
    }

    // MARK: Control bar

    private var controlBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("Trackpad", selection: $player.selectedDevice) {
                    if player.devices.isEmpty {
                        Text("None found").tag(UInt64?.none)
                    }
                    ForEach(player.devices) { device in
                        Text(device.name).tag(UInt64?.some(device.id))
                    }
                }
                .frame(maxWidth: 380)
                Button("Rescan") { player.refreshDevices() }
                Button("Agent Prompt") { showPrompt() }
                    .help("Back to the copy-paste prompt for setting up alerts.")
                Spacer()
                Text(player.deviceStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 14) {
                Picker("Start", selection: $player.delaySeconds) {
                    Text("Now").tag(0)
                    Text("2 s").tag(2)
                    Text("5 s").tag(5)
                    Text("10 s").tag(10)
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
                .help("Delay before playing, so you can move your hands to where they would really be.")

                Toggle("Loop", isOn: $player.loop)
                    .help("Repeat the pattern until stopped.")
                if player.loop {
                    Stepper("every \(player.loopGapSeconds, specifier: "%.1f") s gap",
                            value: $player.loopGapSeconds, in: 0.5...30, step: 0.5)
                        .fixedSize()
                }
                Spacer()
                Button("Stop") { player.stop() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(!player.isPlaying)
            }

            HStack(spacing: 14) {
                Toggle("Hold until touch", isOn: $player.waitForTouch)
                    .disabled(!player.touchMonitorAvailable)
                    .help("Deferred buzz: queue the pattern and play it when something next touches the trackpad. Combine with a Start delay so you can lift your hands first.")
                if player.waitForTouch {
                    Stepper("then wait \(Int(player.settleMs)) ms",
                            value: $player.settleMs, in: 0...1000, step: 50)
                        .fixedSize()
                        .help("Gap between touch-down and the buzz.")
                }
                Spacer()
                if player.touchMonitorAvailable {
                    Circle()
                        .fill(player.isTouching ? Color.blue : Color.secondary.opacity(0.4))
                        .frame(width: 8, height: 8)
                    Text(player.isTouching ? "Pad touched" : "Pad clear")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 70, alignment: .leading)
                } else {
                    Text("Touch sensing unavailable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(player.isPlaying ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 8, height: 8)
                Text(player.status)
                    .font(.callout)
                    .lineLimit(1)
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: Sections

    private var singlePulses: some View {
        GroupBox("Single pulses") {
            VStack(alignment: .leading, spacing: 10) {
                Text("One actuation per click, by actuation ID. Strength and character differ per ID; note which feel strongest.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(Actuator.knownIDs, id: \.self) { id in
                        Button("ID \(id)") {
                            player.play([.pulse(id)], name: "ID \(id)")
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                HStack(spacing: 8) {
                    Text("System API:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Generic") { player.play([.system(.generic)], name: "System generic") }
                    Button("Alignment") { player.play([.system(.alignment)], name: "System alignment") }
                    Button("Level change") { player.play([.system(.levelChange)], name: "System level change") }
                    Spacer()
                }
            }
            .padding(6)
        }
    }

    private func presetSection(_ title: String, note: String, presets: [Preset]) -> some View {
        GroupBox(title) {
            VStack(alignment: .leading, spacing: 10) {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(presets) { preset in
                        Button {
                            customPattern = preset.pattern
                            player.play(pattern: preset.pattern, defaultID: burstID, name: preset.name)
                        } label: {
                            Text(preset.name).frame(maxWidth: .infinity)
                        }
                        .help(preset.pattern)
                    }
                }
            }
            .padding(6)
        }
    }

    private var burstPattern: String {
        "b\(Int(burstCount))/\(Int(burstInterval))@\(burstID)"
    }

    private var burstBuilder: some View {
        GroupBox("Burst builder") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Pulses").frame(width: 70, alignment: .leading)
                    Slider(value: $burstCount, in: 1...200, step: 1)
                    Text("\(Int(burstCount))").monospacedDigit().frame(width: 60, alignment: .trailing)
                }
                HStack {
                    Text("Interval").frame(width: 70, alignment: .leading)
                    Slider(value: $burstInterval, in: 2...100, step: 1)
                    Text("\(Int(burstInterval)) ms").monospacedDigit().frame(width: 60, alignment: .trailing)
                }
                HStack {
                    Text("Pulse").frame(width: 70, alignment: .leading)
                    Picker("", selection: $burstID) {
                        ForEach(Actuator.knownIDs, id: \.self) { id in
                            Text("\(id)").tag(id)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                HStack {
                    Text("\(burstPattern)  ·  \(Int(burstCount * burstInterval)) ms  ·  \(Int(1000 / burstInterval)) Hz")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Spacer()
                    Button("Copy to custom") { customPattern = burstPattern }
                    Button("Play burst") {
                        player.play(pattern: burstPattern, defaultID: burstID, name: "Burst \(burstPattern)")
                    }
                    .keyboardShortcut("b", modifiers: .command)
                }
            }
            .padding(6)
        }
    }

    private var customSection: some View {
        GroupBox("Custom pattern") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("Pattern", text: $customPattern)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .onSubmit(playCustom)
                    Button("Play", action: playCustom)
                        .keyboardShortcut(.return, modifiers: .command)
                }
                Text("t = tap · bN/MS = N pulses MS ms apart · pMS = pause · add @ID to pick the pulse (t@6, b20/12@4). Presets load here for editing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(6)
        }
    }

    private var advancedSection: some View {
        GroupBox {
            DisclosureGroup("Advanced: undocumented actuator arguments", isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("MTActuatorActuate takes two extra floats whose meaning is undocumented. They apply to every private pulse above; change them and listen for a difference.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("Float 1").frame(width: 70, alignment: .leading)
                        Slider(value: $player.argFloat1, in: 0...10, step: 0.25)
                        Text("\(player.argFloat1, specifier: "%.2f")").monospacedDigit().frame(width: 60, alignment: .trailing)
                    }
                    HStack {
                        Text("Float 2").frame(width: 70, alignment: .leading)
                        Slider(value: $player.argFloat2, in: 0...10, step: 0.25)
                        Text("\(player.argFloat2, specifier: "%.2f")").monospacedDigit().frame(width: 60, alignment: .trailing)
                    }
                    HStack {
                        Stepper("Try actuation ID \(rawID)", value: $rawID, in: 1...64)
                            .fixedSize()
                        Button("Fire") {
                            player.play([.pulse(Int32(rawID))], name: "ID \(rawID)")
                        }
                        Button("Reset arguments") {
                            player.argFloat1 = 0
                            player.argFloat2 = 2
                        }
                        Spacer()
                    }
                    Text("IDs outside the known set usually do nothing; the status line shows any error code returned.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 6)
            }
            .padding(6)
        }
    }

    private func playCustom() {
        player.play(pattern: customPattern, defaultID: burstID, name: "Custom")
    }
}
