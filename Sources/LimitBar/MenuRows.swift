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
        HStack(spacing: 10) {
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
                Text("…").foregroundStyle(.secondary)
                Spacer()
            case .failed(let badge):
                Label(badge, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11)).foregroundStyle(.orange)
                Spacer()
            case .ok(let usage, _), .stale(let usage, _, _):
                windowGauge("5h", usage.fiveHour)
                windowGauge("7d", usage.sevenDay)
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

    @ViewBuilder
    private func windowGauge(_ label: String, _ window: UsageWindow?) -> some View {
        HStack(spacing: 5) {
            Text(label).font(.system(size: 10)).foregroundStyle(.tertiary)
                .frame(width: 14, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule().fill(barColor(window?.utilization ?? 0))
                        .frame(width: geo.size.width * min((window?.utilization ?? 0) / 100, 1))
                }
            }
            .frame(width: 39, height: 5)
            Text(window.map { "\(Int($0.utilization))%" } ?? "—")
                .font(.system(size: 11).monospacedDigit())
                .frame(width: 28, alignment: .trailing)
        }
        .help(resetHelp(window))
    }

    private func barColor(_ utilization: Double) -> Color {
        if utilization > 90 { return Color(nsColor: .systemRed) }
        if utilization > 70 { return Color(nsColor: .systemYellow) }
        return Color(nsColor: .secondaryLabelColor)
    }

    private func resetHelp(_ window: UsageWindow?) -> String {
        guard let resets = window?.resetsAt else { return "" }
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .short
        return "resets \(f.localizedString(for: resets, relativeTo: .now))"
    }
}

enum MenuRowFactory {
    static let rowWidth: CGFloat = 340
    static let rowHeight: CGFloat = 40

    static func item(for account: Account, state: AccountState) -> NSMenuItem {
        let item = NSMenuItem()
        let row = AccountRowView(name: account.name, state: state, kind: account.kind,
                                  email: account.email, plan: account.plan)
        let host = NSHostingView(rootView: row)
        host.frame = NSRect(x: 0, y: 0, width: rowWidth, height: rowHeight)
        item.view = host
        item.representedObject = account.id
        return item
    }
}
