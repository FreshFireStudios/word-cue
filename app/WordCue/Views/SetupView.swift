// UNTESTED: written without Xcode.
// First-run setup (User Guide section 03): five steps, about five minutes.
// Welcome, Allow access, Audio, Connect, Done. Dots at the bottom show progress.
import SwiftUI
import WordCueKit

struct SetupView: View {
    @Environment(AppModel.self) private var model
    @State private var step = 0
    @State private var testResult = ""
    @State private var testing = false

    var body: some View {
        @Bindable var settings = model.settings
        VStack(spacing: 0) {
            Group {
                switch step {
                case 0: welcome
                case 1: access
                case 2: audio(settings)
                case 3: connect(settings)
                default: done(settings)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(28)
            Divider()
            HStack {
                if step > 0 { Button("Back") { step -= 1 } }
                Spacer()
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { i in
                        Circle().fill(i == step ? Color.accentColor : Color.secondary.opacity(0.3)).frame(width: 7, height: 7)
                    }
                }
                .accessibilityLabel("Step \(step + 1) of 5")
                Spacer()
                Button(step == 4 ? "Open Word Cue" : "Continue") {
                    if step == 4 {
                        model.settings.s.finishedSetup = true
                        model.showSetup = false
                        model.stopLevelCheck()
                    } else {
                        step += 1
                        if step == 2 { model.startLevelCheck() } else { model.stopLevelCheck() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 560, height: 470)
    }

    private func heading(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.title.weight(.bold))
            Text(sub).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 14)
    }

    private func point(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundStyle(Theme.orange).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 5)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Word Cue").font(Theme.wordmark(34))
            Text("Scripture on screen the moment it\u{2019}s preached.").font(.title3).foregroundStyle(.secondary).padding(.bottom, 18)
            point("waveform", "Hears the sermon", "Listens to the pulpit mic through your soundboard, on this Mac only.")
            point("text.magnifyingglass", "Finds the verses", "Recognizes references like \u{201C}Acts 2:38\u{201D} in real time.")
            point("hand.tap", "Waits for you", "Nothing reaches the screen until the operator sends it.")
        }
    }

    private var access: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading("Allow access", "Word Cue asks macOS for two permissions. Nothing allowed here ever leaves the Mac.")
            permission("Microphone", "To receive audio from the soundboard\u{2019}s USB interface.", model.permissions.microphone) {
                Task { _ = await SystemIntegration.requestMicrophone(); model.refreshPermissions() }
            }
            permission("Speech Recognition", "To transcribe the sermon on this Mac.", model.permissions.speech) {
                Task { _ = await SystemIntegration.requestSpeech(); model.refreshPermissions() }
            }
            Text("Accessibility is asked for later, and only if your setup needs it.")
                .font(.callout).foregroundStyle(.secondary).padding(.top, 12)
        }
    }

    private func permission(_ name: String, _ why: String, _ granted: Bool, _ ask: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.headline)
                Text(why).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if granted {
                Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.green)
            } else {
                Button("Allow", action: ask)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
        .padding(.bottom, 8)
    }

    private func audio(_ settings: AppSettings) -> some View {
        @Bindable var settings = settings
        return VStack(alignment: .leading, spacing: 0) {
            heading("Choose your audio", "Pick the interface carrying the soundboard feed and the channel carrying the pulpit mic, then say a few words into it.")
            Form {
                Picker("Audio interface", selection: $settings.s.inputDeviceUID) {
                    Text("System default").tag("")
                    ForEach(model.inputDevices) { Text($0.name).tag($0.uid) }
                }
                Picker("Input channel", selection: $settings.s.inputChannel) {
                    Text("Mix of all channels").tag(0)
                    ForEach(1...max(1, AudioInput.channelCount(uid: settings.s.inputDeviceUID)), id: \.self) { Text("Channel \($0)").tag($0) }
                }
                LabeledContent("Level") {
                    HStack {
                        LevelMeter(level: model.level).frame(width: 180, height: 8)
                        if model.speechDetected {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green).accessibilityLabel("Sound detected")
                        }
                    }
                }
            }
            .onChange(of: settings.s.inputDeviceUID) { model.startLevelCheck() }
            .onChange(of: settings.s.inputChannel) { model.startLevelCheck() }
            Text("Best practice: feed the pastor\u{2019}s mic channel from the board into a USB audio interface instead of using a room mic.")
                .font(.callout).foregroundStyle(.secondary).padding(.top, 10)
        }
    }

    private func connect(_ settings: AppSettings) -> some View {
        @Bindable var settings = settings
        return VStack(alignment: .leading, spacing: 0) {
            heading("Connect your presentation app", "Pick the app your church uses. It runs on this same Mac.")
            Picker("Presentation app", selection: $settings.s.presentationApp) {
                ForEach(PresentationApp.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Text(settings.s.presentationApp.setupHint)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                .padding(.vertical, 12)
            if settings.s.presentationApp == .proPresenter {
                Form { TextField("Port", value: $settings.s.port, format: .number.grouping(.never), prompt: Text("50001")) }
            }
            if !settings.s.presentationApp.hasAPI && !model.permissions.accessibility {
                Button("Allow Accessibility\u{2026}") { KeyboardAdapter.requestPermission() }
            }
            HStack {
                Button("Test") {
                    testing = true
                    Task {
                        await model.checkConnection()
                        testResult = model.connectionNote
                        testing = false
                    }
                }
                if testing { ProgressView().controlSize(.small) }
                Text(testResult).font(.callout).foregroundStyle(model.appConnected == true ? Theme.green : .secondary)
            }
            Text("Test sends a signal without changing what\u{2019}s on screen.").font(.caption).foregroundStyle(.secondary).padding(.top, 4)
        }
    }

    private func done(_ settings: AppSettings) -> some View {
        @Bindable var settings = settings
        return VStack(alignment: .leading, spacing: 0) {
            heading("You\u{2019}re all set", "From now on Word Cue appears beside your presentation app automatically.")
            summary("Audio", model.permissions.microphone)
            summary("Speech recognition", model.permissions.speech)
            summary(settings.s.presentationApp.displayName, model.appConnected == true)
            Form {
                Toggle("Launch Word Cue at login", isOn: $settings.s.launchAtLogin)
                Toggle("Show Word Cue when your presentation app opens", isOn: $settings.s.showWhenAppOpens)
            }
            .padding(.top, 10)
        }
    }

    private func summary(_ name: String, _ ok: Bool) -> some View {
        HStack {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle").foregroundStyle(ok ? Theme.green : Theme.yellow)
            Text(name)
            Spacer()
            Text(ok ? "Ready" : "Check in Settings").foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
