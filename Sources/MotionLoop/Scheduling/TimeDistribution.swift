import Foundation

/// Auto-spaces N reminder times evenly across a range, for the "count + gap"
/// schedule-authoring mode (as opposed to entering each time explicitly).
enum TimeDistribution {
    /// Evenly spaces `count` times across [rangeStart, rangeEnd] inclusive, so
    /// the two endpoints anchor the range (gap = span / (count - 1) for
    /// count > 1). Returns nil if count < 1, the range is empty/inverted, or
    /// the resulting gap would be < minimumGapMinutes (range too short for
    /// that many times).
    static func evenlySpaced(
        count: Int,
        rangeStart: (hour: Int, minute: Int),
        rangeEnd: (hour: Int, minute: Int),
        minimumGapMinutes: Int
    ) -> [(hour: Int, minute: Int)]? {
        guard count >= 1 else { return nil }
        let startMinutes = rangeStart.hour * 60 + rangeStart.minute
        let endMinutes = rangeEnd.hour * 60 + rangeEnd.minute
        guard endMinutes > startMinutes else { return nil }

        if count == 1 {
            return [rangeStart]
        }

        let span = endMinutes - startMinutes
        let gap = Double(span) / Double(count - 1)
        guard gap >= Double(minimumGapMinutes) else { return nil }

        return (0..<count).map { index in
            let minuteOfDay = startMinutes + Int((Double(index) * gap).rounded())
            return (hour: minuteOfDay / 60, minute: minuteOfDay % 60)
        }
    }
}
