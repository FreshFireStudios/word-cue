// UNTESTED: written without Xcode.
import SwiftUI
import UniformTypeIdentifiers

/// Switches between the full sidebar and compact mode, and handles dropped files.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var dropTargeted = false

    var body: some View {
        @Bindable var model = model
        Group {
            if model.compact {
                CompactView()
                    .frame(minWidth: 300, idealWidth: 340, minHeight: 150, idealHeight: 170)
            } else {
                SidebarView()
                    .frame(minWidth: 300, idealWidth: 360, minHeight: 480, idealHeight: 760)
            }
        }
        .background(Theme.window)
        .foregroundStyle(Theme.text)
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Theme.amber, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .background(Theme.amber.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(Text("Drop to add its verses").font(.headline))
                    .padding(8)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            model.importFiles(urls)
            return !urls.isEmpty
        } isTargeted: { dropTargeted = $0 }
        .background(WindowLevel(floating: model.settings.keepOnTop))
        .sheet(isPresented: $model.showingReport) { ReportView() }
    }
}

/// Keeps the Word Cue window above ProPresenter when "Keep on top" is on.
struct WindowLevel: NSViewRepresentable {
    let floating: Bool

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            view.window?.level = floating ? .floating : .normal
        }
    }
}
