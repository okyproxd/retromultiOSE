import SwiftUI

enum AppTab: Hashable {
    case setup, library, machines, saveStates
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .setup
    @State private var showingNewMachineSheet = false
    @EnvironmentObject var store: LibraryStore

    var body: some View {
        TabView(selection: $selectedTab) {
            SetupTabView()
                .tabItem { Label("Setup", systemImage: "gearshape") }
                .tag(AppTab.setup)

            LibraryTabView()
                .tabItem { Label("Library", systemImage: "opticaldisc") }
                .tag(AppTab.library)

            MachinesTabView(showingNewMachineSheet: $showingNewMachineSheet)
                .tabItem { Label("Machines", systemImage: "desktopcomputer") }
                .tag(AppTab.machines)

            SaveStatesTabView()
                .tabItem { Label("Save States", systemImage: "clock.arrow.circlepath") }
                .tag(AppTab.saveStates)
        }
        .tabViewStyle(.automatic)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    selectedTab = .machines
                    showingNewMachineSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("New Machine")
            }
        }
        .sheet(isPresented: $showingNewMachineSheet) {
            NewMachineSheet().environmentObject(store)
        }
    }
}
