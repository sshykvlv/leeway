import XCTest
@testable import AIStatusBar

final class KeychainServiceTests: XCTestCase {
    func testDefaultProfileUsesPlainService() {
        XCTAssertEqual(KeychainStore.claudeCodeService(configDir: nil), "Claude Code-credentials")
    }

    func testSecondaryProfileAppendsSha256Prefix8() {
        // Суффикс = первые 8 hex SHA-256 от пути конфиг-папки (как считает сам Claude Code).
        // printf %s "/tmp/claude-profile" | shasum -a 256 → 7182514b…
        XCTAssertEqual(KeychainStore.claudeCodeService(configDir: "/tmp/claude-profile"),
                       "Claude Code-credentials-7182514b")
    }

    func testDifferentDirsGetDifferentServices() {
        XCTAssertNotEqual(KeychainStore.claudeCodeService(configDir: "/a"),
                          KeychainStore.claudeCodeService(configDir: "/b"))
    }
}
