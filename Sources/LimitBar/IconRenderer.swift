import AppKit

enum IconRenderer {
    struct BarLevel: Equatable {
        let remaining: Double?   // 0…1; nil = нет данных
        let hot: Bool            // осталось < 10%
    }

    static func barLevels(_ states: [AccountState]) -> [BarLevel] {
        states.map { state in
            switch state {
            case .ok(let u, _), .stale(let u, _, _):
                let remaining = max(0, 1 - u.worstUtilization / 100)
                return BarLevel(remaining: remaining, hot: remaining < 0.10)
            case .failed, .pending:
                return BarLevel(remaining: nil, hot: false)
            }
        }
    }

    static func image(levels: [BarLevel]) -> NSImage {
        let barW: CGFloat = 3.5, gap: CGFloat = 2.5, barH: CGFloat = 15, canvasH: CGFloat = 18
        let count = max(levels.count, 1)
        let width = CGFloat(count) * barW + CGFloat(count - 1) * gap + 2
        let anyHot = levels.contains { $0.hot }
        let img = NSImage(size: NSSize(width: width, height: canvasH), flipped: false) { _ in
            let y = (canvasH - barH) / 2
            for (i, level) in levels.enumerated() {
                let x = 1 + CGFloat(i) * (barW + gap)
                let track = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: barW, height: barH),
                                         xRadius: barW / 2, yRadius: barW / 2)
                NSColor.black.withAlphaComponent(0.25).setFill()
                track.fill()
                if let remaining = level.remaining, remaining > 0 {
                    let h = max(barW, barH * remaining)   // минимум — «точка»
                    let fill = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: barW, height: h),
                                            xRadius: barW / 2, yRadius: barW / 2)
                    (level.hot ? NSColor.systemRed : NSColor.black).setFill()
                    fill.fill()
                }
            }
            return true
        }
        img.isTemplate = !anyHot
        return img
    }
}
