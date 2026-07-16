import XCTest
@testable import AIStatusBar

/// Regression coverage for the "sasha@ykv.lv · Claude" duplicate-row bug: a
/// second CLI profile account (default name "Claude 2") shares its owner's
/// email with the main account, so falling back to email for both rows made
/// them render as identical, indistinguishable text.
final class IdentityTests: XCTestCase {
    func testClaude2KeepsItsOwnNameEvenWithKnownEmail() {
        XCTAssertEqual(AccountRowView.resolvedName(name: "Claude 2", email: "sasha@ykv.lv"), "Claude 2")
    }

    func testMainAccountStillPrefersEmailOverGenericName() {
        XCTAssertEqual(AccountRowView.resolvedName(name: "Claude", email: "sasha@ykv.lv"), "sasha@ykv.lv")
    }

    func testTwoAccountsSharingAnEmailResolveToDifferentIdentities() {
        let main = AccountRowView.resolvedName(name: "Claude", email: "sasha@ykv.lv")
        let secondProfile = AccountRowView.resolvedName(name: "Claude 2", email: "sasha@ykv.lv")
        XCTAssertNotEqual(main, secondProfile)
    }

    func testDefaultNamesExcludesClaude2() {
        XCTAssertFalse(Account.defaultNames.contains("Claude 2"))
    }
}
