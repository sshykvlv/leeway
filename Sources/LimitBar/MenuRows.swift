import SwiftUI
import AppKit

struct AccountRowView: View {
    let name: String
    let state: AccountState

    var body: some View {
        HStack(spacing: 10) {
            Text(name)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .frame(width: 92, alignment: .leading)
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
        .frame(width: 300, height: 30, alignment: .leading)
    }

    @ViewBuilder
    private func windowGauge(_ label: String, _ window: UsageWindow?) -> some View {
        HStack(spacing: 5) {
            Text(label).font(.system(size: 10)).foregroundStyle(.tertiary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule().fill(barColor(window?.utilization ?? 0))
                        .frame(width: geo.size.width * min((window?.utilization ?? 0) / 100, 1))
                }
            }
            .frame(width: 46, height: 5)
            Text(window.map { "\(Int($0.utilization))%" } ?? "—")
                .font(.system(size: 11).monospacedDigit())
                .frame(width: 34, alignment: .trailing)
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
    static func item(for account: Account, state: AccountState) -> NSMenuItem {
        let item = NSMenuItem()
        let host = NSHostingView(rootView: AccountRowView(name: account.name, state: state))
        host.frame = NSRect(x: 0, y: 0, width: 300, height: 30)
        item.view = host
        item.representedObject = account.id
        return item
    }
}
