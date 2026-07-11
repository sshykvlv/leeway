import XCTest
@testable import LimitBar

final class IconTests: XCTestCase {
    func testBarLevelsUsedFromWorstWindow() {
        let states: [AccountState] = [
            .ok(Usage(fiveHour: .init(utilization: 62, resetsAt: nil),
                      sevenDay: .init(utilization: 31, resetsAt: nil)), fetchedAt: .init()),
            .failed(badge: "re-login"),
            .pending,
        ]
        let levels = IconRenderer.barLevels(states)
        XCTAssertEqual(levels[0].used!, 0.62, accuracy: 0.001) // worst window utilization
        XCTAssertEqual(levels[0].severity, .normal)
        XCTAssertNil(levels[1].used)                           // no data → empty track
        XCTAssertNil(levels[2].used)
    }

    func testWarnSeverityAboveSeventyPercentUsed() {
        let s: [AccountState] = [.ok(Usage(fiveHour: .init(utilization: 75, resetsAt: nil),
                                           sevenDay: nil), fetchedAt: .init())]
        XCTAssertEqual(IconRenderer.barLevels(s)[0].severity, .warn)
    }

    func testDangerSeverityAboveNinetyPercentUsed() {
        let s: [AccountState] = [.ok(Usage(fiveHour: .init(utilization: 95, resetsAt: nil),
                                           sevenDay: nil), fetchedAt: .init())]
        let level = IconRenderer.barLevels(s)[0]
        XCTAssertEqual(level.severity, .danger)
        XCTAssertEqual(level.used!, 0.95, accuracy: 0.001)
    }

    func testStaleUsesUsageToo() {
        let s: [AccountState] = [.stale(Usage(fiveHour: .init(utilization: 40, resetsAt: nil),
                                              sevenDay: nil), fetchedAt: .init(), badge: "offline")]
        XCTAssertEqual(IconRenderer.barLevels(s)[0].used!, 0.40, accuracy: 0.001)
    }

    func testImageIsColoredWhenHasData() {
        // Цветовое кодирование: даже спокойный (normal) значок цветной (зелёный),
        // поэтому не template.
        let s: [AccountState] = [.ok(Usage(fiveHour: .init(utilization: 20, resetsAt: nil),
                                           sevenDay: nil), fetchedAt: .init())]
        let img = IconRenderer.image(levels: IconRenderer.barLevels(s))
        XCTAssertTrue(img.size.width > 0 && img.size.height > 0)
        XCTAssertFalse(img.isTemplate)
    }

    func testImageTemplateWhenNoData() {
        let s: [AccountState] = [.pending, .failed(badge: "re-login")]
        let img = IconRenderer.image(levels: IconRenderer.barLevels(s))
        XCTAssertTrue(img.isTemplate)
    }

    func testImageNonTemplateWhenDanger() {
        let s: [AccountState] = [.ok(Usage(fiveHour: .init(utilization: 95, resetsAt: nil),
                                           sevenDay: nil), fetchedAt: .init())]
        let img = IconRenderer.image(levels: IconRenderer.barLevels(s))
        XCTAssertFalse(img.isTemplate)
    }

    func testImageNonTemplateWhenWarn() {
        let s: [AccountState] = [.ok(Usage(fiveHour: .init(utilization: 75, resetsAt: nil),
                                           sevenDay: nil), fetchedAt: .init())]
        let img = IconRenderer.image(levels: IconRenderer.barLevels(s))
        XCTAssertFalse(img.isTemplate)
    }
}
