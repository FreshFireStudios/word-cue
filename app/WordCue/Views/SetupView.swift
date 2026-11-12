// UNTESTED: written without Xcode.
// First-run setup, built to Figures 2 to 6 of the User Guide: five steps,
// everything centred, one grouped card of rows per step, progress dots at
// the bottom left, Back and Continue at the bottom right.
import SwiftUI
import WordCueKit

struct SetupView: View {
    @Environment(AppModel.self) private var model
    @State private var step = 0
    @State private var testing = false

    private var app: String { model.s.presentationApp.displayName }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                header
                VStack(spacing: 0) { rows }
                    .background(Theme.raise, in: RoundedRectangle(cornerRadius: 10))
                    .frame(maxWidth: 400)
                if step == 1 {
                    Text("Accessibility is only requested later, if Word Cue needs it.").font(.system(size: 10)).foregroundStyle(Theme.dim)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 34)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { i in
                        Circle().fill(i == step ? Theme.orange : Theme.raise2).frame(width: 5, height: 5)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel("Step \(step + 1) of 5")
                Spacer()
                if step > 0 {
                    Button("Back") { go(step - 1) }.buttonStyle(PillButtonStyle())
                }
                Button(step == 4 ? "Start Using Word Cue" : "Continue") {
                    if step == 4 {
                        model.settings.s.finishedSetup = true
                        model.showSetup = false
                        model.stopLevelCheck()
                    } else {
                        go(step + 1)
                    }
                }
                .buttonStyle(PillButtonStyle(kind: .primary))
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .frame(width: 560, height: 470)
        .foregroundStyle(Theme.text)
        .background(Theme.window)
        .onAppear { model.refreshPermissions() }
    }

    private func go(_ next: Int) {
        step = next
        if next == 2 { model.startLevelCheck() } else { model.stopLevelCheck() }
        if next == 3 || next == 4 { Task { await model.checkConnection() } }
    }

    // MARK: Header (icon tile, title, one or two lines)

    private var header: some View {
        let h: (String, IconTile.Tint, String, String) = {
            switch step {
            case 0: return ("flame.fill", .orange, "Welcome to Word Cue", "Word Cue listens to the sermon and puts scripture on screen with one key. Setup takes about five minutes.")
            case 1: return ("checkmark.shield", .green, "Allow access", "Word Cue needs two permissions. Nothing you allow ever leaves this Mac.")
            case 2: return ("mic", .orange, "Choose your audio", "Pick the input carrying the pulpit mic, then say a few words into it.")
            case 3: return ("display", .blue, "Connect your presentation app", "Word Cue sends verses to the app you already use on Sunday.")
            default: return ("checkmark.shield", .green, "You\u{2019}re all set", "Word Cue will appear beside \(app) whenever it opens.")
            }
        }()
        return VStack(spacing: 8) {
            IconTile(symbol: h.0, tint: h.1, size: 34)
            Text(h.2).font(.system(size: 15, weight: .bold))
            Text(h.3).font(.system(size: 11)).foregroundStyle(Theme.dim).multilineTextAlignment(.center).frame(maxWidth: 330)
        }
    }

    // MARK: Rows

