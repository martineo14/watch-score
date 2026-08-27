import Foundation

/// A set that has already been played out.
struct CompletedSet: Codable, Equatable, Identifiable {
    var id = UUID()
    /// Games won, indexed by `Team.rawValue`.
    var games: [Int]
    /// Points of the tiebreak that closed the set, if there was one.
    var tiebreakPoints: [Int]?
    var winner: Team

    var scoreText: String {
        var text = "\(games[0])-\(games[1])"
        if let tiebreakPoints {
            text += "(\(min(tiebreakPoints[0], tiebreakPoints[1])))"
        }
        return text
    }
}

/// The scoring rules of tennis and padel, as a value type.
///
/// The whole state of a match lives here, which makes undo a matter of keeping
/// the previous values around, and makes the rules easy to reason about in one
/// place: `score(_:)` is the only way the match moves forward.
struct MatchEngine: Codable, Equatable {
    let options: MatchOptions

    /// Points in the current game, or in the current tiebreak.
    private(set) var points = [0, 0]
    /// Games in the set being played.
    private(set) var games = [0, 0]
    /// Sets won so far.
    private(set) var sets = [0, 0]
    private(set) var completedSets: [CompletedSet] = []
    private(set) var isTiebreak = false
    private(set) var server: Team
    private(set) var winner: Team?
    private(set) var stats = MatchStats()

    /// Who served the first point of the tiebreak, so the next set starts with
    /// the other team serving.
    private var tiebreakFirstServer: Team?

    init(options: MatchOptions) {
        self.options = options
        self.server = options.startingServer
    }

    var isFinished: Bool { winner != nil }

    /// True when the game (or tiebreak) currently on court is a deciding point:
    /// whoever wins it takes the game.
    var isGamePoint: Bool {
        guard !isFinished else { return false }
        let (hi, lo) = (max(points[0], points[1]), min(points[0], points[1]))
        if isTiebreak {
            return hi >= 6 && hi > lo
        }
        if options.goldenPoint && hi == 3 && lo == 3 { return true }
        return hi >= 3 && hi > lo
    }

    // MARK: - Playing

    /// Awards the point at play to `team` and advances the match.
    mutating func score(_ team: Team) {
        guard !isFinished else { return }

        stats.record(point: team, server: server)
        points[team.rawValue] += 1

        if isTiebreak {
            resolveTiebreak()
        } else {
            resolveGame()
        }
    }

    private mutating func resolveGame() {
        let (a, b) = (points[0], points[1])
        let (hi, lo) = (max(a, b), min(a, b))
        guard hi >= 4 else { return }

        let leader: Team = a > b ? .you : .opponent
        if hi - lo >= 2 || (options.goldenPoint && hi == 4 && lo == 3) {
            win(game: leader)
        }
    }

    private mutating func resolveTiebreak() {
        // The first point is served by one team, then serve changes every two
        // points: after totals 1, 3, 5...
        if (points[0] + points[1]) % 2 == 1 {
            server = server.other
        }

        let (a, b) = (points[0], points[1])
        let (hi, lo) = (max(a, b), min(a, b))
        guard hi >= 7, hi - lo >= 2 else { return }

        let tiebreakWinner: Team = a > b ? .you : .opponent
        let tiebreakPoints = points
        stats.record(game: tiebreakWinner, server: nil)
        games[tiebreakWinner.rawValue] += 1
        complete(set: tiebreakWinner, tiebreakPoints: tiebreakPoints)
    }

    private mutating func win(game team: Team) {
        stats.record(game: team, server: server)
        games[team.rawValue] += 1
        points = [0, 0]
        server = server.other

        if let setWinner = completedSetWinner() {
            complete(set: setWinner, tiebreakPoints: nil)
        } else if options.tiebreakAtSixAll && games[0] == 6 && games[1] == 6 {
            isTiebreak = true
            tiebreakFirstServer = server
        }
    }

    /// A set needs six games and a two game lead; 7-6 only happens through a
    /// tiebreak, which is completed by `resolveTiebreak()`.
    private func completedSetWinner() -> Team? {
        let (a, b) = (games[0], games[1])
        let (hi, lo) = (max(a, b), min(a, b))
        guard hi >= 6, hi - lo >= 2 else { return nil }
        return a > b ? .you : .opponent
    }

    private mutating func complete(set setWinner: Team, tiebreakPoints: [Int]?) {
        completedSets.append(
            CompletedSet(games: games, tiebreakPoints: tiebreakPoints, winner: setWinner)
        )
        sets[setWinner.rawValue] += 1
        games = [0, 0]
        points = [0, 0]

        if isTiebreak {
            // Whoever served first in the tiebreak returns first in the next set.
            if let tiebreakFirstServer {
                server = tiebreakFirstServer.other
            }
            isTiebreak = false
            tiebreakFirstServer = nil
        }

        if sets[setWinner.rawValue] >= options.setsToWin {
            winner = setWinner
        }
    }

    /// What is at stake on the point about to be played, if anything.
    ///
    /// `team` is nil on a golden point at deuce, where either side can take the
    /// game with it.
    struct Milestone: Equatable {
        var team: Team?
        var label: String
    }

    var milestone: Milestone? {
        guard isGamePoint else { return nil }

        let sharedPoint = !isTiebreak && options.goldenPoint && points[0] == points[1]
        let leader: Team? = sharedPoint ? nil : (points[0] > points[1] ? .you : .opponent)
        let candidates: [Team] = leader.map { [$0] } ?? Team.allCases

        if candidates.contains(where: wouldWinMatch) {
            return Milestone(team: leader, label: "Match point")
        }
        if candidates.contains(where: wouldWinSet) {
            return Milestone(team: leader, label: "Set point")
        }
        return Milestone(team: leader, label: sharedPoint ? "Golden point" : "Game point")
    }

    private func wouldWinSet(_ team: Team) -> Bool {
        // Winning a tiebreak always closes the set.
        if isTiebreak { return true }
        var after = games
        after[team.rawValue] += 1
        let (hi, lo) = (max(after[0], after[1]), min(after[0], after[1]))
        return hi >= 6 && hi - lo >= 2
    }

    private func wouldWinMatch(_ team: Team) -> Bool {
        wouldWinSet(team) && sets[team.rawValue] + 1 >= options.setsToWin
    }

    // MARK: - Display

    private static let pointLadder = ["0", "15", "30", "40"]

    /// The score to show for a team: tiebreak points, or 0/15/30/40/AD.
    func pointLabel(for team: Team) -> String {
        if isTiebreak {
            return "\(points[team.rawValue])"
        }
        let mine = points[team.rawValue]
        let theirs = points[team.other.rawValue]
        if mine >= 3 && theirs >= 3 {
            if mine == theirs { return "40" }
            return mine > theirs ? "AD" : "40"
        }
        return Self.pointLadder[min(mine, 3)]
    }

    /// "6-4 3-6 2-1" — every set played, including the one in progress.
    var scoreLine: String {
        var parts = completedSets.map(\.scoreText)
        if !isFinished && (games[0] > 0 || games[1] > 0 || completedSets.isEmpty) {
            parts.append("\(games[0])-\(games[1])")
        }
        return parts.joined(separator: " ")
    }
}
