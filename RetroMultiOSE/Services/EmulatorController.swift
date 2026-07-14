import Foundation
import Combine

final class EmulatorController: ObservableObject {
    @Published var isRunning = false
    @Published var lastError: String?

    private var process: Process?
    private var monitorSocketPath: String?
    private var stderrPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var capturedOutput = ""

    private var resourcesDir: URL {
        Bundle.main.resourceURL!
    }

    private func binaryPath(for backend: EmulationBackend) -> URL {
        switch backend {
        case .qemuPPC:     return resourcesDir.appendingPathComponent("qemu-system-ppc")
        case .qemuX86:     return resourcesDir.appendingPathComponent("qemu-system-x86_64")
        case .sheepShaver: return resourcesDir.appendingPathComponent("SheepShaver")
        case .basiliskII:  return resourcesDir.appendingPathComponent("BasiliskII")
        }
    }

    private func driveFormat(for path: String) -> String {
        path.lowercased().hasSuffix(".qcow2") ? "qcow2" : "raw"
    }

    func launch(profile: MachineProfile, store: LibraryStore, loadSnapshotName: String? = nil) {
        let binary = binaryPath(for: profile.backend)
        guard FileManager.default.fileExists(atPath: binary.path) else {
            lastError = "\(profile.backend.displayName) binary not bundled. See build_qemu.sh."
            return
        }

        let cdroms = profile.disks.filter { $0.role == .cdrom }
        let hardDisks = profile.disks.filter { $0.role == .hardDisk }

        var args: [String] = []

        switch profile.backend {
        case .qemuPPC, .qemuX86:
            let ramMB = max(1, profile.ramKB / 1024)
            args += ["-L", resourcesDir.path]
            args += ["-m", "\(ramMB)"]
            args += ["-display", "cocoa"]

            if profile.backend == .qemuX86 {
                args += ["-accel", "tcg"]
                for disk in hardDisks {
                    args += ["-drive", "file=\(disk.path),format=\(driveFormat(for: disk.path)),media=disk"]
                }
                for cd in cdroms {
                    args += ["-cdrom", cd.path]
                }
                if !cdroms.isEmpty {
                    args += ["-boot", "d"]
                }
            } else {
                args += ["-accel", "tcg,thread=multi"]
                args += ["-M", "mac99,via=pmu"]
                args += ["-cpu", "G4"]
                args += ["-prom-env", "auto-boot?=true"]
                args += ["-prom-env", "vga-ndrv?=true"]
                for (i, disk) in hardDisks.enumerated() {
                    args += ["-device", "ide-hd,bus=ide.0,unit=0,drive=hd\(i)"]
                    args += ["-drive", "id=hd\(i),if=none,file=\(disk.path),format=\(driveFormat(for: disk.path))"]
                }
                for cd in cdroms {
                    args += ["-device", "ide-cd,bus=ide.0,unit=1,drive=cd0,bootindex=1"]
                    args += ["-drive", "id=cd0,if=none,file=\(cd.path),media=cdrom,cache=unsafe"]
                }
            }

            let sockPath = store.baseDir.appendingPathComponent("\(profile.id).sock").path
            try? FileManager.default.removeItem(atPath: sockPath)
            monitorSocketPath = sockPath
            args += ["-monitor", "unix:\(sockPath),server,nowait"]

            if let shift = profile.speedPreset.icountShift {
                args += ["-icount", "shift=\(shift)"]
            }
            if let snap = loadSnapshotName {
                args += ["-loadvm", snap]
            }

        case .sheepShaver, .basiliskII:
            let prefsURL = store.baseDir.appendingPathComponent("\(profile.id)-prefs.txt")
            writeClassicPrefs(profile: profile, to: prefsURL)
            args += ["--config", prefsURL.path]
        }

        let proc = Process()
        proc.executableURL = binary
        proc.arguments = args
        proc.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser

        let errPipe = Pipe()
        let outPipe = Pipe()
        proc.standardError = errPipe
        proc.standardOutput = outPipe
        stderrPipe = errPipe
        stdoutPipe = outPipe
        capturedOutput = ""

        let handleOutput: (FileHandle) -> Void = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                guard let self else { return }
                self.capturedOutput += text
                let trimmed = self.capturedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    let lines = trimmed.components(separatedBy: "\n")
                    self.lastError = lines.suffix(5).joined(separator: "\n")
                }
            }
        }

        errPipe.fileHandleForReading.readabilityHandler = handleOutput
        outPipe.fileHandleForReading.readabilityHandler = handleOutput

        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.stderrPipe?.fileHandleForReading.readabilityHandler = nil
                self?.stdoutPipe?.fileHandleForReading.readabilityHandler = nil
            }
        }

        do {
            try proc.run()
            process = proc
            isRunning = true
            lastError = nil
        } catch {
            lastError = "Failed to launch: \(error.localizedDescription)"
        }
    }

    private func writeClassicPrefs(profile: MachineProfile, to url: URL) {
        var lines: [String] = []
        if let rom = profile.romOrFirmwarePath { lines.append("rom \(rom)") }
        for disk in profile.disks {
            let key = (disk.role == .cdrom) ? "cdrom" : "disk"
            lines.append("\(key) \(disk.path)")
        }
        lines.append("ramsize \(profile.ramKB * 1024)")
        lines.append("modelid \(profile.backend == .sheepShaver ? 5 : 3)")
        // Documented fixes for Basilisk II crashing/hanging a few seconds
        // into boot, specifically on modern macOS / Apple Silicon hosts —
        // ignoresegv prevents the common SIGSEGV-during-startup crash,
        // idlewait improves emulation stability, jit disabled since the
        // 68k JIT engine predates Apple Silicon and can misbehave there.
        lines.append("ignoresegv true")
        lines.append("idlewait true")
        lines.append("jit false")
        try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    func saveState(named name: String, profile: MachineProfile, store: LibraryStore, completion: @escaping (Bool) -> Void) {
        guard let sockPath = monitorSocketPath else {
            lastError = "Save State failed: machine is not running."
            completion(false)
            return
        }
        sendMonitorCommand("savevm \(name)\n", socketPath: sockPath) { [weak self] success, message in
            DispatchQueue.main.async {
                if success {
                    var updated = profile
                    updated.snapshots.append(SaveStateEntry(name: name))
                    store.updateMachine(updated)
                    self?.lastError = "Save State response: \(message)"
                    completion(true)
                } else {
                    self?.lastError = "Save State failed: \(message)"
                    completion(false)
                }
            }
        }
    }

    func loadState(named name: String, profile: MachineProfile, store: LibraryStore, completion: @escaping (Bool) -> Void) {
        if isRunning, let sockPath = monitorSocketPath {
            sendMonitorCommand("loadvm \(name)\n", socketPath: sockPath) { [weak self] success, message in
                DispatchQueue.main.async {
                    if !success { self?.lastError = "Load State failed: \(message)" }
                    completion(success)
                }
            }
        } else {
            launch(profile: profile, store: store, loadSnapshotName: name)
            completion(true)
        }
    }

    func swapDisc(to newDiskPath: String, completion: @escaping (Bool) -> Void) {
        guard let sockPath = monitorSocketPath else { completion(false); return }
        sendMonitorCommand("eject cd0\n", socketPath: sockPath) { [weak self] _, _ in
            self?.sendMonitorCommand("change cd0 \(newDiskPath)\n", socketPath: sockPath) { success, _ in
                completion(success)
            }
        }
    }

    func stop() {
        process?.terminate()
        isRunning = false
    }

    private func sendMonitorCommand(_ command: String, socketPath: String, completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let fd = socket(AF_UNIX, SOCK_STREAM, 0)
            guard fd >= 0 else { completion(false, "Could not open socket"); return }
            defer { close(fd) }

            var addr = sockaddr_un()
            addr.sun_family = sa_family_t(AF_UNIX)
            let pathBytes = socketPath.utf8CString
            withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { dst in
                    _ = pathBytes.withUnsafeBufferPointer { src in
                        memcpy(dst, src.baseAddress, min(src.count, 104))
                    }
                }
            }
            let len = socklen_t(MemoryLayout<sockaddr_un>.size)
            let connectResult = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    connect(fd, $0, len)
                }
            }
            guard connectResult == 0 else { completion(false, "Could not connect to monitor"); return }

            var tv = timeval()
            tv.tv_sec = 1
            tv.tv_usec = 0
            setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

            var junk = [UInt8](repeating: 0, count: 4096)
            _ = recv(fd, &junk, junk.count, 0)

            _ = command.withCString { write(fd, $0, strlen($0)) }

            var buffer = [UInt8](repeating: 0, count: 4096)
            let bytesRead = recv(fd, &buffer, buffer.count, 0)
            let response = bytesRead > 0 ? (String(bytes: buffer[0..<bytesRead], encoding: .utf8) ?? "") : ""

            if response.lowercased().contains("error") {
                completion(false, response.trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                completion(true, response.isEmpty ? "(no response text)" : response)
            }
        }
    }
}
