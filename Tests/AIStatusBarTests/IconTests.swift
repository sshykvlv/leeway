import XCTest
import AppKit
@testable import AIStatusBar

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

    /// Regression coverage for the "bars don't reflect the real percentage" bug:
    /// the fill height used to floor at barWidth (3pt = 20% of a 15pt bar), so
    /// any two accounts both under 20% used (e.g. real-world 4% and 19%) rendered
    /// as the exact same height despite a 5x gap in actual usage.
    func testFillHeightDistinguishesTwoLowPercentages() {
        let low = IconRenderer.fillHeight(used: 0.04)
        let mid = IconRenderer.fillHeight(used: 0.19)
        let high = IconRenderer.fillHeight(used: 0.28)
        XCTAssertLessThan(low, mid)
        XCTAssertLessThan(mid, high)
    }

    func testFillHeightIsProportionalAboveTheFloor() {
        // Well above the 1pt floor, height should track usage linearly.
        XCTAssertEqual(IconRenderer.fillHeight(used: 0.5), IconRenderer.barHeight * 0.5, accuracy: 0.01)
    }

    func testFillHeightFloorsNearZeroToStayVisible() {
        XCTAssertEqual(IconRenderer.fillHeight(used: 0.001), 1)
        XCTAssertEqual(IconRenderer.fillHeight(used: 0), 0)
    }

    /// Regression coverage for the "icon disappears" bug: with zero configured
    /// accounts, `image(levels:)` used to draw nothing at all (the fill loop
    /// iterates `levels`, which was empty) — a fully blank, invisible menu bar
    /// icon with nothing left to click to add an account back. It must still
    /// draw at least an empty placeholder track.
    func testImageDrawsPlaceholderTrackWhenNoAccountsConfigured() {
        let img = IconRenderer.image(levels: [])
        XCTAssertTrue(img.size.width > 0 && img.size.height > 0)
        XCTAssertTrue(img.isTemplate, "no data at all should still render as a template icon")
        XCTAssertTrue(hasAnyNonTransparentPixel(img), "expected a visible placeholder track, got a blank canvas")
    }

    private func hasAnyNonTransparentPixel(_ image: NSImage) -> Bool {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                   pixelsWide: Int(image.size.width), pixelsHigh: Int(image.size.height),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: image.size))
        NSGraphicsContext.restoreGraphicsState()
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                if let color = rep.colorAt(x: x, y: y), color.alphaComponent > 0.01 { return true }
            }
        }
        return false
    }
}
