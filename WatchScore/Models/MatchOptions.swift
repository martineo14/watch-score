import Foundation

/// Everything that has to be decided before the first point is played.
struct MatchOptions: Codable, Equatable {
    var sport: Sport = .padel
    /// 1 = single set, 2 = best of three.
    var setsToWin: Int = 2
    /// Sudden death at deuce ("punto de oro"): the next point wins the game.
    var goldenPoint: Bool = true
    /// Play a tiebreak at 6-6. When off, sets run on until someone leads by two.
    var tiebreakAtSixAll: Bool = true
    var startingServer: Team = .you

    static let `default` = MatchOptions()

    var setsDescription: String {
        setsToWin == 1 ? "1 set" : "Best of \(setsToWin * 2 - 1)"
    }

    /// Applies the conventions of a sport without touching what the user
    /// already picked for the rest of the match.
    mutating func applyDefaults(for sport: Sport) {
        self.sport = sport
        goldenPoint = sport.defaultGoldenPoint
    }
}
