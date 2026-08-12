import Foundation

enum OccurrenceStatus: String, Codable, CaseIterable {
    case pending
    case completed
    case missed
}
