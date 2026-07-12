import SwiftUI
import AppKit

struct AccountRowView: View {
    let name: String
    let state: AccountState
    let kind: AccountKind
    var email: String? = nil
    var plan: String? = nil

    @State private var hovered = false

    // Дизайн «V2-B» (выбор владельца 12.07): одна строка, identity = email вместо
    // generic-имени (та же fallback-логика, что в тултипе менюбара), суффикс сервиса
    // обязателен — один email может быть и на Claude, и на Codex. Кольца убраны
    // (на 16pt дуга не читается) — окна показаны текстом, единственный цветной
    // акцент — процент. Полные слова («resets», тариф) — только в тултипах.
    private var serviceSuffix: String {
        switch kind {
        case .claudeMain, .claudeOAuth: return "Claude"
        case .codex: return "Codex"
        }
    }

    private var serviceLabel: String {
        switch kind {
        case .claudeMain, .claudeOAuth: return "Claude Code"
        case .codex: return "Codex"
        }
    }

    private var resolvedName: String {
        Account.defaultNames.contains(name) ? (email ?? name) : name
    }

    // «Claude · Claude» у дефолтного имени без email — дубль: суффикс различает
    // сервисы при одинаковых identity, а тут identity и есть имя сервиса.
    private var showsSuffix: Bool { resolvedName != serviceSuffix }

    private var identityHelp: String {
        var lines = [name, serviceLabel]
        if let plan, !plan.isEmpty { lines[1] += " · \(plan)" }
        if let email, !email.isEmpty { lines.append(email) }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            (Text(resolvedName)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(hovered ? Color.white : Color.primary)
             + Text(showsSuffix ? " · \(serviceSuffix)" : "")
                .font(.system(size: 11))
                .foregroundColor(hovered ? Color.white.opacity(0.85) : Color(nsColor: .secondaryLabelColor)))
                .lineLimit(1)
                .truncationMode(.middle)
                .help(identityHelp)
            if case .stale(_, _, let badge) = state {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 10)).foregroundStyle(.orange)
                    .help(badge)
            }
            // Identity гибкая, сегменты окон прижаты вправо: фиксированная ширина
            // выравнивает проценты и времена в столбцы между строками.
            Spacer(minLength: 12)
            switch state {
            case .pending:
                windows(usage: nil)
            case .failed(let badge):
                Label(badge, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11)).foregroundStyle(.orange)
            case .ok(let usage, _), .stale(let usage, _, _):
                windows(usage: usage)
            }
        }
        .padding(.horizontal, 12)
        .frame(width: MenuRowFactory.rowWidth, height: MenuRowFactory.rowHeight, alignment: .leading)
        // Нативная подсветка выделения: кастомные view-строки NSMenu сам не
        // подсвечивает — рисуем акцентный rounded-rect с инсетом 5pt, как у
        // системных пунктов; цвет — системный selection (следует за акцентом юзера).
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color(nsColor: .selectedContentBackgroundColor))
                .opacity(hovered ? 1 : 0)
                .padding(.horizontal, 5)
        )
        .onHover { hovered = $0 }
    }

    @ViewBuilder
    private func windows(usage: Usage?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            WindowSegment(label: "5h", window: usage?.fiveHour, hovered: hovered)
                .help(resetHelp(title: "5-hour window", window: usage?.fiveHour))
            WindowSegment(label: "7d", window: usage?.sevenDay, hovered: hovered)
                .help(resetHelp(title: "Weekly window", window: usage?.sevenDay))
        }
    }

    /// Multi-line tooltip: "<title>\n<used>% used · <left>% left\nResets <abs> (<rel>)".
    private func resetHelp(title: String, window: UsageWindow?) -> String {
        guard let window else { return "\(title)\nNo data" }
        let used = Int(window.utilization)
        let remaining = 100 - used
        var lines = [title, "\(used)% used · \(remaining)% left"]
        if let resetsAt = window.resetsAt, let absolute = ResetClock.label(resetsAt) {
            let rel = RelativeDateTimeFormatter(); rel.unitsStyle = .full
            lines.append("Resets \(absolute) (\(rel.localizedString(for: resetsAt, relativeTo: .now)))")
        }
        if let projected = window.projectedExhaustion, let label = ResetClock.label(projected) {
            lines.append("At this pace, hits 100% ~\(label)")
        }
        return lines.joined(separator: "\n")
    }
}

