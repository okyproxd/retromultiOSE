import Foundation
import Combine

/// Holds one EmulatorController per machine, independent of any SwiftUI
/// view's lifecycle. Without this, switching away from a running machine
/// and back tears down its controller and creates a fresh one that
/// thinks nothing is running — even though the real QEMU process is
/// still alive in the background.
final class EmulatorProcessManager: ObservableObject {
    private var controllers: [UUID: EmulatorController] = [:]

    func controller(for machineID: UUID) -> EmulatorController {
        if let existing = controllers[machineID] {
            return existing
        }
        let new = EmulatorController()
        controllers[machineID] = new
        return new
    }

    func removeController(for machineID: UUID) {
        controllers[machineID]?.stop()
        controllers.removeValue(forKey: machineID)
    }
}
