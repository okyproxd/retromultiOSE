import SwiftUI

struct SaveStatesTabView: View {
    @EnvironmentObject var store: LibraryStore
    @EnvironmentObject var processManager: EmulatorProcessManager

    var body: some View {
        List {
            ForEach(store.machines) { machine in
                if !machine.snapshots.isEmpty {
                    Section(machine.name) {
                        ForEach(machine.snapshots) { snap in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(snap.name).font(.headline)
                                    Text(snap.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Load State") {
                                    let controller = processManager.controller(for: machine.id)
                                    controller.loadState(named: snap.name, profile: machine, store: store) { _ in }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Save States")
        .overlay {
            if store.machines.allSatisfy({ $0.snapshots.isEmpty }) {
                ContentUnavailableView("No save states yet", systemImage: "clock.arrow.circlepath",
                    description: Text("Run a machine and tap Save State — give it a name, then come back here anytime to load it."))
            }
        }
    }
}
