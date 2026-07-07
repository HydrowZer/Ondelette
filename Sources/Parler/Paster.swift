import AppKit
import CoreGraphics

/// Colle le texte dans l'application active en simulant ⌘V,
/// puis restaure le contenu précédent du presse-papiers.
enum Paster {
    static func paste(_ text: String) {
        let pasteboard = NSPasteboard.general

        // Sauvegarde du presse-papiers actuel (tous types).
        let savedItems: [NSPasteboardItem] = (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        sendCmdV()

        // Laisse le temps à l'app cible de lire le presse-papiers avant restauration.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            pasteboard.clearContents()
            if !savedItems.isEmpty {
                pasteboard.writeObjects(savedItems)
            }
        }
    }

    private static func sendCmdV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9
        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        else { return }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
