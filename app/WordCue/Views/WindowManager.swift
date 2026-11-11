// UNTESTED: written without Xcode. Window placement is the kind of code that
// needs a real screen to get right; expect to adjust it.
//
// Full sidebar: about 380 points wide, pinned to the right edge of the
// operator's screen at full height, and it cannot be dragged wider.
// Compact: a small floating panel in a corner, above other windows.
import SwiftUI
import AppKit
import WordCueKit

struct WindowManager: NSViewRepresentable {
    let compact: Bool
    let corner: PanelCorner
    let opacity: Double
    let onTop: Bool
    let onWindow: (NSWindow) -> Void

    static let sidebarWidth: CGFloat = 380
    static let compactSize = CGSize(width: 340, height: 190)

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = view.window, let screen = window.screen ?? NSScreen.main else { return }
            onWindow(window)
            let area = screen.visibleFrame
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = compact
            if compact {
                let size = Self.compactSize
                let x = corner == .topLeft || corner == .bottomLeft ? area.minX + 16 : area.maxX - size.width - 16
                let y = corner == .topLeft || corner == .topRight ? area.maxY - size.height - 16 : area.minY + 16
                window.minSize = size
                window.maxSize = size
                window.setFrame(NSRect(origin: CGPoint(x: x, y: y), size: size), display: true, animate: true)
                window.level = onTop ? .floating : .normal
                window.alphaValue = opacity
            } else {
                let w = Self.sidebarWidth
                window.minSize = CGSize(width: w, height: 480)
                window.maxSize = CGSize(width: w, height: 10_000)
                window.setFrame(NSRect(x: area.maxX - w, y: area.minY, width: w, height: area.height), display: true, animate: true)
                window.level = .normal
                window.alphaValue = 1
            }
        }
    }
}
