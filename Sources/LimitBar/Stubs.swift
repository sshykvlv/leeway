import AppKit

// Заглушки — реальные реализации в Task 11 (OAuth) и Task 12 (Updates).
@MainActor
final class OAuthFlow {
    static let shared = OAuthFlow()
    func start(store: AccountStore, reloginID: UUID? = nil, onDone: @escaping () -> Void) {
        NSSound.beep()  // TODO(Task 11): real OAuth PKCE flow
    }
}

enum Updates {
    static func check(announce: Bool) {
        NSWorkspace.shared.open(URL(string: "https://github.com/sashayakovlev/limitbar/releases")!)
    }
}
