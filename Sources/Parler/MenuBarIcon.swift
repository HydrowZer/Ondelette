import AppKit

/// Glyphe de barre de menus : la signature vocale de Parler (même onde
/// calligraphique que l'icône de l'app), dessinée en vectoriel.
/// Template par défaut (s'adapte au thème), rouge pendant l'enregistrement.
enum MenuBarIcon {
    static func make(recording: Bool) -> NSImage {
        let size = NSSize(width: 22, height: 16)
        let image = NSImage(size: size, flipped: false) { _ in
            let path = NSBezierPath()
            let midY: CGFloat = 8
            let samples = 64
            for i in 0...samples {
                let t = CGFloat(i) / CGFloat(samples)
                let x = 1 + t * 20
                let centered = (x - 11) / 5.2
                let envelope = exp(-centered * centered)
                let y = midY + 6.2 * envelope * cos((x - 11) * 0.95)
                let point = NSPoint(x: x, y: y)
                if i == 0 {
                    path.move(to: point)
                } else {
                    path.line(to: point)
                }
            }
            path.lineWidth = 1.7
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            (recording ? NSColor.systemRed : NSColor.black).setStroke()
            path.stroke()
            return true
        }
        image.isTemplate = !recording
        return image
    }
}
