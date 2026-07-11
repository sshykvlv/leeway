import Foundation
import UserNotifications

/// Одно событие, требующее уведомления пользователя: окно пересекло порог
/// использования или явно сбросилось после высокого расхода.
struct AlertEvent: Equatable {
    enum Kind: Equatable { case threshold(Int); case reset }  // threshold 80 или 90
    let accountName: String
    let windowLabel: String   // "5h" | "7d"
    let utilization: Int      // текущее значение, для текста уведомления
    let resetsAt: Date?
    let kind: Kind
}

/// Чистый движок без побочных эффектов (тестируется без UserNotifications).
/// Хранит последнее увиденное значение utilization по ключу accountID+windowLabel
/// и решает, какое событие (если есть) породил переход от старого значения к новому.
final class AlertEngine {
    private struct Key: Hashable { let accountID: UUID; let windowLabel: String }
    private var lastSeen: [Key: Double] = [:]

    /// Вызывается после каждого успешного опроса аккаунта. Возвращает события,
    /// которые нужно доставить пользователю (может быть пусто).
    func process(accountID: UUID, accountName: String, usage: Usage) -> [AlertEvent] {
        var events: [AlertEvent] = []
        if let window = usage.fiveHour {
            events += processWindow(accountID: accountID, accountName: accountName,
                                     windowLabel: "5h", window: window)
        }
        if let window = usage.sevenDay {
            events += processWindow(accountID: accountID, accountName: accountName,
                                     windowLabel: "7d", window: window)
        }
        return events
    }

    private func processWindow(accountID: UUID, accountName: String, windowLabel: String,
                                window: UsageWindow) -> [AlertEvent] {
        let key = Key(accountID: accountID, windowLabel: windowLabel)
        let new = window.utilization
        defer { lastSeen[key] = new }

        // Первое наблюдение этого ключа: просто запоминаем значение, ничего не шлём —
        // иначе при запуске приложения с уже высоким usage поймали бы шторм уведомлений.
        guard let previous = lastSeen[key] else { return [] }

        // Большой провал = окно перекатилось (сброс). .reset шлём только если предыдущее
        // значение было тревожным (>= 80) — иначе это молчаливый ре-арм порогов, никому
        // не интересно что почти неиспользуемое окно сбросилось.
        if new < previous - 30 {
            if previous >= 80 {
                return [AlertEvent(accountName: accountName, windowLabel: windowLabel,
                                    utilization: Int(new), resetsAt: window.resetsAt, kind: .reset)]
            }
            return []
        }

        // Пересечение порога: если прыгнули через оба (напр. 70→95), шлём только более
        // срочный (90) — одно уведомление, не два.
        if previous < 90, new >= 90 {
            return [AlertEvent(accountName: accountName, windowLabel: windowLabel,
                                utilization: Int(new), resetsAt: window.resetsAt, kind: .threshold(90))]
        }
        if previous < 80, new >= 80 {
            return [AlertEvent(accountName: accountName, windowLabel: windowLabel,
                                utilization: Int(new), resetsAt: window.resetsAt, kind: .threshold(80))]
        }
        return []
    }
}

/// Доставка через UserNotifications — тонкая обвязка, не тестируется юнит-тестами.
/// Bundle.main.bundleIdentifier == nil в голом SPM-экзекьютабле/тестах — там у
/// UNUserNotificationCenter.current() нет bundle и он падает, поэтому гвардим везде.
@MainActor
enum Notifier {
    static func requestAuthorization() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func deliver(_ events: [AlertEvent]) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let center = UNUserNotificationCenter.current()
        for event in events {
            let content = UNMutableNotificationContent()
            switch event.kind {
            case .threshold:
                content.title = "\(event.accountName): \(event.windowLabel) window \(event.utilization)% used"
                if let text = ResetClock.label(event.resetsAt) {
                    content.body = "Resets \(text)"
                }
            case .reset:
                content.title = "\(event.accountName): \(event.windowLabel) window reset"
                content.body = "Usage back to \(event.utilization)%"
            }
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            center.add(request)
        }
    }
}
