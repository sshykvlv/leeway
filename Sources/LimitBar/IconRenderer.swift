import AppKit

enum IconRenderer {
    enum Severity: Equatable {
        case normal, warn, danger
    }

    struct BarLevel: Equatable {
        let remaining: Double?   // 0…1; nil = нет данных
        let severity: Severity
    }

    /// Severity — по худшему окну (worstUtilization): >90% использовано → danger,
    /// >70% → warn, иначе normal. danger по сути покрывает старый "hot" (<10% remaining).
    static func barLevels(_ states: [AccountState]) -> [BarLevel] {
        states.map { state in
            switch state {
            case .ok(let u, _), .stale(let u, _, _):
                let remaining = max(0, 1 - u.worstUtilization / 100)
                let severity: Severity
                if u.worstUtilization > 90 { severity = .danger }
                else if u.worstUtilization > 70 { severity = .warn }
                else { severity = .normal }
                return BarLevel(remaining: remaining, severity: severity)
            case .failed, .pending:
                return BarLevel(remaining: nil, severity: .normal)
            }
        }
    }

    static func image(levels: [BarLevel]) -> NSImage {
        // Бар на аккаунт (заполнение = остаток) + цифра ХУДШЕГО остатка рядом —
        // «сколько осталось» читается числом, бары дают текстуру по аккаунтам
        // (фидбэк владельца 11.07: уровень на тонких барах не считывался).
        let barW: CGFloat = 3, gap: CGFloat = 2, barH: CGFloat = 15, canvasH: CGFloat = 18
        let count = max(levels.count, 1)
        let barsW = CGFloat(count) * barW + CGFloat(count - 1) * gap + 2
        // Худший (минимальный) остаток среди аккаунтов с данными — именно он решает,
        // можно ли запускать тяжёлую задачу прямо сейчас.
        let worst = levels.compactMap { lvl in lvl.remaining.map { ($0, lvl.severity) } }
            .min { $0.0 < $1.0 }
        let label: NSAttributedString? = worst.map { remaining, severity in
            NSAttributedString(string: "\(Int((remaining * 100).rounded()))%", attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: fillColor(for: severity),
            ])
        }
        let labelW = label.map { ceil($0.size().width) + 3 } ?? 0
        let width = barsW + labelW
        // Цветовое кодирование (зелёный/жёлтый/красный) — картинка всегда цветная,
        // template оставляем только когда данных нет вовсе (пустой значок).
        let hasData = levels.contains { $0.remaining != nil }
        let img = NSImage(size: NSSize(width: width, height: canvasH), flipped: false) { _ in
            let y = (canvasH - barH) / 2
            for (i, level) in levels.enumerated() {
                let x = 1 + CGFloat(i) * (barW + gap)
                let track = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: barW, height: barH),
                                         xRadius: barW / 2, yRadius: barW / 2)
                // Нейтральный трек, читаемый и на светлой, и на тёмной строке меню.
                NSColor(white: 0.5, alpha: 0.35).setFill()
                track.fill()
                if let remaining = level.remaining, remaining > 0 {
                    let h = max(barW, barH * remaining)   // минимум — «точка»
                    let fill = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: barW, height: h),
                                            xRadius: barW / 2, yRadius: barW / 2)
                    fillColor(for: level.severity).setFill()
                    fill.fill()
                }
            }
            if let label {
                let size = label.size()
                label.draw(at: NSPoint(x: barsW + 1, y: (canvasH - size.height) / 2))
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
