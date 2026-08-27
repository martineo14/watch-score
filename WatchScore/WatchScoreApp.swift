import SwiftUI

@main
struct WatchScoreApp: App {
    @StateObject private var store = MatchStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