    private func row<Trailing: View>(_ symbol: String, _ tint: IconTile.Tint, _ title: String, _ sub: String = "",
                                     last: Bool = false, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                IconTile(symbol: symbol, tint: tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 11, weight: .semibold))
                    if !sub.isEmpty { Text(sub).font(.system(size: 10)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true) }
                }
                Spacer(minLength: 6)
                trailing()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            if !last { Rectangle().fill(Theme.hair).frame(height: 1) }
        }
    }

    private func ready(_ text: String, _ ok: Bool = true) -> some View {
        HStack(spacing: 4) {
            Circle().fill(ok ? Theme.green : Theme.amber).frame(width: 6, height: 6)
            Text(text).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(ok ? Theme.green : Theme.amber)
        }
    }

    @ViewBuilder
    private var rows: some View {
        @Bindable var settings = model.settings
        switch step {
        case 0:
            row("waveform", .orange, "Hears the sermon", "From your soundboard, transcribed on this Mac.")
            row("text.magnifyingglass", .orange, "Finds the verses", "Spoken and written references, in real time.")
            row("return", .orange, "You send them", "Every verse waits for you by default.", last: true)
        case 1:
            row("mic", .green, "Microphone", "To receive audio from your soundboard\u{2019}s USB interface.") {
                if model.permissions.microphone { ready("Allowed") } else {
                    Button("Allow") { Task { _ = await SystemIntegration.requestMicrophone(); model.refreshPermissions() } }
                        .buttonStyle(PillButtonStyle(kind: .primary))
                }
            }
            row("text.bubble", .neutral, "Speech Recognition", "To transcribe the sermon on this Mac.", last: true) {
                if model.permissions.speech { ready("Allowed") } else {
                    Button("Allow") { Task { _ = await SystemIntegration.requestSpeech(); model.refreshPermissions() } }
                        .buttonStyle(PillButtonStyle(kind: .primary))
                }
            }
        case 2:
            row("cable.connector", .orange, "Audio interface") {
                SelectPill(selection: $settings.s.inputDeviceUID,
                           options: [("", "System default")] + model.inputDevices.map { ($0.uid, $0.name) })
            }
            row("slider.horizontal.3", .blue, "Input channel") {
                SelectPill(selection: $settings.s.inputChannel,
                           options: [(0, "Mix of all channels")] + (1...max(1, AudioInput.channelCount(uid: settings.s.inputDeviceUID))).map { ($0, "Channel \($0)") })
            }
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Live level").font(.system(size: 11, weight: .semibold))
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.raise2)
                            Capsule().fill(Theme.orange).frame(width: geo.size.width * CGFloat(model.level))
                        }
                    }
                    .frame(height: 3)
                }
                if model.speechDetected { ready("Speech detected") }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .onChange(of: settings.s.inputDeviceUID) { model.startLevelCheck() }
            .onChange(of: settings.s.inputChannel) { model.startLevelCheck() }
        case 3:
            row("rectangle.stack", .orange, "Presentation app") {
                SelectPill(selection: $settings.s.presentationApp, options: PresentationApp.allCases.map { ($0, $0.displayName) })
            }
            ForEach(Array(settings.s.presentationApp.setupSteps.enumerated()), id: \.offset) { i, text in
                row("\(i + 1).circle", .orange, text)
            }
            row(model.appConnected == true ? "checkmark" : "bolt.horizontal", model.appConnected == true ? .green : .neutral,
                model.appConnected == true ? "Connected to \(app)" : "Not connected yet",
                model.appConnected == true ? model.connectionNote : "Follow the steps above, then press Test.", last: true) {
                if testing { ProgressView().controlSize(.small) }
                Button("Test") {
                    testing = true
                    Task {
                        await model.checkConnection()
                        testing = false
                    }
                }
                .buttonStyle(PillButtonStyle())
            }
        default:
            row("mic", .green, "Audio", model.inputDevices.first { $0.uid == settings.s.inputDeviceUID }?.name ?? "System default input") {
                ready(model.permissions.microphone ? "Ready" : "Check", model.permissions.microphone)
            }
            row("text.bubble", .green, "Speech recognition") { ready(model.permissions.speech ? "Ready" : "Check", model.permissions.speech) }
            row("display", .green, app, model.appConnected == true ? "Connected" : "Not connected") {
                ready(model.appConnected == true ? "Ready" : "Check", model.appConnected == true)
            }
            row("power", .neutral, "Launch Word Cue at login") {
                Toggle("", isOn: $settings.s.launchAtLogin).toggleStyle(.switch).controlSize(.mini).labelsHidden().tint(Theme.orange)
            }
            row("macwindow", .neutral, "Show Word Cue when \(app) opens", last: true) {
                Toggle("", isOn: $settings.s.showWhenAppOpens).toggleStyle(.switch).controlSize(.mini).labelsHidden().tint(Theme.orange)
            }
        }
    }
}
