import Foundation
import WatchKit

/// Drives one match: applies points, keeps an undo stack and plays the haptics
/// that let you keep score without looking at the screen.
@MainActor
final class MatchController: ObservableObject {
    @Published private(set) var engine: MatchEngine

    /// A state of the match, and the point that led out of it.
    private struct Step {
        let engine: MatchEngine
        let scorer: Team
    }

    /// Every previous state of the match, newest last. A match is a few hundred
    /// small structs at most, so keeping them all is cheaper than replaying.
    private var undoStack: [Step] = []

    let startedAt: Date

    init(options: MatchOptions, startedAt: Date = Date()) {
        self.engine = MatchEngine(options: options)
        self.startedAt = startedAt
    }

    var canUndo: Bool { !undoStack.isEmpty }

    /// Who was given the point that undo would take back, so the button can
    /// say which side it is about to correct.
    var lastScorer: Team? { undoStack.last?.scorer }

    func score(_ team: Team) {
        guard !engine.isFinished else { return }

        var updated = engine
        updated.score(team)
        undoStack.append(Step(engine: engine, scorer: team))
        playFeedback(from: engine, to: updated)
        engine = updated
    }

    /// Takes back the last point, however far back into the match it reaches.
    func undo() {
        guard let previous = undoStack.popLast() else { return }
        engine = previous.engine
        WKInterfaceDevice.current().play(.click)
    }

    func makeRecord(vitals: MatchVitals? = nil, endedAt: Date = Date()) -> MatchRecord {
        MatchRecord(engine: engine, startedAt: startedAt, endedAt: endedAt, vitals: vitals)
    }

    private func playFeedback(from old: MatchEngine, to new: MatchEngine) {
        let device = WKInterfaceDevice.current()
        if new.isFinished {
            device.play(.success)
        } else if new.completedSets.count != old.completedSets.count {
            device.play(.notification)
        } else if new.games != old.games {
            device.play(.start)
        } else {
            device.play(.click)
        }
    }
}
