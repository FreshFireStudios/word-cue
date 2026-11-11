// UNTESTED: written without Xcode.
// "Anywhere" shortcuts: the keys that work while the presentation app is in
// front (Control-Option plus the normal key). Uses the Carbon hot key API,
// which needs no special permission.
import Carbon.HIToolbox
import AppKit
import WordCueKit

final class GlobalHotKeys {
    private var refs: [EventHotKeyRef?] = []
    private var handlerRef: EventHandlerRef?
    private var actions: [UInt32: String] = [:]
    fileprivate var onAction: ((String) -> Void)?

    /// `keys`: action name -> the combo to register system-wide.
    func register(_ keys: [String: KeyCombo], onAction: @escaping (String) -> Void) {
        unregister()
        self.onAction = onAction
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return noErr }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            let me = Unmanaged<GlobalHotKeys>.fromOpaque(userData).takeUnretainedValue()
            if let action = me.actions[hotKeyID.id] {
                DispatchQueue.main.async { me.onAction?(action) }
            }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)

        var next: UInt32 = 1
        for (action, combo) in keys.sorted(by: { $0.key < $1.key }) {
            guard let code = combo.keyCode else { continue }
            var modifiers = 0
            if combo.command { modifiers |= cmdKey }
            if combo.option { modifiers |= optionKey }
            if combo.control { modifiers |= controlKey }
            if combo.shift { modifiers |= shiftKey }
            var ref: EventHotKeyRef?
            RegisterEventHotKey(UInt32(code), UInt32(modifiers), EventHotKeyID(signature: 0x57435545, id: next),
                                GetApplicationEventTarget(), 0, &ref)
            actions[next] = action
            refs.append(ref)
            next += 1
        }
    }

    func unregister() {
        refs.compactMap { $0 }.forEach { UnregisterEventHotKey($0) }
        refs = []
        actions = [:]
        if let handlerRef { RemoveEventHandler(handlerRef) }
        handlerRef = nil
    }
}
