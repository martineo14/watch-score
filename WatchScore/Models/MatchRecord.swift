import Foundation

/// A finished (or abandoned) match, as it is kept on disk.
struct MatchRecord: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var duration: TimeInterval
    var options: MatchOptions
    var sets: [CompletedSet]
    /// Games of the set that was still being played when an abandoned match ended.
    var unfinishedSetGames: [Int]?
    var stats: MatchStats
    /// Nil when the match was ended before anybody won it.
    var winner: Team?

    var sport: Sport { options.sport }
    var wasAbandoned: Bool { winner == nil }
    var didWin: Bool { winner == .you }

    var scoreLine: String {
        var parts = sets.map(\.scoreText)
        if let unfinishedSetGames {
            parts.append("(\(unfinishedSetGames[0])-\(unfinishedSetGames[1]))")
        }
        return parts.isEmpty ? "no games played" : parts.joined(separator: " ")
    }

    var durationText: String {
        let minutes = Int(duration) / 60
        guard minutes >= 60 else { return "\(minutes) min" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    /// Builds the record for a match that is being closed, finished or not.
    init(engine: MatchEngine, startedAt: Date, endedAt: Date = Date()) {
        self.date = startedAt
        self.duration = endedAt.timeIntervalSince(startedAt)
        self.options = engine.options
        self.sets = engine.completedSets
        self.stats = engine.stats
        self.winner = engine.winner
        let games = engine.games
        self.unfinishedSetGames = engine.isFinished ? nil : games
    }
}

#if DEBUG
extension MatchRecord {
    /// A played-out match, for SwiftUI previews.
    static var preview: MatchRecord {
        var options = MatchOptions()
        options.setsToWin = 1
        var engine = MatchEngine(options: options)
        var played = 0
        while !engine.isFinished && played < 500 {
            engine.score(played % 3 == 2 ? .opponent : .you)
            played += 1
        }
        return MatchRecord(engine: engine, startedAt: Date().addingTimeInterval(-58 * 60))
    }
}
#endif
