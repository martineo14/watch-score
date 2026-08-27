import SwiftUI

/// Every match played, newest first.
struct HistoryView: View {
    @EnvironmentObject private var store: MatchStore

    var body: some View {
        List {
            if store.matches.isEmpty {
                Text("No matches yet.\nPlay one and it shows up here.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.recentMatches) { match in
                    NavigationLink {
                        MatchSummaryView(record: match)
                    } label: {
                        MatchRow(match: match)
                    }
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("History")
    }

    private func delete(at offsets: IndexSet) {
        let shown = store.recentMatches
        for index in offsets where shown.indices.contains(index) {
            store.delete(shown[index])
        }
    }
}

private struct MatchRow: View {
    let match: MatchRecord

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: match.sport.symbolName)
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(match.scoreLine)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(match.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 2)
            Text(resultBadge)
                .font(.caption2.bold())
                .foregroundStyle(badgeColor)
        }
    }

    private var resultBadge: String {
        guard let winner = match.winner else { return "–" }
        return winner == .you ? "W" : "L"
    }

    private var badgeColor: Color {
        guard let winner = match.winner else { return .secondary }
        return winner == .you ? .green : .orange
    }
}

#Preview {
    NavigationStack {
        HistoryView()
            .environmentObject(MatchStore())
    }
}
