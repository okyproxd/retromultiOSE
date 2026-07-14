import SwiftUI

@main
struct RetroMultiOSEApp: App {
    @StateObject private var store = LibraryStore()
    @StateObject private var processManager = EmulatorProcessManager()

    var body: some Scene {
        WindowGroup("Retro MultiOSE") {
            ContentView()
                .environmentObject(store)
                .environmentObject(processManager)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
