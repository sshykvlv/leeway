import Foundation

struct UsageWindow: Equatable {
    let utilization: Double      // 0…100, сколько ИЗРАСХОДОВАНО
    let resetsAt: Date?
    // Прогноз момента исчерпания (100%) при текущем темпе — заполняется Poller'ом
    // только когда он наступает раньше resetsAt (см. BurnRate.swift). Default сохраняет
    // все существующие вызовы UsageWindow(utilization:resetsAt:) компилируемыми.
    var projectedExhaustion: Date? = nil
}

struct Usage: Equatable {
    let fiveHour: UsageWindow?
    let sevenDay: UsageWindow?
    var worstUtilization: Double {
        max(fiveHour?.utilization ?? 0, sevenDay?.utilization ?? 0)
    }
}

enum AccountKind: String, Codable { case claudeMain, claudeOAuth, codex }

struct Account: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    let kind: AccountKind
    var email: String?
    var plan: String? = nil
    /// Для дополнительных Codex-аккаунтов — путь к их CODEX_HOME (папке с auth.json).
    /// nil = основной автоподхваченный Codex (использует ~/.codex по умолчанию).
    var codexHome: String? = nil
    /// Для дополнительных Claude CLI-профилей — путь к их CLAUDE_CONFIG_DIR.
    /// Claude Code кладёт креды такого профиля в Keychain-сервис с hash-суффиксом
    /// от этого пути (см. KeychainStore.claudeCodeService). nil = основной ~/.claude.
    var claudeConfigDir: String? = nil

    /// Names an owner never customized, used as a fallback signal that a row's
    /// email (once fetched) is more informative than its generic default name.
    /// Shared by the menubar tooltip and the menu rows. "Claude 2" (the default
    /// name for a second CLI profile) is deliberately excluded: it already
    /// disambiguates from the main account, while its email usually doesn't
    /// (same owner logged into two subscriptions) — falling back to email here
    /// used to make both rows render as identical, indistinguishable text.
    static let defaultNames: Set<String> = ["Claude", "Codex"]
}

enum AccountState: Equatable {
    case pending                                   // ещё не опрашивали
    case ok(Usage, fetchedAt: Date)
    case stale(Usage, fetchedAt: Date, badge: String) // старые данные + бейдж
    case failed(badge: String)                     // данных нет
}

enum FetchError: Error, Equatable {
    case unauthorized        // 401/403 — токен протух/нет scope
    case rateLimited         // 429
    case network(String)
    case badResponse(String)
}

import AppKit

extension NSColor {
    /// Warn-оранжевый порогов: в тёмной теме — systemOrange, в светлой — более
    /// глубокий янтарный (фидбэк владельца 13.07: systemOrange на светлом фоне
    /// чипа читается слабо). Динамический — резолвится по appearance при отрисовке.
    static let asbWarn = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? .systemOrange
            : NSColor(srgbRed: 0.72, green: 0.40, blue: 0.0, alpha: 1.0)
    }
}
