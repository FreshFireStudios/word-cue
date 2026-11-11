// UNTESTED: written without Xcode.
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var connectionMessage = ""
    @State private var busy = false

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section("Audio") {
                Picker("Input", selection: $settings.inputDeviceUID) {
                    Text("System default").tag("")
                    ForEach(model.inputDevices) { device in
                        Text(device.name).tag(device.uid)
                    }
                }
                Text("Pick the audio interface that carries the soundboard feed. Changes apply the next time you start listening.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("ProPresenter") {
                TextField("Computer", text: $settings.proPresenter.host, prompt: Text("127.0.0.1"))
                TextField("Port", value: $settings.proPresenter.port, format: .number.grouping(.never))
                TextField("Message name", text: $settings.proPresenter.messageName)
                HStack {
                    Button("Test Connection") { run { await model.testConnection() } }
                    Button("Set Up Message") { run { await model.setUpMessage() } }
                    if busy { ProgressView().controlSize(.small) }
                }
                if !connectionMessage.isEmpty {
                    Text(connectionMessage).font(.callout)
                }
                Text("In ProPresenter, open Settings > Network and turn on Enable Network. The port is shown there.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Also show the reference on the stage display", isOn: $settings.alsoShowOnStage)
            }
            Section("Suggestions") {
                LabeledContent("Hide suggestions below") {
                    Slider(value: $settings.minimumConfidence, in: 0.3...0.9, step: 0.05)
                    Text("\(Int(settings.minimumConfidence * 100))%").monospacedDigit()
                }
                Toggle("Send sure matches to the screen automatically", isOn: $settings.autoSend)
                if settings.autoSend {
                    LabeledContent("Only when at least") {
                        Slider(value: $settings.autoSendThreshold, in: 0.8...0.99, step: 0.01)
                        Text("\(Int(settings.autoSendThreshold * 100))%").monospacedDigit()
                    }
                    Text("With this on, a verse can reach the screen without anyone approving it.")
                        .font(.caption).foregroundStyle(Theme.yellow)
                }
            }
            Section("Window") {
                Toggle("Keep Word Cue on top of other windows", isOn: $settings.keepOnTop)
                Toggle("Show what Word Cue is hearing", isOn: $settings.showTranscript)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .onAppear { model.refreshDevices() }
    }

    private func run(_ work: @escaping () async -> String) {
        busy = true
        Task {
            connectionMessage = await work()
            busy = false
        }
    }
}
