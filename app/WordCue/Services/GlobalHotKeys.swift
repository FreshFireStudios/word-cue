// UNTESTED: written without Xcode.
// System-wide shortcuts, so the operator can approve a verse while
// ProPresenter is the front app. Uses the old-but-reliable Carbon hot key
// API, which needs no special permission.
//
//   Control-Option-Return   send the selected suggestion
//   Control-Option-Delete   dismiss it
//   Control-Option-Up/Down  move the selection
//   Control-Option-Right    next verse        Control-Option-Left  previous verse
//   Control-Option-Period   clear the screen
import Carbon.HIToolbox
import AppKit

final class GlobalHotKeys {
    enum Action: UInt32, CaseIterable {
        case send = 1, dismiss, up, down, nextVerse, previousVerse, clear

        var keyCode: Int {
            switch self {
            case .send: return kVK_Return
            case .dismiss: return kVK_Delete
            case .up: return kVK_UpArrow
            case .down: return kVK_DownArrow
            case .nextVerse: return kVK_RightArrow
            case .previousVerse: return kVK_LeftArrow
            case .clear: return kVK_ANSI_Period
            }
        }
    }

    private var refs: [EventHotKeyRef?] = []
    private var handlerRef: EventHandlerRef?
    fileprivate var onAction: ((Action) -> Void)?

    func register(_ onAction: @escaping (Action) -> Void) {
        self.onAction = onAction
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return noErr }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            let me = Unmanaged<GlobalHotKeys>.fromOpaque(userData).takeUnretainedValue()
            if let action = Action(rawValue: hotKeyID.id) {
                DispatchQueue.main.async { me.onAction?(action) }
            }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)

        let signature: OSType = 0x57435545   // "WCUE"
        for action in Action.allCases {
            var ref: EventHotKeyRef?
            RegisterEventHotKey(UInt32(action.keyCode), UInt32(controlKey | optionKey),
                                EventHotKeyID(signature: signature, id: action.rawValue),
                                GetApplicationEventTarget(), 0, &ref)
            refs.append(ref)
        }
    }

    func unregister() {
        refs.compactMap { $0 }.forEach { UnregisterEventHotKey($0) }
        refs = []
        if let handlerRef { RemoveEventHandler(handlerRef) }
        handlerRef = nil
    }
}
