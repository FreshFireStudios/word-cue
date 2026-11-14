// UNTESTED: written without Xcode. Window placement is the kind of code that
// needs a real screen to get right; expect to adjust it.
//
// Full sidebar: 380 points wide, pinned to the right edge of the OPERATOR's
// screen at full height, and it cannot be dragged wider.
// Compact: a small floating panel in a corner, above other windows.
//
// "Keep it off the projector": a booth Mac usually has two screens, the
// operator's and the projector output. Word Cue picks the operator's screen
// on purpose (the one the church chose in Settings, else the built-in
// display, else the screen with the menu bar) and moves back there if a
// projector is plugged in or the screens are rearranged.
import SwiftUI
import AppKit
import CoreGraphics
import WordCueKit

struct WindowManager: NSViewRepresentable {
    let compact: Bool
    let corner: PanelCorner
    let opacity: Double
    let onTop: Bool
    let screenName: String          // "" = choose automatically
    let onWindow: (NSWindow) -> Void

    static let sidebarWidth: CGFloat = 380
    static let compactSize = CGSize(width: 300, height: 150)

    final class Coordinator {
        var lastPlacement = ""
        var observer: NSObjectProtocol?
        deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // Screens added, removed or rearranged: place the window again.
        context.coordinator.observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak view] _ in
            context.coordinator.lastPlacement = ""
            view?.needsLayout = true
            if let view { place(view, context.coordinator) }
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { place(view, context.coordinator) }
    }

    /// Only moves the window when something that decides its place has changed,
    /// so it never fights the operator on every redraw.
    private func place(_ view: NSView, _ coordinator: Coordinator) {
        guard let window = view.window else { return }
        onWindow(window)
        let screen = Self.operatorScreen(named: screenName)
        let key = "\(compact)|\(corner)|\(screen.localizedName)|\(screen.frame)"
        window.alphaValue = compact ? opacity : 1
        window.level = compact && onTop ? .floating : .normal
        guard key != coordinator.lastPlacement else { return }
        coordinator.lastPlacement = key

        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = compact
        // The compact panel has no traffic lights in the guide (Figure 8).
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(button)?.isHidden = compact
        }
        window.collectionBehavior.insert(.fullScreenNone)     // never goes full screen onto any display

        let area = screen.visibleFrame
        if compact {
            let size = Self.compactSize
            let x = corner == .topLeft || corner == .bottomLeft ? area.minX + 16 : area.maxX - size.width - 16
            let y = corner == .topLeft || corner == .topRight ? area.maxY - size.height - 16 : area.minY + 16
            window.minSize = size
            window.maxSize = size
            window.setFrame(NSRect(origin: CGPoint(x: x, y: y), size: size), display: true, animate: true)
        } else {
            let w = Self.sidebarWidth
            window.minSize = CGSize(width: w, height: 480)
            window.maxSize = CGSize(width: w, height: 10_000)
            window.setFrame(NSRect(x: area.maxX - w, y: area.minY, width: w, height: area.height), display: true, animate: true)
        }
    }

    /// The operator's screen: the one picked in Settings, else the Mac's
    /// built-in display, else the screen with the menu bar. Projectors are
    /// almost always an added, external screen, so this keeps Word Cue off them.
    static func operatorScreen(named name: String) -> NSScreen {
        let screens = NSScreen.screens
        if !name.isEmpty, let chosen = screens.first(where: { $0.localizedName == name }) { return chosen }
        if let builtIn = screens.first(where: { screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return false }
            return CGDisplayIsBuiltin(id) != 0
        }) { return builtIn }
        return screens.first ?? NSScreen.main!      // screens[0] is the one with the menu bar
    }

    /// Names for the picker in Settings.
    static var screenNames: [String] { NSScreen.screens.map(\.localizedName) }
}
