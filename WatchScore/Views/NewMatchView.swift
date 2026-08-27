import SwiftUI

/// Picks the sport and the format, starting from whatever was used last time.
struct NewMatchView: View {
    @EnvironmentObject private var store: MatchStore
    @State private var options = MatchOptions.default
    /// Called with the chosen options once the user taps Start.
    let onStart: (MatchOptions) -> Void

    var body: some View {
        List {
            Section {
                HStack(spacing: 6) {
                    ForEach(Sport.allCases) { sport in
                        SportButton(sport: sport, isSelected: options.sport == sport) {
                            options.applyDefaults(for: sport)
                        }
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Format") {
                Picker("Sets", selection: $options.setsToWin) {
                    Text("1 set").tag(1)
                    Text("Best of 3").tag(2)
                }
                Toggle("Golden point", isOn: $options.goldenPoint)
                Toggle("Tiebreak at 6-6", isOn: $options.tiebreakAtSixAll)
            }

            Section("First serve") {
                Picker("Serving", selection: $options.startingServer) {
                    ForEach(Team.allCases) { team in
                        Text(team.name).tag(team)
                    }
                }
            }

            Section {
                Button {
                    onStart(options)
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("New Match")
        .onAppear { options = store.lastOptions }
    }
}

private struct SportButton: View {
    let sport: Sport
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: sport.symbolName)
                    .font(.title3)
                Text(sport.displayName)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.accentColor : Color.gray.opacity(0.25))
        .foregroundStyle(isSelected ? Color.black : Color.primary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    NavigationStack {
        NewMatchView { _ in }
            .environmentObject(MatchStore())
    }
}
