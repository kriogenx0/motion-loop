import Foundation

/// Immutable snapshot of a Schedule and the activities currently attached to
/// it, decoupled from SwiftData so generation can be pure Foundation code.
struct ScheduleSnapshot: Hashable {
    let scheduleID: UUID
    let type: ScheduleType
    /// nil unless type == .window.
    let windowDurationMinutes: Int?
    let activityIDs: [UUID]
    let times: [ScheduleTimeSnapshot]
}

/// Identifies one occurrence's "slot" -- a given ScheduleTime firing on a given
/// calendar day for a given activity -- used to avoid generating duplicate
/// occurrences for the same slot. Includes activityID because a ScheduleTime
/// can now be shared by several activities, each needing their own occurrence
/// for the same slot.
struct OccurrenceKey: Hashable {
    let scheduleTimeID: UUID
    let day: Date
    let activityID: UUID
}

/// Identifies one (ScheduleTime, day) slot, independent of which activity --
/// used to look up (or mint) the sessionID shared by every activity's
/// occurrence generated for that slot.
struct SlotKey: Hashable {
    let scheduleTimeID: UUID
    let day: Date
}

struct PlannedOccurrence {
    let activityID: UUID
    let scheduleTimeID: UUID
    let sessionID: UUID
    let scheduledDate: Date
    /// nil unless the owning Schedule is type == .window.
    let windowEnd: Date?
    let ruleWeekday: Int
    let ruleHour: Int
    let ruleMinute: Int
}

enum OccurrenceGenerator {
    /// Pure function: given the currently active schedules and the set of slots
    /// that already have an occurrence, returns the occurrences that should be
    /// inserted to fill the rolling horizon starting at `referenceDate`.
    ///
    /// Every activity attached to a Schedule gets its own occurrence per slot,
    /// but all of them share one `sessionID` per (ScheduleTime, day) -- reused
    /// from `existingSessionIDs` when a sibling activity already generated an
    /// occurrence for that slot, freshly minted otherwise (and cached for the
    /// rest of this call, so several activities newly joining one slot in the
    /// same pass still end up sharing a single id rather than one each).
    static func generateOccurrences(
        for schedules: [ScheduleSnapshot],
        existingKeys: Set<OccurrenceKey>,
        existingSessionIDs: [SlotKey: UUID],
        referenceDate: Date,
        horizonDays: Int = 14,
        calendar: Calendar = .current,
        makeSessionID: @escaping () -> UUID = UUID.init
    ) -> [PlannedOccurrence] {
        let horizonEnd = calendar.date(byAdding: .day, value: horizonDays, to: referenceDate) ?? referenceDate

        var planned: [PlannedOccurrence] = []
        var mintedSessionIDs: [SlotKey: UUID] = [:]

        for schedule in schedules {
            for time in schedule.times {
                // Strictly after `referenceDate` (not shifted back a day) -- a
                // time whose time-of-day already passed today must never
                // generate today's slot, otherwise a newly-added activity
                // immediately shows a "missed" occurrence for a moment that
                // existed before the activity did.
                let candidates = ScheduleMath.nextOccurrenceDates(
                    for: time,
                    after: referenceDate,
                    count: horizonDays + 1,
                    calendar: calendar
                )
                for date in candidates where date <= horizonEnd {
                    let day = calendar.startOfDay(for: date)
                    let slotKey = SlotKey(scheduleTimeID: time.scheduleTimeID, day: day)

                    let activitiesNeedingOccurrence = schedule.activityIDs.filter { activityID in
                        !existingKeys.contains(OccurrenceKey(scheduleTimeID: time.scheduleTimeID, day: day, activityID: activityID))
                    }
                    guard !activitiesNeedingOccurrence.isEmpty else { continue }

                    let sessionID = existingSessionIDs[slotKey]
                        ?? mintedSessionIDs[slotKey]
                        ?? makeSessionID()
                    mintedSessionIDs[slotKey] = sessionID

                    let end: Date? = schedule.type == .window
                        ? schedule.windowDurationMinutes.map {
                            ScheduleMath.windowEnd(for: date, durationMinutes: $0, calendar: calendar)
                        }
                        : nil

                    for activityID in activitiesNeedingOccurrence {
                        planned.append(
                            PlannedOccurrence(
                                activityID: activityID,
                                scheduleTimeID: time.scheduleTimeID,
                                sessionID: sessionID,
                                scheduledDate: date,
                                windowEnd: end,
                                ruleWeekday: time.weekday,
                                ruleHour: time.hour,
                                ruleMinute: time.minute
                            )
                        )
                    }
                }
            }
        }
        return planned
    }
}
