import SwiftUI
import UniformTypeIdentifiers

struct NewMachineSheet: View {
    @EnvironmentObject var store: LibraryStore
    @Environment(\.dismiss) var dismiss

    @State private var name = "New Machine"
    @State private var backend: EmulationBackend = .qemuPPC
    @State private var romPath: String?
    @State private var selectedCD: URL?

    @State private var diskMode: DiskMode = .createNew
    @State private var selectedExistingDisk: URL?
    @State private var newDiskName = "Hard Disk"
    @State private var newDiskSizeGBText = "2.0"
    @State private var showingUploadPicker = false
    @State private var uploadedDiskURL: URL?

    @State private var ramValueText = "512"
    @State private var ramUnit: RAMUnit = .mb
    @State private var ramErrorText: String?

    enum DiskMode: String, CaseIterable, Identifiable {
        case createNew = "Create New"
        case useExisting = "Use Existing"
        case upload = "Upload"
        var id: String { rawValue }
    }

    private var newDiskSizeMB: Int {
        let gb = Double(newDiskSizeGBText) ?? 2.0
        return max(128, Int(gb * 1024))
    }

    private var candidateExistingDisks: [URL] {
        store.diskImages.filter { url in
            let ext = url.pathExtension.lowercased()
            return ext == "qcow2" || ext == "img" || ext == "vhd" || ext == "vdi" || ext == "dsk" || ext == "hda"
        }
    }

    private func resolvedRAMKB() -> Int? {
        guard let raw = Double(ramValueText), raw > 0 else {
            ramErrorText = "Enter a RAM amount greater than 0."
            return nil
        }
        let kb = Int(raw * ramUnit.toKB)
        if kb < MachineProfile.minRAMKB {
            ramErrorText = "Minimum is 128 KB."
            return nil
        }
        if kb > MachineProfile.maxRAMKB {
            ramErrorText = "Maximum is 8 GB."
            return nil
        }
        ramErrorText = nil
        return kb
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Machine").font(.title2.bold())

            TextField("Name", text: $name)

            Picker("System type", selection: $backend) {
                ForEach(EmulationBackend.allCases) { b in Text(b.displayName).tag(b) }
            }

            Picker("ROM / Firmware", selection: $romPath) {
                Text("None").tag(String?.none)
                ForEach(store.romFiles, id: \.self) { url in
                    Text(url.lastPathComponent).tag(Optional(url.path))
                }
            }

            Text("Boot CD / Installer").font(.subheadline.bold())
            Text("Pick the install disc or ISO this machine boots from. Leave none selected if you're just reattaching an already-installed hard disk.")
                .font(.caption).foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(store.diskImages, id: \.self) { url in
                        HStack {
                            Image(systemName: selectedCD == url ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedCD == url ? Color.accentColor : .secondary)
                            Text(url.lastPathComponent).lineLimit(1)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(selectedCD == url ? Color.accentColor.opacity(0.12) : .clear,
                                    in: RoundedRectangle(cornerRadius: 6))
                        .onTapGesture {
                            selectedCD = (selectedCD == url) ? nil : url
                        }
                    }
                }
            }
            .frame(height: 100)

            Text("Hard Disk").font(.subheadline.bold())
            Picker("", selection: $diskMode) {
                ForEach(DiskMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch diskMode {
            case .createNew:
                HStack {
                    TextField("Disk name", text: $newDiskName)
                        .frame(width: 160)
                    TextField("Size (GB)", text: $newDiskSizeGBText)
                        .frame(width: 70)
                        .multilineTextAlignment(.trailing)
                    Text("GB")
                }
                Text("This disk belongs to this machine and is deleted with it.")
                    .font(.caption).foregroundStyle(.secondary)

            case .useExisting:
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(candidateExistingDisks, id: \.self) { url in
                            HStack {
                                Image(systemName: selectedExistingDisk == url ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedExistingDisk == url ? Color.accentColor : .secondary)
                                Text(url.lastPathComponent).lineLimit(1)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(selectedExistingDisk == url ? Color.accentColor.opacity(0.12) : .clear,
                                        in: RoundedRectangle(cornerRadius: 6))
                            .onTapGesture {
                                selectedExistingDisk = (selectedExistingDisk == url) ? nil : url
                            }
                        }
                    }
                }
                .frame(height: 100)
                Text("Reattaching an existing disk keeps it independent — deleting this machine will NOT delete this disk.")
                    .font(.caption).foregroundStyle(.secondary)

            case .upload:
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        showingUploadPicker = true
                    } label: {
                        Label("Choose .img / .dsk / .hda File", systemImage: "tray.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    if let uploadedDiskURL {
                        Label(uploadedDiskURL.lastPathComponent, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.callout)
                    }
                }
                Text("Imports a copy into your library, then attaches it as this machine's hard disk (e.g. a MacPack volume).")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Text("RAM").font(.subheadline.bold())
            HStack {
                TextField("Amount", text: $ramValueText)
                    .frame(width: 100)
                Picker("", selection: $ramUnit) {
                    ForEach(RAMUnit.allCases) { unit in Text(unit.rawValue).tag(unit) }
                }
                .labelsHidden()
                .frame(width: 90)
                Spacer()
                Text("Range: 128 KB – 8 GB")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let ramErrorText {
                Text(ramErrorText).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Create") {
                    guard let ramKB = resolvedRAMKB() else { return }

                    var disks: [AttachedDisk] = []
                    if let cd = selectedCD {
                        disks.append(AttachedDisk(path: cd.path, role: .cdrom, ownedByMachine: false))
                    }
                    switch diskMode {
                    case .createNew:
                        let uniqueName = "\(name)-\(newDiskName)"
                        if let hdURL = store.createBlankDisk(name: uniqueName, sizeMB: newDiskSizeMB) {
                            disks.append(AttachedDisk(path: hdURL.path, role: .hardDisk, ownedByMachine: true))
                        }
                    case .useExisting:
                        if let existing = selectedExistingDisk {
                            disks.append(AttachedDisk(path: existing.path, role: .hardDisk, ownedByMachine: false))
                        }
                    case .upload:
                        if let uploaded = uploadedDiskURL {
                            disks.append(AttachedDisk(path: uploaded.path, role: .hardDisk, ownedByMachine: false))
                        }
                    }
                    let profile = MachineProfile(
                        name: name,
                        backend: backend,
                        romOrFirmwarePath: romPath,
                        disks: disks,
                        ramKB: ramKB,
                        speedPreset: backend.speedPresets[0]
                    )
                    store.addMachine(profile)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(diskCreateDisabled)
            }
        }
        .padding(24)
        .frame(width: 520)
        .fileImporter(
            isPresented: $showingUploadPicker,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                let gotAccess = url.startAccessingSecurityScopedResource()
                defer { if gotAccess { url.stopAccessingSecurityScopedResource() } }
                uploadedDiskURL = store.importFile(from: url, into: .diskImage)
            }
        }
    }

    private var diskCreateDisabled: Bool {
        if selectedCD == nil {
            switch diskMode {
            case .useExisting: return selectedExistingDisk == nil
            case .upload: return uploadedDiskURL == nil
            case .createNew: return false
            }
        }
        return false
    }
}
