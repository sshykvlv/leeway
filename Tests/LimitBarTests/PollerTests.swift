import XCTest
@testable import LimitBar

final class PollerTests: XCTestCase {
    func testBackoffScheduleShape() {
        XCTAssertEqual(Poller.backoffSchedule, [120, 240, 480, 900])
        XCTAssertEqual(Poller.interval, 60)
    }

    func testWorstUtilizationTakesMax() {
        let u = Usage(fiveHour: .init(utilization: 30, resetsAt: nil),
                      sevenDay: .init(utilization: 80, resetsAt: nil))
        XCTAssertEqual(u.worstUtilization, 80)
    }
}

final class AccountStoreTests: XCTestCase {
    private func ephemeralDefaults() -> UserDefaults {
        let d = UserDefaults(suiteName: "limitbar.test.\(UUID().uuidString)")!
        return d
    }

    func testDiscoversNoBuiltinsWhenAbsent() {
        let store = AccountStore(defaults: ephemeralDefaults(),
                                 hasClaudeMain: { false }, hasCodex: { false })
        XCTAssertTrue(store.accounts.isEmpty)
    }

    func testDiscoversClaudeMainAndCodex() {
        let store = AccountStore(defaults: ephemeralDefaults(),
                                 hasClaudeMain: { true }, hasCodex: { true })
        XCTAssertEqual(store.accounts.first?.kind, .claudeMain)
        XCTAssertEqual(store.accounts.last?.kind, .codex)
    }

    func testAddKeepsCodexLast() {
        let store = AccountStore(defaults: ephemeralDefaults(),
                                 hasClaudeMain: { false }, hasCodex: { true })
        store.add(Account(id: UUID(), name: "Claude 2", kind: .claudeOAuth, email: nil))
        XCTAssertEqual(store.accounts.last?.kind, .codex)
        XCTAssertEqual(store.accounts.first?.kind, .claudeOAuth)
    }

    func testPersistenceRoundtrip() {
        let d = ephemeralDefaults()
        let store1 = AccountStore(defaults: d, hasClaudeMain: { false }, hasCodex: { false })
        let id = UUID()
        store1.add(Account(id: id, name: "Extra", kind: .claudeOAuth, email: "a@b.c"))
        let store2 = AccountStore(defaults: d, hasClaudeMain: { false }, hasCodex: { false })
        XCTAssertEqual(store2.accounts.first(where: { $0.id == id })?.name, "Extra")
    }

    func testRenameAndRemove() {
        let store = AccountStore(defaults: ephemeralDefaults(),
                                 hasClaudeMain: { false }, hasCodex: { false })
        let id = UUID()
        store.add(Account(id: id, name: "Old", kind: .claudeOAuth, email: nil))
        store.rename(id: id, to: "New")
        XCTAssertEqual(store.accounts.first?.name, "New")
        store.remove(id: id)
        XCTAssertTrue(store.accounts.isEmpty)
    }

    func testSetEmailPersistsEmailAndPlan() {
        let store = AccountStore(defaults: ephemeralDefaults(),
                                 hasClaudeMain: { false }, hasCodex: { false })
        let id = UUID()
        store.add(Account(id: id, name: "Claude", kind: .claudeMain, email: nil))
        store.setEmail(id: id, "sasha@ykv.lv", plan: "Max 20x")
        XCTAssertEqual(store.accounts.first?.email, "sasha@ykv.lv")
        XCTAssertEqual(store.accounts.first?.plan, "Max 20x")
    }

    func testRemovingBuiltinDismissesItPermanently() throws {
        let defaults = ephemeralDefaults()
        let store1 = AccountStore(defaults: defaults, hasClaudeMain: { true }, hasCodex: { false })
        let id = try XCTUnwrap(store1.accounts.first(where: { $0.kind == .claudeMain })?.id)
        store1.remove(id: id)
        XCTAssertTrue(store1.accounts.isEmpty)
        // Restart with the same "builtin present" signal — dismissal must stick.
        let store2 = AccountStore(defaults: defaults, hasClaudeMain: { true }, hasCodex: { false })
        XCTAssertFalse(store2.accounts.contains { $0.kind == .claudeMain })
    }
}
