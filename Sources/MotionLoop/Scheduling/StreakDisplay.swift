import Foundation

enum StreakTier {
    case none      // < 3 days
    case warm      // 3-6 days
    case hot       // 7-13 days
    case blazing   // 14-29 days
    case inferno   // 30+ days
}

enum StreakDisplay {
    static func tier(for streak: Int) -> StreakTier {
        switch streak {
        case ..<3: return .none
        case 3..<7: return .warm
        case 7..<14: return .hot
        case 14..<30: return .blazing
        default: return .inferno
        }
    }

    static func flameCount(for tier: StreakTier) -> Int {
        switch tier {
        case .none: return 0
        case .warm: return 1
        case .hot: return 1
        case .blazing: return 2
        case .inferno: return 3
        }
    }

    static func flames(for streak: Int) -> String {
        String(repeating: "\u{1F525}", count: flameCount(for: tier(for: streak)))
    }

    static func label(for streak: Int) -> String {
        streak == 1 ? "1 day streak" : "\(streak) day streak"
    }
}
