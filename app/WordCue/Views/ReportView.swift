// UNTESTED: written without Xcode.
import SwiftUI

/// "Report a Problem": the operator writes what went wrong and sees exactly what will be saved.
struct ReportView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @State private var includeTranscript = false
    @State private var result = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Report a Problem").font(.title2.weight(.semibold))
            Text("What went wrong? For example: \u{201C}It showed Acts 2:28 but he said Acts 2:38.\u{201D}")
                .foregroundStyle(.secondary)
            TextEditor(text: $note)
                .frame(height: 110)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
            Toggle("Include the last few lines Word Cue heard", isOn: $includeTranscript)
            Text("The report lists this service's suggestions and your note. No audio is ever included.")
                .font(.caption).foregroundStyle(.secondary)
            if !result.isEmpty { Text(result).font(.callout) }
            HStack {
                Spacer()
                Button("Close") { dismiss() }
                Button("Save Report") {
                    Task { result = await model.sendReport(note: note, includeTranscript: includeTranscript) }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}
