import SwiftUI
import AppKit

struct AccountRowView: View {
    let name: String
    let state: AccountState
    let kind: AccountKind
    var email: String? = nil
    var plan: String? = nil

    private var providerIcon: String {
        switch kind {
        case .claudeMain, .claudeOAuth: return "sparkles"
        case .codex: return "chevron.left.forwardslash.chevron.right"
        }
    }

    private var secondaryLine: String? {
        guard let email, !email.isEmpty else { return nil }
        if let plan, !plan.isEmpty { return "\(email) · \(plan)" }
        return email
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: providerIcon)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                if let secondaryLine {
                    Text(secondaryLine)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 90, alignment: .leading)
            switch state {
            case .pending:
                Spacer(minLength: 6)
                HStack(spacing: 10) {
                    ringGauge(title: "5-hour window", caption: "5h", window: nil)
                    ringGauge(title: "Weekly window", caption: "7d", window: nil)
                }
            case .failed(let badge):
                Label(badge, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11)).foregroundStyle(.orange)
                Spacer()
            case .ok(let usage, _), .stale(let usage, _, _):
                Spacer(minLength: 6)
                HStack(spacing: 10) {
                    ringGauge(title: "5-hour window", caption: "5h", window: usage.fiveHour)
                    ringGauge(title: "Weekly window", caption: "7d", window: usage.sevenDay)
                }
                if case .stale(_, _, let badge) = state {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10)).foregroundStyle(.orange)
                        .help(badge)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(width: MenuRowFactory.rowWidth, height: MenuRowFactory.rowHeight, alignment: .leading)
    }

    /// One ring gauge (utilization ring + numeric center + window caption) plus its
    /// detailed hover tooltip. `window == nil` renders a faint empty track with "—".
    @ViewBuilder
    private func ringGauge(title: String, caption: String, window: UsageWindow?) -> some View {
        RingGauge(value: window?.utilization, caption: caption,
                  color: gaugeColor(window?.utilization ?? 0))
            .help(resetHelp(title: title, window: window))
    }

    private func gaugeColor(_ utilization: Double) -> Color {
        if utilization > 90 { return Color(nsColor: .systemRed) }
        if utilization > 70 { return Color(nsColor: .systemYellow) }
        return Color(nsColor: .secondaryLabelColor)
    }

    /// Multi-line tooltip: "<title>\n<used>% used · <left>% left\nResets <abs> (<rel>)".
    /// The "Resets" line is omitted when `resetsAt` is nil; the whole body collapses to
    /// "<title>\nNo data" when there's no window at all for this account.
    private func resetHelp(title: String, window: UsageWindow?) -> String {
        guard let window else { return "\(title)\nNo data" }
        let used = Int(window.utilization)
        let remaining = 100 - used
        var lines = [title, "\(used)% used · \(remaining)% left"]
        if let resetsAt = window.resetsAt {
            let absolute: String
            if Calendar.current.isDateInToday(resetsAt) {
                let f = DateFormatter()
                f.dateStyle = .none
                f.timeStyle = .short
                absolute = f.string(from: resetsAt)
            } else {
                let f = DateFormatter()
                f.dateFormat = "EEE HH:mm"
                absolute = f.string(from: resetsAt)
            }
            let rel = RelativeDateTimeFormatter()
            rel.unitsStyle = .full
            let relative = rel.localizedString(for: resetsAt, relativeTo: .now)
            lines.append("Resets \(absolute) (\(relative))")
        }
        return lines.joined(separator: "\n")
    }
}

/// A small circular utilization ring: faint background track + a clockwise-filling
/// foreground arc starting at 12 o'clock, with the percentage centered and a tiny
/// window-label caption underneath. `value == nil` means "no data" — only the faint
/// track and a "—" are drawn, no foreground arc.
private struct RingGauge: View {
    let value: Double?
    let caption: String
    let color: Color

    private static let diameter: CGFloat = 26
    private static let lineWidth: CGFloat = 3.5

    private var fraction: Double {
        guard let value else { return 0 }
        return min(max(value / 100, 0), 1)
    }

    var body: some View {
        VStack(spacing: 1) {
            ZStack {
                Circle()
                    .stroke(Color(nsColor: .quaternaryLabelColor), lineWidth: Self.lineWidth)
                if value != nil {
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(color, style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                Text(value.map { "\(Int($0))" } ?? "—")
                    .font(.system(size: 9.5, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .frame(width: Self.diameter, height: Self.diameter)
            Text(caption)
                .font(.system(size: 8.5))
                .foregroundStyle(.tertiary)
        }
    }
}

enum MenuRowFactory {
    // Width budget (padding 12·2 + icon ~16 + spacing 10 + name/email column 90 + spacing 10
    // + flexible Spacer + two 26pt rings with 10pt gap between them (62) + spacing 10 +
    // stale-badge icon ~10 in the worst case) bottoms out around 248pt; 300pt leaves the
    // Spacer comfortable slack so the rings sit flush against the right padding without
    // ever clipping.
    static let rowWidth: CGFloat = 300
    // Height budget: the ring block is the tallest element — 26pt ring + 1pt spacing +
    // an 8.5pt caption (~10pt line height) ≈ 37pt — vs. the two-line text column
    // (~13pt name + 1pt spacing + ~10pt secondary ≈ 29pt). Add ~2.5pt of padding above
    // and below the taller ring block and round to 42pt.
    static let rowHeight: CGFloat = 42

    static func item(for account: Account, state: AccountState) -> NSMenuItem {
        let item = NSMenuItem()
        let row = AccountRowView(name: account.name, state: state, kind: account.kind,
                                  email: account.email, plan: account.plan)
        let host = NSHostingView(rootView: row)
        // Disable NSHostingView's own intrinsic-size layout pass so it can't grow/shrink
        // past the explicit frame we set below after SwiftUI's first layout pass — a
        // known NSHostingView-as-NSMenuItem.view gotcha that leaves stale sizing slack
        // in the parent NSMenu's window. Available since macOS 13; this package targets 14+.
        host.sizingOptions = []
        host.frame = NSRect(x: 0, y: 0, width: rowWidth, height: rowHeight)
        item.view = host
        item.representedObject = account.id
        return item
    }
}
