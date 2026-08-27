import Foundation

/// Keeps the played matches, and the options used for the last one, on disk.
///
/// A single JSON file is plenty for a match history: even a heavy season is a
/// few hundred small records, and it keeps the app free of any setup.
@MainActor
final class MatchStore: ObservableObject {
    @Published private(set) var matches: [MatchRecord] = []
    /// Pre-filled into the new match screen, so the usual setup is one tap away.
    @Published var lastOptions: MatchOptions = .default

    private let fileURL: URL
    private let optionsKey = "lastMatchOptions"

    init(directory: URL? = nil) {
        let folder = directory
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = folder.appendingPathComponent("matches.json")
        load()
    }

    // MARK: - Reading

    /// Most recent first.
    var recentMatches: [MatchRecord] {
        matches.sorted { $0.date > $1.date }
    }

    func matches(for sport: Sport) -> [MatchRecord] {
        recentMatches.filter { $0.sport == sport }
    }

    /// Wins and losses, ignoring matches that were abandoned.
    func record(for sport: Sport? = nil) -> (wins: Int, losses: Int) {
        let played = matches.filter { !$0.wasAbandoned && (sport == nil || $0.sport == sport) }
        let wins = played.filter(\.didWin).count
        return (wins, played.count - wins)
    }

    // MARK: - Writing

    func add(_ match: MatchRecord) {
        matches.append(match)
        save()
    }

    func delete(_ match: MatchRecord) {
        matches.removeAll { $0.id == match.id }
        save()
    }

    func deleteAll() {
        matches.removeAll()
        save()
    }

    func remember(_ options: MatchOptions) {
        lastOptions = options
        if let data = try? JSONEncoder().encode(options) {
            UserDefaults.standard.set(data, forKey: optionsKey)
        }
    }

    // MARK: - Disk

    private func load() {
        if let data = try? Data(contentsOf: fileURL),
           let stored = try? JSONDecoder().decode([MatchRecord].self, from: data) {
            matches = stored
        }
        if let data = UserDefaults.standard.data(forKey: optionsKey),
           let options = try? JSONDecoder().decode(MatchOptions.self, from: data) {
            lastOptions = options
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(matches)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Losing a match record is not worth interrupting the user over;
            // the in-memory list stays correct for this session either way.
            print("Could not save matches: \(error)")
        }
    }
}
