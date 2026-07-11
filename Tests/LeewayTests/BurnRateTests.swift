import XCTest
@testable import Leeway

final class BurnRateEstimatorTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    func testSteadyClimbProjectsExhaustionAboutOneHourOut() {
        let estimator = BurnRateEstimator()
        estimator.record(key: "a:5h", utilization: 40, at: base)
        estimator.record(key: "a:5h", utilization: 50, at: base.addingTimeInterval(15 * 60))
        estimator.record(key: "a:5h", utilization: 60, at: base.addingTimeInterval(30 * 60))
        let now = base.addingTimeInterval(30 * 60)
        let projected = estimator.projectedExhaustion(key: "a:5h", now: now)
        XCTAssertNotNil(projected)
        // slope = (60-40)/30min = 0.667%/min; remaining 40% / 0.667 = 60min from last sample.
        let expected = base.addingTimeInterval(30 * 60).addingTimeInterval(60 * 60)
        XCTAssertEqual(projected!.timeIntervalSince(expected), 0, accuracy: 60)
    }

    func testFlatUsageReturnsNil() {
        let estimator = BurnRateEstimator()
        estimator.record(key: "a:5h", utilization: 40, at: base)
        estimator.record(key: "a:5h", utilization: 40, at: base.addingTimeInterval(15 * 60))
        estimator.record(key: "a:5h", utilization: 40, at: base.addingTimeInterval(30 * 60))
        XCTAssertNil(estimator.projectedExhaustion(key: "a:5h", now: base.addingTimeInterval(30 * 60)))
    }

    func testSingleSampleReturnsNil() {
        let estimator = BurnRateEstimator()
        estimator.record(key: "a:5h", utilization: 40, at: base)
        XCTAssertNil(estimator.projectedExhaustion(key: "a:5h", now: base))
    }

    func testTwoSamplesFiveMinutesApartReturnsNilSpanTooShort() {
        let estimator = BurnRateEstimator()
        estimator.record(key: "a:5h", utilization: 40, at: base)
        estimator.record(key: "a:5h", utilization: 50, at: base.addingTimeInterval(5 * 60))
        XCTAssertNil(estimator.projectedExhaustion(key: "a:5h", now: base.addingTimeInterval(5 * 60)))
    }

    func testDropOver30ClearsHistory() {
        let estimator = BurnRateEstimator()
        estimator.record(key: "a:5h", utilization: 40, at: base)
        estimator.record(key: "a:5h", utilization: 60, at: base.addingTimeInterval(15 * 60))
        estimator.record(key: "a:5h", utilization: 5, at: base.addingTimeInterval(30 * 60))  // reset
        XCTAssertNil(estimator.projectedExhaustion(key: "a:5h", now: base.addingTimeInterval(30 * 60)))
    }

    func testPruningOldSamplesBeyond45MinDoesNotDragSlope() {
        let estimator = BurnRateEstimator()
        // Old, slow-climbing samples well beyond the 45-min window.
        estimator.record(key: "a:5h", utilization: 10, at: base)
        estimator.record(key: "a:5h", utilization: 12, at: base.addingTimeInterval(50 * 60))
        // Recent, steep climb within the last 45 minutes.
        estimator.record(key: "a:5h", utilization: 40, at: base.addingTimeInterval(70 * 60))
        estimator.record(key: "a:5h", utilization: 70, at: base.addingTimeInterval(100 * 60))
        let now = base.addingTimeInterval(100 * 60)
        let projected = estimator.projectedExhaustion(key: "a:5h", now: now)
        XCTAssertNotNil(projected)
        // If pruning worked, slope uses only the last two samples: (70-40)/30min = 1%/min.
        // Remaining 30% / 1%/min = 30 min from last sample.
        let expected = now.addingTimeInterval(30 * 60)
        XCTAssertEqual(projected!.timeIntervalSince(expected), 0, accuracy: 60)
    }

    func testUtilizationAlready100ReturnsNil() {
        let estimator = BurnRateEstimator()
        estimator.record(key: "a:5h", utilization: 80, at: base)
        estimator.record(key: "a:5h", utilization: 100, at: base.addingTimeInterval(15 * 60))
        XCTAssertNil(estimator.projectedExhaustion(key: "a:5h", now: base.addingTimeInterval(15 * 60)))
    }
}
