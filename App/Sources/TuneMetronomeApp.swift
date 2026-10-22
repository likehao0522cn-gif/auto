import SwiftUI

@main
struct TuneMetronomeApp: App {
    @StateObject private var appModel = AppModel()
    @StateObject private var metronome = MetronomeViewModel()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView()
            }
            .environmentObject(appModel)
            .environmentObject(metronome)
        }
    }
}
