import SwiftUI

@main
struct MetroStationApp: App {
    var body: some Scene {
        WindowGroup {
            InstrumentView()
                .preferredColorScheme(.dark)
                .tint(MetroStationTheme.cyan)
        }
    }
}
