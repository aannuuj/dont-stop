import AppKit

enum AppIconFactory {
    static func menuBarIcon(active: Bool) -> NSImage {
        let size: CGFloat = 18
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let bounds = NSRect(x: 1, y: 1, width: size - 2, height: size - 2)
        let circle = NSBezierPath(ovalIn: bounds)

        if active {
            MonoPalette.text.setFill()
            circle.fill()
        } else {
            MonoPalette.textMuted.setStroke()
            circle.lineWidth = 2
            circle.stroke()
        }

        let pulse = NSBezierPath()
        pulse.move(to: NSPoint(x: 4, y: 9))
        pulse.line(to: NSPoint(x: 6.7, y: 9))
        pulse.line(to: NSPoint(x: 8.4, y: 12.7))
        pulse.line(to: NSPoint(x: 10.9, y: 5.4))
        pulse.line(to: NSPoint(x: 12.7, y: 9))
        pulse.line(to: NSPoint(x: 15, y: 9))
        (active ? NSColor.black.withAlphaComponent(0.86) : MonoPalette.textMuted).setStroke()
        pulse.lineWidth = 2.0
        pulse.lineCapStyle = .round
        pulse.lineJoinStyle = .round
        pulse.stroke()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    static func icon(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let bounds = NSRect(x: 0, y: 0, width: size, height: size)
        let outer = NSBezierPath(roundedRect: bounds.insetBy(dx: size * 0.06, dy: size * 0.06), xRadius: size * 0.18, yRadius: size * 0.18)
        NSGradient(colors: [
            NSColor(calibratedWhite: 0.30, alpha: 1.0),
            NSColor(calibratedWhite: 0.10, alpha: 1.0)
        ])?.draw(in: outer, angle: 270)

        MonoPalette.lineStrong.setStroke()
        outer.lineWidth = size * 0.018
        outer.stroke()

        let inner = NSBezierPath(roundedRect: bounds.insetBy(dx: size * 0.24, dy: size * 0.22), xRadius: size * 0.08, yRadius: size * 0.08)
        NSGradient(colors: [
            NSColor(calibratedWhite: 0.94, alpha: 1.0),
            NSColor(calibratedWhite: 0.64, alpha: 1.0)
        ])?.draw(in: inner, angle: 270)

        let pulse = NSBezierPath()
        pulse.move(to: NSPoint(x: size * 0.31, y: size * 0.50))
        pulse.line(to: NSPoint(x: size * 0.41, y: size * 0.50))
        pulse.line(to: NSPoint(x: size * 0.48, y: size * 0.64))
        pulse.line(to: NSPoint(x: size * 0.57, y: size * 0.36))
        pulse.line(to: NSPoint(x: size * 0.65, y: size * 0.50))
        pulse.line(to: NSPoint(x: size * 0.73, y: size * 0.50))
        NSColor.black.withAlphaComponent(0.84).setStroke()
        pulse.lineWidth = max(3, size * 0.045)
        pulse.lineCapStyle = .round
        pulse.lineJoinStyle = .round
        pulse.stroke()

        let text = "DS" as NSString
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let textRect = NSRect(x: size * 0.18, y: size * 0.08, width: size * 0.64, height: size * 0.22)
        text.draw(in: textRect, withAttributes: [
            .font: NSFont.systemFont(ofSize: size * 0.13, weight: .bold),
            .foregroundColor: NSColor.black.withAlphaComponent(0.68),
            .paragraphStyle: paragraph
        ])

        image.unlockFocus()
        return image
    }
}
