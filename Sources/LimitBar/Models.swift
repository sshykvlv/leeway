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
