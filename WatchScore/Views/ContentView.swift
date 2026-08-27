import SwiftUI

/// Home screen: start a match, or look at the ones already played.
struct ContentView: View {
    @EnvironmentObject private var store: MatchStore
    @State private var path: [Route] = []
    @State private var activeMatch: StartedMatch?

    private enum Route: Hashable {
        case newMatch
        case history
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    NavigationLink(value: Route.newMatch) {
                        Label("New Match", systemImage: "plus.circle.fill")
                    }
                    NavigationLink(value: Route.history) {
                        Label("History", systemImage: "list.bullet.rectangle")
                    }
                }

                if !store.matches.isEmpty {
                    Section("Record") {
                        ForEach(Sport.allCases) { sport in
                            let record = store.record(for: sport)
                            if record.wins + record.losses > 0 {
                                LabeledContent(sport.displayName) {
                                    Text("\(record.wins)W \(record.losses)L")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Watch Score")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .newMatch:
                    NewMatchView { options in
                        store.remember(options)
                        activeMatch = StartedMatch(options: options)
                    }
                case .history:
                    HistoryView()
                }
            }
        }
        // The setup screen is popped once the match is over, rather than while
        // the match is being presented, so the two transitions do not overlap.
        .fullScreenCover(item: $activeMatch, onDismiss: { path.removeAll() }) { match in
            MatchView(options: match.options)
        }
    }
}

/// A match waiting to be presented. The id makes every start a new presentation,
/// even when the same options are used twice in a row.
private struct StartedMatch: Identifiable {
    let id = UUID()
    let options: MatchOptions
}

#Preview {
    ContentView()
        .environmentObject(MatchStore())
}
