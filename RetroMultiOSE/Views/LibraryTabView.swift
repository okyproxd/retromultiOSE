import SwiftUI

struct LibraryTabView: View {
    @EnvironmentObject var store: LibraryStore

    var body: some View {
        NavigationSplitView {
            List {
                Section("ROMs / Firmware") {
                    ForEach(store.romFiles, id: \.self) { Text($0.lastPathComponent) }
                }
                Section("Disk Images") {
                    ForEach(store.diskImages, id: \.self) { Text($0.lastPathComponent) }
                }
            }
            .navigationTitle("Library")
        } detail: {
            Text("Select a file to see details, or head to Setup to import more.")
                .foregroundStyle(.secondary)
        }
    }
}
