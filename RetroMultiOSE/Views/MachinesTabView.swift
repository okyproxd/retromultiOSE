import SwiftUI

struct MachinesTabView: View {
    @EnvironmentObject var store: LibraryStore
    @EnvironmentObject var processManager: EmulatorProcessManager
    @Binding var showingNewMachineSheet: Bool
    @State private var selectedMachineID: MachineProfile.ID?

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(store.machines) { machine in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(machine.name).font(.headline)
                            Text(machine.backend.displayName).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            if selectedMachineID == machine.id { selectedMachineID = nil }
                            processManager.removeController(for: machine.id)
                            store.deleteMachine(machine)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 2)
                    .background(selectedMachineID == machine.id ? Color.accentColor.opacity(0.15) : .clear)
                    .onTapGesture {
                        selectedMachineID = machine.id
                    }
                }
            }
            .navigationTitle("Machines")
        } detail: {
            if let selected = store.machines.first(where: { $0.id == selectedMachineID }) {
                MachineDetailView(profile: selected, controller: processManager.controller(for: selected.id))
            } else {
                ContentUnavailableView("No machine selected", systemImage: "desktopcomputer",
                    description: Text("Tap a machine on the left, or tap + in the top-right to create one."))
            }
        }
    }
}

struct MachineDetailView: View {
    let profile: MachineProfile
    @ObservedObject var controller: EmulatorController
    @EnvironmentObject var store: LibraryStore
    @State private var selectedSpeed: SpeedPreset
    @State private var showingSaveNamePrompt = false
    @State private var snapshotNameInput = ""

    init(profile: MachineProfile, controller: EmulatorController) {
        self.profile = profile
        self.controller = controller
        _selectedSpeed = State(initialValue: profile.speedPreset)
    }

    private func defaultSnapshotName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(profile.name).font(.largeTitle.bold())
            Text(profile.backend.displayName).foregroundStyle(.secondary)

            Picker("CPU Speed", selection: $selectedSpeed) {
                ForEach(profile.backend.speedPresets, id: \.self) { preset in
                    Text(preset.label).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 420)

            HStack(spacing: 12) {
                Button {
                    var p = profile
                    p.speedPreset = selectedSpeed
                    controller.launch(profile: p, store: store)
                } label: {
                    Label(controller.isRunning ? "Running…" : "Run", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(controller.isRunning)

                Button {
                    snapshotNameInput = defaultSnapshotName()
                    showingSaveNamePrompt = true
                } label: {
                    Label("Save State", systemImage: "square.and.arrow.down")
                }
                .disabled(!controller.isRunning)

                Button(role: .destructive) {
                    controller.stop()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .disabled(!controller.isRunning)
            }

            if !profile.snapshots.isEmpty {
                Text("Save States").font(.subheadline.bold())
                ForEach(profile.snapshots) { snap in
                    HStack {
                        Text(snap.name)
                        Spacer()
                        Button("Load") {
                            controller.loadState(named: snap.name, profile: profile, store: store) { _ in }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            if let error = controller.lastError {
                Text(error).foregroundStyle(.red).font(.caption)
            }

            Spacer()
        }
        .padding(28)
        .alert("Name this Save State", isPresented: $showingSaveNamePrompt) {
            TextField("Name", text: $snapshotNameInput)
            Button("Save") {
                controller.saveState(named: snapshotNameInput, profile: profile, store: store) { _ in }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
