import Foundation

/// The two racket sports the app knows how to score.
///
/// Both share the same scoring rules, so the sport only changes the labels,
/// the icon and the defaults suggested when a new match is created.
enum Sport: String, Codable, CaseIterable, Identifiable {
    case tennis
    case padel

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tennis: return "Tennis"
        case .padel: return "Padel"
        }
    }

    var symbolName: String {
        switch self {
        case .tennis: return "figure.tennis"
        case .padel: return "figure.racquetball"
        }
    }

    /// Padel is usually played with a deciding point at deuce, tennis is not.
    var defaultGoldenPoint: Bool {
        switch self {
        case .tennis: return false
        case .padel: return true
        }
    }
}

/// The two sides of a match. `you` is always the side the watch owner plays on,
/// which is what makes the win/loss stats meaningful.
enum Team: Int, Codable, CaseIterable, Identifiable {
    case you = 0
    case opponent = 1

    var id: Int { rawValue }

    var other: Team { self == .you ? .opponent : .you }

    var name: String { self == .you ? "You" : "Opponent" }

    var shortName: String { self == .you ? "You" : "Opp" }
}
