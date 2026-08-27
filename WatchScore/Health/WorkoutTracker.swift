import Foundation
import HealthKit

/// Runs a HealthKit workout for the length of a match.
///
/// The point is mostly that watchOS keeps an app with a running workout
/// session awake and in the foreground: without one, dropping your wrist
/// between points puts the app to sleep and you come back to the watch face.
/// Heart rate, calories and a workout saved to Health come along with it.
///
/// Scoring never depends on any of this. If Health is unavailable or the
/// permission is declined, every method here quietly does nothing.
@MainActor
final class WorkoutTracker: NSObject, ObservableObject {
    /// The most recent heart rate reading, nil until the first one arrives.
    @Published private(set) var heartRate: Int?
    @Published private(set) var activeCalories = 0
    /// True once watchOS has the session actually running.
    @Published private(set) var isRunning = false

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    // MARK: - Running a match

    func start(for sport: Sport) async {
        guard HKHealthStore.isHealthDataAvailable(), session == nil else { return }

        let toShare: Set<HKSampleType> = [HKQuantityType.workoutType()]
        let toRead: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
        ]

        do {
            try await healthStore.requestAuthorization(toShare: toShare, read: toRead)

            let configuration = HKWorkoutConfiguration()
            configuration.activityType = sport.workoutActivityType
            configuration.locationType = sport.workoutLocationType

            let session = try HKWorkoutSession(healthStore: healthStore,
                                               configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore,
                                                         workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self

            let startDate = Date()
            session.startActivity(with: startDate)
            try await builder.beginCollection(at: startDate)

            self.session = session
            self.builder = builder
            self.isRunning = true
        } catch {
            // A match is still perfectly playable without any of this.
            print("Could not start the workout: \(error)")
            clear()
        }
    }

    /// Closes the workout and hands back what it measured, or nil if it
    /// measured nothing worth showing.
    func end() async -> MatchVitals? {
        guard let session, let builder else { return nil }

        session.end()
        var vitals: MatchVitals?

        do {
            try await builder.endCollection(at: Date())

            // Read the totals before finishing: the builder is done afterwards.
            let beatsPerMinute = HKUnit.count().unitDivided(by: .minute())
            vitals = MatchVitals(
                averageHeartRate: value(from: builder, .heartRate, in: beatsPerMinute) { $0.averageQuantity() },
                maxHeartRate: value(from: builder, .heartRate, in: beatsPerMinute) { $0.maximumQuantity() },
                activeCalories: value(from: builder, .activeEnergyBurned, in: .kilocalorie()) { $0.sumQuantity() }
            )

            _ = try await builder.finishWorkout()
        } catch {
            print("Could not finish the workout: \(error)")
        }

        clear()
        return vitals?.isEmpty == false ? vitals : nil
    }

    private func value(from builder: HKLiveWorkoutBuilder,
                       _ identifier: HKQuantityTypeIdentifier,
                       in unit: HKUnit,
                       pick: (HKStatistics) -> HKQuantity?) -> Int? {
        guard let statistics = builder.statistics(for: HKQuantityType(identifier)),
              let quantity = pick(statistics) else { return nil }
        return Int(quantity.doubleValue(for: unit).rounded())
    }

    private func clear() {
        session = nil
        builder = nil
        isRunning = false
    }
}

// MARK: - Session state

extension WorkoutTracker: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState,
                                    date: Date) {
        let running = toState == .running
        Task { @MainActor [weak self] in
            self?.isRunning = running
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didFailWithError error: Error) {
        print("Workout session failed: \(error)")
        Task { @MainActor [weak self] in
            self?.clear()
        }
    }
}

// MARK: - Live samples

extension WorkoutTracker: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                                    didCollectDataOf collectedTypes: Set<HKSampleType>) {
        // This lands on a background queue, so only plain numbers are carried
        // back to the main actor, never the HealthKit objects themselves.
        var newHeartRate: Int?
        var newCalories: Int?

        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType,
                  let statistics = workoutBuilder.statistics(for: quantityType) else { continue }

            if quantityType == HKQuantityType(.heartRate) {
                let unit = HKUnit.count().unitDivided(by: .minute())
                if let bpm = statistics.mostRecentQuantity()?.doubleValue(for: unit) {
                    newHeartRate = Int(bpm.rounded())
                }
            } else if quantityType == HKQuantityType(.activeEnergyBurned) {
                if let kcal = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                    newCalories = Int(kcal.rounded())
                }
            }
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            if let newHeartRate { self.heartRate = newHeartRate }
            if let newCalories { self.activeCalories = newCalories }
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Pauses and laps are not used here.
    }
}

// MARK: - How each sport is logged

private extension Sport {
    /// watchOS has no padel activity type; racquetball is the closest thing
    /// on an enclosed court.
    var workoutActivityType: HKWorkoutActivityType {
        switch self {
        case .tennis: return .tennis
        case .padel: return .racquetball
        }
    }

    /// Only decides whether GPS is used. Neither sport tracks distance, so
    /// padel stays indoor to save the battery.
    var workoutLocationType: HKWorkoutSessionLocationType {
        switch self {
        case .tennis: return .outdoor
        case .padel: return .indoor
        }
    }
}
