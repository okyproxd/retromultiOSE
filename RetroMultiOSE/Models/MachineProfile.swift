import Foundation

enum EmulationBackend: String, Codable, CaseIterable, Identifiable {
    case qemuPPC
    case qemuX86
    case sheepShaver
    case basiliskII

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .qemuPPC: return "QEMU (PowerPC)"
        case .qemuX86: return "QEMU (x86_64)"
        case .sheepShaver: return "SheepShaver (68k/PPC)"
        case .basiliskII: return "Basilisk II (68k)"
        }
    }

    var speedPresets: [SpeedPreset] {
        switch self {
        case .basiliskII:
            return [
                .init(label: "100% – 68030", icountShift: nil, throttlePercent: 100),
                .init(label: "75% – 68020",  icountShift: nil, throttlePercent: 75),
                .init(label: "50% – 68000",  icountShift: nil, throttlePercent: 50),
            ]
        case .sheepShaver, .qemuPPC:
            return [
                .init(label: "100% – Full speed PPC", icountShift: nil, throttlePercent: 100),
                .init(label: "75%", icountShift: 2, throttlePercent: 75),
                .init(label: "50%", icountShift: 4, throttlePercent: 50),
            ]
        case .qemuX86:
            return [
                .init(label: "100% – Full speed", icountShift: nil, throttlePercent: 100),
                .init(label: "75%", icountShift: 2, throttlePercent: 75),
                .init(label: "50%", icountShift: 4, throttlePercent: 50),
            ]
        }
    }
}

struct SpeedPreset: Codable, Hashable {
    let label: String
    let icountShift: Int?
    let throttlePercent: Int
}

struct AttachedDisk: Codable, Hashable, Identifiable {
    enum Role: String, Codable {
        case cdrom
        case hardDisk
    }
    var id: UUID = UUID()
    var path: String
    var role: Role
    var ownedByMachine: Bool = false
}

struct SaveStateEntry: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var createdAt: Date = Date()
}

enum RAMUnit: String, CaseIterable, Identifiable {
    case kb = "KB"
    case mb = "MB"
    case gb = "GB"
    var id: String { rawValue }

    /// Multiplier to convert a value in this unit into kilobytes.
    var toKB: Double {
        switch self {
        case .kb: return 1
        case .mb: return 1024
        case .gb: return 1024 * 1024
        }
    }
}

struct MachineProfile: Codable, Identifiable, Hashable {
    static let minRAMKB = 128            // 128 KB — real Mac 128K minimum
    static let maxRAMKB = 8 * 1024 * 1024 // 8 GB

    var id: UUID = UUID()
    var name: String
    var backend: EmulationBackend
    var romOrFirmwarePath: String?
    var disks: [AttachedDisk] = []
    var ramKB: Int = 512 * 1024   // default 512 MB, expressed in KB
    var speedPreset: SpeedPreset
    var snapshots: [SaveStateEntry] = []
    var createdAt: Date = Date()

    /// Human-friendly display of the configured RAM, auto-picking a sensible unit.
    var ramDisplayString: String {
        if ramKB < 1024 {
            return "\(ramKB) KB"
        } else if ramKB < 1024 * 1024 {
            let mb = Double(ramKB) / 1024
            return mb.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(mb)) MB" : String(format: "%.1f MB", mb)
        } else {
            let gb = Double(ramKB) / (1024 * 1024)
            return gb.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(gb)) GB" : String(format: "%.2f GB", gb)
        }
    }

    static func == (lhs: MachineProfile, rhs: MachineProfile) -> Bool { lhs.id == rhs.id }
}
