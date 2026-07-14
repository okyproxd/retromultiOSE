import Foundation
import Combine

final class LibraryStore: ObservableObject {
    @Published var machines: [MachineProfile] = []
    @Published var romFiles: [URL] = []
    @Published var diskImages: [URL] = []

    private let fm = FileManager.default

    var baseDir: URL {
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RetroMultiOSE", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    var romsDir: URL { subdir("ROMs") }
    var disksDir: URL { subdir("DiskImages") }
    var snapshotsDir: URL { subdir("SaveStates") }
    var profilesFile: URL { baseDir.appendingPathComponent("machines.json") }

    private func subdir(_ name: String) -> URL {
        let dir = baseDir.appendingPathComponent(name, isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    init() {
        reloadAll()
    }

    func reloadAll() {
        romFiles = (try? fm.contentsOfDirectory(at: romsDir, includingPropertiesForKeys: nil)) ?? []
        diskImages = (try? fm.contentsOfDirectory(at: disksDir, includingPropertiesForKeys: nil)) ?? []

        guard let data = try? Data(contentsOf: profilesFile) else {
            machines = []
            return
        }

        if let decoded = try? JSONDecoder().decode([MachineProfile].self, from: data) {
            machines = decoded
            return
        }

        // Decoding the current model failed — most likely because the
        // saved file predates a schema change. Rather than silently
        // wiping the list, back up the old file (so nothing is lost)
        // and surface that recovery happened, instead of pretending
        // there were never any machines.
        let backupURL = baseDir.appendingPathComponent("machines-backup-\(Int(Date().timeIntervalSince1970)).json")
        try? data.write(to: backupURL)
        print("⚠️ machines.json could not be decoded with the current model — backed up to \(backupURL.lastPathComponent). Machines will need to be recreated, but the backup file preserves the old data for reference.")
        machines = []
    }

    func saveMachines() {
        if let data = try? JSONEncoder().encode(machines) {
            try? data.write(to: profilesFile)
        }
    }

    @discardableResult
    func importFile(from sourceURL: URL, into kind: ImportKind) -> URL? {
        let destDir = (kind == .rom) ? romsDir : disksDir
        let dest = destDir.appendingPathComponent(sourceURL.lastPathComponent)
        do {
            if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
            try fm.copyItem(at: sourceURL, to: dest)
            reloadAll()
            return dest
        } catch {
            print("Import failed: \(error)")
            return nil
        }
    }

    @discardableResult
    func createBlankDisk(name: String, sizeMB: Int) -> URL? {
        var fileName = name
        if !fileName.lowercased().hasSuffix(".qcow2") { fileName += ".qcow2" }
        let dest = disksDir.appendingPathComponent(fileName)
        guard !fm.fileExists(atPath: dest.path) else { return nil }
        guard let qemuImg = Bundle.main.resourceURL?.appendingPathComponent("qemu-img"),
              fm.fileExists(atPath: qemuImg.path) else {
            print("qemu-img not bundled — copy it into Resources/qemu/ (see build notes).")
            return nil
        }
        let proc = Process()
        proc.executableURL = qemuImg
        proc.arguments = ["create", "-f", "qcow2", dest.path, "\(sizeMB)M"]
        do {
            try proc.run()
            proc.waitUntilExit()
            guard proc.terminationStatus == 0 else { return nil }
        } catch {
            return nil
        }
        reloadAll()
        return dest
    }

    func deleteROM(_ url: URL) {
        try? fm.removeItem(at: url)
        reloadAll()
    }

    func deleteDiskImage(_ url: URL) {
        try? fm.removeItem(at: url)
        reloadAll()
    }

    enum ImportKind { case rom, diskImage }

    func addMachine(_ profile: MachineProfile) {
        machines.append(profile)
        saveMachines()
    }

    func updateMachine(_ profile: MachineProfile) {
        if let idx = machines.firstIndex(where: { $0.id == profile.id }) {
            machines[idx] = profile
            saveMachines()
        }
    }

    func deleteMachine(_ profile: MachineProfile) {
        machines.removeAll { $0.id == profile.id }
        saveMachines()
        for disk in profile.disks where disk.ownedByMachine {
            try? fm.removeItem(atPath: disk.path)
        }
        for snap in profile.snapshots {
            try? fm.removeItem(at: snapshotsDir.appendingPathComponent(snap.name))
        }
        reloadAll()
    }
}
