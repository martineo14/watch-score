import SwiftUI

/// What the match looked like once it was over: score, and the handful of
/// numbers that are actually worth reading on a wrist.
struct MatchSummaryView: View {
    let record: MatchRecord

    private var stats: MatchStats { record.stats }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 2) {
                    Text(resultText)
                        .font(.headline)
                        .foregroundStyle(resultColor)
                    Text(record.scoreLine)
                        .font(.system(.title3, design: .rounded))
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                    Text("\(record.sport.displayName) · \(record.options.setsDescription) · \(record.durationText)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }

            Section("Stats") {
                StatRow(title: "Points won",
                        you: "\(stats.pointsWon[0])",
                        opponent: "\(stats.pointsWon[1])")
                StatRow(title: "Points share",
                        you: percent(stats.pointShare(for: .you)),
                        opponent: percent(stats.pointShare(for: .opponent)))
                StatRow(title: "Won on serve",
                        you: percent(stats.servicePointShare(for: .you)),
                        opponent: percent(stats.servicePointShare(for: .opponent)))
                StatRow(title: "Games",
                        you: "\(stats.gamesWon[0])",
                        opponent: "\(stats.gamesWon[1])")
                StatRow(title: "Breaks",
                        you: "\(stats.breaks[0])",
                        opponent: "\(stats.breaks[1])")
                StatRow(title: "Best run",
                        you: "\(stats.longestStreak[0])",
                        opponent: "\(stats.longestStreak[1])")
            }

            if let vitals = record.vitals {
                Section("Body") {
                    if let average = vitals.averageHeartRate {
                        LabeledContent("Avg heart rate") { Text("\(average) bpm") }
                    }
                    if let peak = vitals.maxHeartRate {
                        LabeledContent("Max heart rate") { Text("\(peak) bpm") }
                    }
                    if let calories = vitals.activeCalories {
                        LabeledContent("Active calories") { Text("\(calories) kcal") }
                    }
                }
                .font(.caption)
            }

            if !record.sets.isEmpty {
                Section("Sets") {
                    ForEach(Array(record.sets.enumerated()), id: \.element.id) { index, set in
                        LabeledContent("Set \(index + 1)") {
                            Text(set.scoreText)
                                .foregroundStyle(set.winner == .you ? Color.accentColor : Color.primary)
                        }
                        .font(.caption)
                    }
                }
            }
        }
        // Date only: a date and time together is wider than the watch title bar
        // and gets truncated to something like "Aug 24, 2026 at 7...".
        .navigationTitle(record.date.formatted(date: .abbreviated, time: .omitted))
    }

    private var resultText: String {
        guard let winner = record.winner else { return "Ended early" }
        return winner == .you ? "You won" : "Opponent won"
    }

    private var resultColor: Color {
        guard let winner = record.winner else { return .secondary }
        return winner == .you ? .green : .orange
    }

    private func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int((value * 100).rounded()))%"
    }
}

/// One line of the stats table: label on the left, both teams on the right.
private struct StatRow: View {
    let title: String
    let you: String
    let opponent: String

    var body: some View {
        HStack {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text(you)
                .foregroundStyle(Color.accentColor)
            Text("/")
                .foregroundStyle(.tertiary)
            Text(opponent)
        }
        .font(.caption)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

#Preview {
    NavigationStack {
        MatchSummaryView(record: .preview)
    }
}
