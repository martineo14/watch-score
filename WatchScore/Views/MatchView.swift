import SwiftUI

/// The screen you play with: two big targets, the score, and nothing else.
struct MatchView: View {
    @EnvironmentObject private var store: MatchStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller: MatchController
    @StateObject private var workout = WorkoutTracker()

    @State private var confirmEnd = false
    @State private var finishedRecord: MatchRecord?
    @State private var isFinishing = false
    @State private var endedEarly = false

    init(options: MatchOptions) {
        _controller = StateObject(wrappedValue: MatchController(options: options))
    }

    private var engine: MatchEngine { controller.engine }

    @ViewBuilder
    var body: some View {
        if let record = finishedRecord {
            NavigationStack {
                MatchSummaryView(record: record, resume: resumeOption)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { saveAndClose(record) }
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
                undoButton
            }
            .padding(.horizontal, 2)
            .navigationTitle(engine.scoreLine)
            .toolbar {
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
            Button("End match", role: .destructive) {
                endedEarly = true
                finish()
            }
            Button("Keep playing", role: .cancel) {}
        }
        .onChange(of: engine.isFinished) { _, isFinished in
            if isFinished { finish() }
        }
        // Keeps the app awake between points: without a running workout the
        // watch sleeps as soon as you drop your wrist.
        .task { await workout.start(for: engine.options.sport) }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(spacing: 1) {
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

            if workout.isRunning {
                HStack(spacing: 3) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(Color.pink)
                    Text(workout.heartRate.map { "\($0)" } ?? "--")
                    Spacer()
                    Text("\(workout.activeCalories) kcal")
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
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

    /// Named with the side it will correct, because the mistake this fixes is
    /// nearly always a point given to the wrong one.
    @ViewBuilder
    private var undoButton: some View {
        if controller.canUndo {
            Button {
                controller.undo()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                    Text("Undo")
                    if let scorer = controller.lastScorer {
                        Text(scorer.shortName)
                            .foregroundStyle(scorer == .you ? Color.accentColor : Color.orange)
                    }
                }
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, minHeight: 22)
            }
            .buttonStyle(.bordered)
            .tint(.gray)
        }
    }

    // MARK: - Ending

    /// Ends the match and saves it, but leaves the workout running: the result
    /// can still be taken back from the summary, and restarting a workout
    /// would split the match into two of them in Health.
    private func finish() {
        // Reachable both from the end-match button and from the match finishing
        // on its own, so it has to be safe to call twice.
        guard finishedRecord == nil, !isFinishing else { return }
        isFinishing = true

        let record = controller.makeRecord(vitals: workout.currentVitals())
        store.add(record)
        finishedRecord = record
    }

    private var resumeOption: MatchSummaryView.ResumeOption {
        MatchSummaryView.ResumeOption(
            title: endedEarly ? "Keep playing" : "Undo last point",
            note: endedEarly
                ? "Puts you back on court. This match stops being saved."
                : "Marked the wrong side? This takes the last point back and puts you on court again.",
            perform: resume
        )
    }

    /// Back onto the court: the match is unsaved, and the point that ended it
    /// is taken back so the score is playable again.
    private func resume() {
        if let record = finishedRecord {
            store.delete(record)
        }
        if engine.isFinished {
            controller.undo()
        }
        finishedRecord = nil
        isFinishing = false
        endedEarly = false
    }

    /// Closes the workout, folds its final numbers into the saved match, and
    /// leaves.
    private func saveAndClose(_ record: MatchRecord) {
        Task { @MainActor in
            if let vitals = await workout.end() {
                var finished = record
                finished.vitals = vitals
                store.update(finished)
            }
            dismiss()
        }
    }
}

#Preview {
    MatchView(options: .default)
        .environmentObject(MatchStore())
}
