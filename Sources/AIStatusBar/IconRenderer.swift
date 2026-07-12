import AppKit

enum IconRenderer {
    enum Severity: Equatable {
        case normal, warn, danger
    }

    struct BarLevel: Equatable {
        let used: Double?        // 0…1, доля израсходованного; nil = нет данных
        let severity: Severity
    }

    /// Один бар на аккаунт. Заполнение = израсходовано (worstUtilization), цвет по нему же:
    /// >90% → danger (красный), >70% → warn (жёлтый), иначе normal (зелёный).
    static func barLevels(_ states: [AccountState]) -> [BarLevel] {
        states.map { state in
            switch state {
            case .ok(let u, _), .stale(let u, _, _):
                let used = min(max(u.worstUtilization / 100, 0), 1)
                let severity: Severity
                if u.worstUtilization > 90 { severity = .danger }
                else if u.worstUtilization > 70 { severity = .warn }
                else { severity = .normal }
                return BarLevel(used: used, severity: severity)
            case .failed, .pending:
                return BarLevel(used: nil, severity: .normal)
            }
        }
    }

    /// Стиль менюбар-иконки (переключалка в меню, идея владельца 12.07).
    enum Style: String {
        case bars, rings
    }

    /// Читаемость вложенных колец на 18pt кончается на трёх: четвёртое кольцо —
    /// уже точка (проверено прототипом 12.07). Дальше честный фолбэк в бары.
    static let maxRings = 3

    static func image(levels: [BarLevel], style: Style = .bars) -> NSImage {
        if style == .rings, levels.count <= maxRings, !levels.isEmpty {
            return ringsImage(levels: levels)
        }
        return barsImage(levels: levels)
    }

    /// Вложенные кольца — кольцо на аккаунт (внешнее = первый аккаунт).
    /// Заполнение = израсходовано, от 12 часов по часовой; цвет по severity.
    private static func ringsImage(levels: [BarLevel]) -> NSImage {
        let canvas: CGFloat = 18
        let hasData = levels.contains { $0.used != nil }
        let img = NSImage(size: NSSize(width: canvas, height: canvas), flipped: false) { _ in
            let c = NSPoint(x: canvas / 2, y: canvas / 2)
            let maxR: CGFloat = canvas / 2 - 1
            let n = CGFloat(levels.count)
            let w = min(3.2, maxR / (n + 1.2))
            let gap = w * 0.5
            for (i, level) in levels.enumerated() {
                let r = maxR - CGFloat(i) * (w + gap) - w / 2
                guard r > w * 0.4 else { break }
                let track = NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                track.lineWidth = w
                NSColor(white: 1.0, alpha: 0.35).setStroke()
                track.stroke()
                if let used = level.used, used > 0 {
                    let arc = NSBezierPath()
                    arc.lineWidth = w
                    arc.lineCapStyle = .round
                    arc.appendArc(withCenter: c, radius: r,
                                  startAngle: 90, endAngle: 90 - 360 * min(used, 1), clockwise: true)
                    fillColor(for: level.severity).setStroke()
                    arc.stroke()
                }
            }
            return true
        }
        img.isTemplate = !hasData
        return img
    }

    private static func barsImage(levels: [BarLevel]) -> NSImage {
        // Столбик на аккаунт, высота = сколько израсходовано у этой модели (снизу вверх),
        // цвет — зелёный/жёлтый/красный по уровню. Никаких цифр: столбики сами показывают
        // реальный статус каждой модели.
        let barW: CGFloat = 3, gap: CGFloat = 2, barH: CGFloat = 15, canvasH: CGFloat = 18
        let count = max(levels.count, 1)
        let width = CGFloat(count) * barW + CGFloat(count - 1) * gap + 2
        // Template оставляем только когда данных нет вовсе (пустой значок).
        let hasData = levels.contains { $0.used != nil }
        let img = NSImage(size: NSSize(width: width, height: canvasH), flipped: false) { _ in
            let y = (canvasH - barH) / 2
            for (i, level) in levels.enumerated() {
                let x = 1 + CGFloat(i) * (barW + gap)
                let track = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: barW, height: barH),
                                         xRadius: barW / 2, yRadius: barW / 2)
                // Белая подложка столбика (фидбэк владельца 11.07).
                NSColor(white: 1.0, alpha: 0.5).setFill()
                track.fill()
                if let used = level.used {
                    let h = used > 0 ? max(barW, barH * used) : 0   // минимум — «точка», 0% — пусто
                    if h > 0 {
                        let fill = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: barW, height: h),
                                                xRadius: barW / 2, yRadius: barW / 2)
                        fillColor(for: level.severity).setFill()
                        fill.fill()
                    }
                }
            }
            return true
        }
        img.isTemplate = !hasData
        return img
    }

    private static func fillColor(for severity: Severity) -> NSColor {
        switch severity {
        case .danger: return .systemRed
        case .warn: return .systemYellow
        case .normal: return .systemGreen
        }
    }
}
