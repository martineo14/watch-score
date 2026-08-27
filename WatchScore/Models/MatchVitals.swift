import Foundation

/// What the watch measured while the match was played.
///
/// Every field is optional: Health access can be declined, and the simulator
/// has no heart rate sensor at all, so a match may be scored with no vitals
/// behind it.
struct MatchVitals: Codable, Equatable {
    var averageHeartRate: Int?
    var maxHeartRate: Int?
    var activeCalories: Int?

    var isEmpty: Bool {
        averageHeartRate == nil && maxHeartRate == nil && activeCalories == nil
    }
}
