import XCTest
@testable import AIStatusBar

final class AlertEngineTests: XCTestCase {
    private let accountID = UUID()

    private func usage(_ fiveHour: Double?, _ sevenDay: Double? = nil) -> Usage {
        Usage(fiveHour: fiveHour.map { UsageWindow(utilization: $0, resetsAt: Date().addingTimeInterval(3600)) },
              sevenDay: sevenDay.map { UsageWindow(utilization: $0, resetsAt: Date().addingTimeInterval(86400)) })
    }

    func testFirstObservationEmitsNothingEvenAtHighUtilization() {
        let engine = AlertEngine()
        let events = engine.process(accountID: accountID, accountName: "Personal", usage: usage(95))
        XCTAssertTrue(events.isEmpty)
    }

    func test80PercentCrossingEmitsThreshold80() {
        let engine = AlertEngine()
        _ = engine.process(accountID: accountID, accountName: "Personal", usage: usage(70))
        let events = engine.process(accountID: accountID, accountName: "Personal", usage: usage(82))
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.kind, .threshold(80))
        XCTAssertEqual(events.first?.windowLabel, "5h")
        XCTAssertEqual(events.first?.utilization, 82)
    }

    func test90PercentCrossingEmitsThreshold90() {
        let engine = AlertEngine()
        _ = engine.process(accountID: accountID, accountName: "Personal", usage: usage(85))
        let events = engine.process(accountID: accountID, accountName: "Personal", usage: usage(91))
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.kind, .threshold(90))
    }

    func testJumpFrom70To95EmitsOnlyThreshold90() {
        let engine = AlertEngine()
        _ = engine.process(accountID: accountID, accountName: "Personal", usage: usage(70))
        let events = engine.process(accountID: accountID, accountName: "Personal", usage: usage(95))
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.kind, .threshold(90))
    }

    func testStayingAbove80AcrossPollsEmitsNothingAfterFirstCrossing() {
        let engine = AlertEngine()
        _ = engine.process(accountID: accountID, accountName: "Personal", usage: usage(70))
        let first = engine.process(accountID: accountID, accountName: "Personal", usage: usage(85))
        XCTAssertEqual(first.count, 1)
        let second = engine.process(accountID: accountID, accountName: "Personal", usage: usage(85))
        XCTAssertTrue(second.isEmpty)
        let third = engine.process(accountID: accountID, accountName: "Personal", usage: usage(86))
        XCTAssertTrue(third.isEmpty)
    }

    func testDropFrom95To5EmitsReset() {
        let engine = AlertEngine()
        _ = engine.process(accountID: accountID, accountName: "Personal", usage: usage(70))
        _ = engine.process(accountID: accountID, accountName: "Personal", usage: usage(95))
        let events = engine.process(accountID: accountID, accountName: "Personal", usage: usage(5))
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.kind, .reset)
        XCTAssertEqual(events.first?.utilization, 5)
    }

    func testDropFrom50To5EmitsNothing() {
        let engine = AlertEngine()
        _ = engine.process(accountID: accountID, accountName: "Personal", usage: usage(70))
        _ = engine.process(accountID: accountID, accountName: "Personal", usage: usage(50))
        let events = engine.process(accountID: accountID, accountName: "Personal", usage: usage(5))
        XCTAssertTrue(events.isEmpty)
    }

    func testAfterResetClimbingTo85EmitsThreshold80Again() {
        let engine = AlertEngine()
        _ = engine.process(accountID: accountID, accountName: "Personal", usage: usage(70))
        _ = engine.process(accountID: accountID, accountName: "Personal", usage: usage(95))
        _ = engine.process(accountID: accountID, accountName: "Personal", usage: usage(5))
        let events = engine.process(accountID: accountID, accountName: "Personal", usage: usage(85))
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.kind, .threshold(80))
    }

    func testFiveHourAndSevenDayWindowsTrackedIndependently() {
        let engine = AlertEngine()
        _ = engine.process(accountID: accountID, accountName: "Personal", usage: usage(70, 70))
        let events = engine.process(accountID: accountID, accountName: "Personal", usage: usage(82, 70))
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.windowLabel, "5h")

        let events2 = engine.process(accountID: accountID, accountName: "Personal", usage: usage(82, 91))
        XCTAssertEqual(events2.count, 1)
        XCTAssertEqual(events2.first?.windowLabel, "7d")
        XCTAssertEqual(events2.first?.kind, .threshold(90))
    }

    func testTwoAccountsTrackedIndependently() {
        let engine = AlertEngine()
        let other = UUID()
        _ = engine.process(accountID: accountID, accountName: "Personal", usage: usage(70))
        _ = engine.process(accountID: other, accountName: "Work", usage: usage(70))
        let eventsA = engine.process(accountID: accountID, accountName: "Personal", usage: usage(85))
        XCTAssertEqual(eventsA.count, 1)
        // Second account has not crossed yet — still at its first-crossing baseline of 70.
        let eventsB = engine.process(accountID: other, accountName: "Work", usage: usage(70))
        XCTAssertTrue(eventsB.isEmpty)
        let eventsB2 = engine.process(accountID: other, accountName: "Work", usage: usage(85))
        XCTAssertEqual(eventsB2.count, 1)
        XCTAssertEqual(eventsB2.first?.accountName, "Work")
    }
}