/// Абсолютное время сброса окна: сегодня — «19:00», иначе — «Tu 09:00»
/// (двухбуквенный день, локале-зависимые форматы). Владелец 11.07: конкретное
/// время полезнее, чем «через сколько часов», — показываем его всегда.
enum ResetClock {
    static func label(_ date: Date?, now: Date = .now, calendar: Calendar = .current) -> String? {
        guard let date else { return nil }
        if date <= now { return "now" }
        let f = DateFormatter()
        f.timeZone = calendar.timeZone
        if calendar.isDate(date, inSameDayAs: now) {
            f.setLocalizedDateFormatFromTemplate("jm")
        } else {
            f.setLocalizedDateFormatFromTemplate("EEEEEE jm")
        }
        return f.string(from: date)
    }
}

/// Текстовый сегмент окна: «5h 62% · 19:04». Метка окна — тихая (tertiary),
/// процент — единственный цветной акцент строки (≥90 красный, ≥70 оранжевый,
/// иначе зелёный; semibold + tabular, чтобы столбцы не плясали). Время голое —
/// позиция после процента сама объясняет, что это сброс; burn-rate прогноз
/// вытесняет его оранжевым «full 17:30» (умрёт раньше, чем сбросится).
/// `window == nil` — нет данных: «5h —».
private struct WindowSegment: View {
    let label: String
    let window: UsageWindow?
    var hovered: Bool = false

    private static let width: CGFloat = 112

    private var percentColor: Color {
        if hovered { return .white }
        let util = window?.utilization ?? 0
        if util >= 90 { return Color(nsColor: .systemRed) }
        if util >= 70 { return Color(nsColor: .systemOrange) }
        return Color(nsColor: .systemGreen)
    }

    // На выделенной (синей) строке серые/цветные элементы теряют контраст —
    // на hover весь сегмент уходит в белый разной плотности.
    private var labelColor: Color { hovered ? .white.opacity(0.75) : Color(nsColor: .tertiaryLabelColor) }

    private var projected: Bool {
        guard let window else { return false }
        return window.utilization <= 99 && window.projectedExhaustion != nil
    }

    private var timeText: String {
        guard let window else { return "" }
        if projected, let time = ResetClock.label(window.projectedExhaustion) {
            return "full \(time)"
        }
        return ResetClock.label(window.resetsAt) ?? ""
    }

    private var timeColor: Color {
        if hovered { return .white.opacity(0.85) }
        if projected { return Color(nsColor: .systemOrange) }
        return Color(nsColor: .secondaryLabelColor)
    }

    var body: some View {
        (Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(labelColor)
         + Text(window.map { " \(Int($0.utilization))%" } ?? " —")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(window == nil ? labelColor : percentColor)
         + Text(timeText.isEmpty ? "" : " · \(timeText)")
            .font(.system(size: 11))
            .foregroundColor(timeColor))
            .monospacedDigit()
            .lineLimit(1)
            .frame(width: Self.width, alignment: .leading)
    }
}

enum MenuRowFactory {
    static let rowWidth: CGFloat = 400
    // Одна текстовая строка 12.5pt + по ~5pt воздуха сверху/снизу (V2-B,
    // выбор владельца 12.07 — ниже и плотнее двухстрочного варианта).
    static let rowHeight: CGFloat = 25

    static func item(for account: Account, state: AccountState) -> NSMenuItem {
        let item = NSMenuItem()
        let row = AccountRowView(name: account.name, state: state, kind: account.kind,
                                  email: account.email, plan: account.plan)
        let host = NSHostingView(rootView: row)
        // Disable NSHostingView's own intrinsic-size layout so it can't leave stale sizing
        // slack in the parent NSMenu window (the "gap after Quit" gotcha). macOS 13+.
        host.sizingOptions = []
        host.frame = NSRect(x: 0, y: 0, width: rowWidth, height: rowHeight)
        item.view = host
        item.representedObject = account.id
        return item
    }
}
