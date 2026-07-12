import Foundation

/// Оценивает, когда окно упрётся в 100% при текущем темпе расхода. Чистый движок —
/// хранит скользящее окно недавних (date, utilization) сэмплов по ключу и линейно
/// экстраполирует последний тренд.
final class BurnRateEstimator {
    private struct Sample { let date: Date; let utilization: Double }

    private static let pruneWindow: TimeInterval = 45 * 60
    private static let minSpan: TimeInterval = 10 * 60
    private static let minSlopePerMinute: Double = 0.1
    private static let resetDrop: Double = 30

    private var samples: [String: [Sample]] = [:]

    func record(key: String, utilization: Double, at date: Date) {
        var history = samples[key] ?? []
        // Большой провал = окно перекатилось — старая история больше не релевантна.
        if let last = history.last, utilization < last.utilization - Self.resetDrop {
            history = []
        }
        history.append(Sample(date: date, utilization: utilization))
        let newest = history.last!.date
        history.removeAll { newest.timeIntervalSince($0.date) > Self.pruneWindow }
        samples[key] = history
    }

    func projectedExhaustion(key: String, now: Date) -> Date? {
        guard let history = samples[key], history.count >= 2,
              let first = history.first, let last = history.last else { return nil }
        guard last.utilization < 100 else { return nil }
        let spanSeconds = last.date.timeIntervalSince(first.date)
        guard spanSeconds >= Self.minSpan else { return nil }
        let minutes = spanSeconds / 60
        let slope = (last.utilization - first.utilization) / minutes   // %/min
        guard slope > Self.minSlopePerMinute else { return nil }
        let remainingMinutes = (100 - last.utilization) / slope
        return last.date.addingTimeInterval(remainingMinutes * 60)
    }
}
