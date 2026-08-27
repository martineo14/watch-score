import SwiftUI

/// The screen you play with: two big targets, the score, and nothing else.
struct MatchView: View {
    @EnvironmentObject private var store: MatchStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller: MatchController

    @State private var confirmEnd = false
    @State private var finishedRecord: MatchRecord?

    init(options: MatchOptions) {
        _controller = StateObject(wrappedValue: MatchController(options: options))
    }

    private var engine: MatchEngine { controller.engine }

    @ViewBuilder
    var body: some View {
        if let record = finishedRecord {
            NavigationStack {
                MatchSummaryView(record: record)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { dismiss() }
                        }
                    }
            }
        } else {
            scoringScreen
        }
    }

    private var scoringScreen: some View {
        NavigationStack {
            VStack(spacing: 4) {
                header
                Spacer(minLength: 0)
                pointScore
                Spacer(minLength: 0)
                pointButtons
            }
            .padding(.horizontal, 2)
            .navigationTitle(engine.scoreLine)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        controller.undo()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(!controller.canUndo)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        confirmEnd = true
                    } label: {
                        Image(systemName: "flag.checkered")
                    }
                }
            }
        }
        .confirmationDialog("End this match?", isPresented: $confirmEnd) {
            Button("End match", role: .destructive) { finish() }
            Button("Keep playing", role: .cancel) {}
        }
        .onChange(of: engine.isFinished) { _, isFinished in
            if isFinished { finish() }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(spacing: 4) {
            Label(engine.isTiebreak ? "Tiebreak" : "Serve: \(engine.server.shortName)",
                  systemImage: engine.isTiebreak ? "flame.fill" : "circle.fill")
                .labelStyle(.titleAndIcon)
                .font(.caption2)
                .foregroundStyle(engine.isTiebreak ? Color.orange : Color.secondary)
            Spacer()
            Text(controller.startedAt, style: .timer)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var pointScore: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                pointLabel(for: .you)
                Text("-")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                pointLabel(for: .opponent)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)

            // Kept in the layout even when there is nothing at stake, so the
            // score does not jump around between points.
            Text(engine.milestone?.label.uppercased() ?? " ")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(milestoneColor(engine.milestone?.team))
                .opacity(engine.milestone == nil ? 0 : 1)
        }
    }

    private func milestoneColor(_ team: Team?) -> Color {
        switch team {
        case .you: return .accentColor
        case .opponent: return .orange
        case nil: return .yellow
        }
    }

    private func pointLabel(for team: Team) -> some View {
        Text(engine.pointLabel(for: team))
            .font(.system(size: 40, weight: .semibold, design: .rounded))
            .foregroundStyle(team == .you ? Color.accentColor : Color.primary)
    }

    private var pointButtons: some View {
        HStack(spacing: 6) {
            ForEach(Team.allCases) { team in
                Button {
                    controller.score(team)
                } label: {
                    VStack(spacing: 1) {
                        Text(team.shortName)
                            .font(.headline)
                        Text("\(engine.games[team.rawValue]) games")
                            .font(.system(size: 11))
                            .opacity(0.7)
                    }
                    .frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(.borderedProminent)
                .tint(team == .you ? .accentColor : .gray)
            }
        }
        .padding(.bottom, 2)
    }

    // MARK: - Ending

    private func finish() {
        guard finishedRecord == nil else { return }
        let record = controller.makeRecord()
        store.add(record)
        finishedRecord = record
    }
}

#Preview {
    MatchView(options: .default)
        .environmentObject(MatchStore())
}
