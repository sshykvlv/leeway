import SwiftUI
import AppKit

struct AccountRowView: View {
    let name: String
    let state: AccountState
    let kind: AccountKind
    var email: String? = nil
    var plan: String? = nil

    @State private var hovered = false

    // Одна строка: identity = email вместо generic-имени (та же fallback-логика,
    // что в тултипе менюбара), суффикс сервиса — один email может быть и на
    // Claude, и на Codex. Кольца убраны (на 16pt дуга не читается). Правая часть —
    // «D2, только цифры», см. комментарий у windows(usage:). Полные слова
    // («resets», тариф) — только в тултипах.
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

    /// Полный тултип пункта меню. NSMenu во время трекинга подавляет view-тултипы
    /// (SwiftUI .help / NSView.toolTip) — работает только NSMenuItem.toolTip,
    /// поэтому вся детализация собирается одной простынёй на строку.
    static func toolTip(name: String, state: AccountState, kind: AccountKind,
                        email: String?, plan: String?) -> String {
        let serviceLabel: String
        switch kind {
        case .claudeMain, .claudeOAuth: serviceLabel = "Claude Code"
        case .codex: serviceLabel = "Codex"
        }
        var head = [name, serviceLabel]
        if let plan, !plan.isEmpty { head[1] += " · \(plan)" }
        if let email, !email.isEmpty { head.append(email) }
        var blocks = [head.joined(separator: "\n")]
        switch state {
        case .pending:
            blocks.append("Loading…")
        case .failed(let badge):
            blocks.append(badge)
        case .ok(let usage, _):
            blocks.append(windowHelp(title: "5-hour window", window: usage.fiveHour))
            blocks.append(windowHelp(title: "Weekly window", window: usage.sevenDay))
        case .stale(let usage, _, let badge):
            blocks.append(windowHelp(title: "5-hour window", window: usage.fiveHour))
            blocks.append(windowHelp(title: "Weekly window", window: usage.sevenDay))
            blocks.append("⚠ \(badge)")
        }
        return blocks.joined(separator: "\n\n")
    }

    /// Блок одного окна: "<title>\n<used>% used · <left>% left\nResets <abs> (<rel>)".
    private static func windowHelp(title: String, window: UsageWindow?) -> String {
        guard let window else { return "\(title)\nNo data" }
        let used = Int(window.utilization)
        var lines = [title, "\(used)% used · \(100 - used)% left"]
        if let resetsAt = window.resetsAt, let absolute = ResetClock.label(resetsAt) {
            let rel = RelativeDateTimeFormatter(); rel.unitsStyle = .full
            lines.append("Resets \(absolute) (\(rel.localizedString(for: resetsAt, relativeTo: .now)))")
        }
        if let projected = window.projectedExhaustion, let label = ResetClock.label(projected) {
            lines.append("At this pace, hits 100% ~\(label)")
        }
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
            if case .stale = state {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 10)).foregroundStyle(.orange)
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

    // Дизайн «D2 — только цифры» (выбор владельца 12.07 после листа минимализации):
    // два процента в колонках (слева всегда 5h, справа 7d) — и всё. Метки окон,
    // времена сброса и слова живут в тултипах. Исключения ровно два:
    // исчерпанное окно дописывает время возврата (главный вопрос в этот момент),
    // оранжевая молния = burn-rate прогноз (цифры выглядят спокойно, а окно
    // кончится до сброса). Красной молнии нет — исчерпание видно по 100%.
    @ViewBuilder
    private func windows(usage: Usage?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            PercentCell(window: usage?.fiveHour, hovered: hovered)
            PercentCell(window: usage?.sevenDay, hovered: hovered)
            boltSlot(usage: usage)
        }
        // Кластер окон не сжимается — при длинной identity усекается она, не цифры.
        .layoutPriority(1)
    }

    /// Ближайший burn-rate прогноз по неисчерпанным окнам — одна молния на строку.
    private func earliestForecast(_ usage: Usage?) -> Date? {
        guard let usage else { return nil }
        return [usage.fiveHour, usage.sevenDay]
            .compactMap { $0 }
            .filter { $0.utilization <= 99 }
            .compactMap(\.projectedExhaustion)
            .min()
    }

    // Слот фиксированной ширины и без молнии: правые края процентов совпадают
    // между строками независимо от того, у кого горит прогноз.
    @ViewBuilder
    private func boltSlot(usage: Usage?) -> some View {
        Group {
            if earliestForecast(usage) != nil {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(hovered ? Color.white : Color(nsColor: .systemOrange))
            }
        }
        .frame(width: 16, alignment: .trailing)
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

/// Колонка-процент одного окна: голая цифра, окрашенная порогом — серая пока
/// спокойно (<70), оранжевая ≥70, красная ≥90 (semibold + tabular, чтобы
/// столбцы не плясали). Исчерпанное окно (>99%) — единственное, кому цифры
/// мало: дописывает время возврата «100% · 13:44». `window == nil` — «—».
/// minWidth держит колонки ровными между строками при 1–3 значных процентах.
private struct PercentCell: View {
    let window: UsageWindow?
    var hovered: Bool = false

    private var exhausted: Bool { (window?.utilization ?? 0) > 99 }

    private var percentColor: Color {
        if hovered { return .white }
        guard let util = window?.utilization else { return Color(nsColor: .tertiaryLabelColor) }
        if util >= 90 { return Color(nsColor: .systemRed) }
        if util >= 70 { return Color(nsColor: .systemOrange) }
        return Color(nsColor: .secondaryLabelColor)
    }

    private var resetSuffix: String {
        guard exhausted, let time = ResetClock.label(window?.resetsAt) else { return "" }
        return " · \(time)"
    }

    var body: some View {
        (Text(window.map { "\(Int($0.utilization))%" } ?? "—")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(percentColor)
         + Text(resetSuffix)
            .font(.system(size: 11))
            // На выделенной (синей) строке серые тексты теряют контраст — в белый.
            .foregroundColor(hovered ? .white.opacity(0.85) : Color(nsColor: .secondaryLabelColor)))
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
            .frame(minWidth: 44, alignment: .trailing)
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
        // Вся детализация — здесь: view-тултипы внутри NSMenu не показываются.
        item.toolTip = AccountRowView.toolTip(name: account.name, state: state, kind: account.kind,
                                              email: account.email, plan: account.plan)
        item.representedObject = account.id
        return item
    }
}
