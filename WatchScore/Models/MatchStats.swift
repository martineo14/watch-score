import Foundation

/// Counters kept while the match is played, so no history has to be replayed
/// to build the summary. Every array is indexed by `Team.rawValue`.
struct MatchStats: Codable, Equatable {
    var pointsWon = [0, 0]
    var servicePointsPlayed = [0, 0]
    var servicePointsWon = [0, 0]
    var gamesWon = [0, 0]
    /// Games won while returning.
    var breaks = [0, 0]
    var longestStreak = [0, 0]

    private var streakTeam: Team?
    private var streakLength = 0

    var totalPoints: Int { pointsWon[0] + pointsWon[1] }

    mutating func record(point winner: Team, server: Team) {
        pointsWon[winner.rawValue] += 1
        servicePointsPlayed[server.rawValue] += 1
        if winner == server {
            servicePointsWon[winner.rawValue] += 1
        }

        if streakTeam == winner {
            streakLength += 1
        } else {
            streakTeam = winner
            streakLength = 1
        }
        longestStreak[winner.rawValue] = max(longestStreak[winner.rawValue], streakLength)
    }

    /// `server` is nil for a tiebreak, where both teams served and calling it
    /// a break of serve would be meaningless.
    mutating func record(game winner: Team, server: Team?) {
        gamesWon[winner.rawValue] += 1
        if let server, winner != server {
            breaks[winner.rawValue] += 1
        }
    }

    /// Share of the total points a team took, 0...1.
    func pointShare(for team: Team) -> Double {
        guard totalPoints > 0 else { return 0 }
        return Double(pointsWon[team.rawValue]) / Double(totalPoints)
    }

    /// Share of the points won when serving, 0...1, or nil if the team never served.
    func servicePointShare(for team: Team) -> Double? {
        let played = servicePointsPlayed[team.rawValue]
        guard played > 0 else { return nil }
        return Double(servicePointsWon[team.rawValue]) / Double(played)
    }
}
