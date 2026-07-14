import SwiftUI
import UniformTypeIdentifiers

struct SetupTabView: View {
    @EnvironmentObject var store: LibraryStore
    @State private var showingPicker = false
    @State private var pendingImportKind: LibraryStore.ImportKind = .rom
    @State private var importStatus: String?

    private var hardDiskExtensions: Set<String> = ["qcow2", "img", "vhd", "vdi"]

    private var hardDisks: [URL] {
        store.diskImages.filter { hardDiskExtensions.contains($0.pathExtension.lowercased()) }
    }

    private var bootMedia: [URL] {
        store.diskImages.filter { !hardDiskExtensions.contains($0.pathExtension.lowercased()) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                header("ROMs & Firmware",
                       "Upload the Mac ROM image, Open Firmware, or OVMF file needed to boot a system.")
                uploadRow(buttonLabel: "Upload ROM / Firmware", systemImage: "cpu") {
                    pendingImportKind = .rom
                    showingPicker = true
                }
                fileGrid(store.romFiles) { url in store.deleteROM(url) }

                Divider()

                header("Boot CDs & Installer ISOs",
                       "Upload as many .iso/.dsk/.hfv files as you like — installers, "
                       + "MacPack app compilations for System 5–7, anything.")
                uploadRow(buttonLabel: "Upload Disk Image(s)", systemImage: "tray.and.arrow.up") {
                    pendingImportKind = .diskImage
                    showingPicker = true
                }
                fileGrid(bootMedia) { url in store.deleteDiskImage(url) }

                Divider()

                header("Hard Disks",
                       "Virtual hard disks (.qcow2/.img) — created per-machine, or uploaded here. Delete freely; this won't touch any ISO above.")
                fileGrid(hardDisks) { url in store.deleteDiskImage(url) }

                if let status = importStatus {
                    Text(status).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
        .fileImporter(
            isPresented: $showingPicker,
            allowedContentTypes: [.data],
            allowsMultipleSelection: true
        ) { result in
            handleImport(result, kind: pendingImportKind)
        }
    }

    private func header(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title2.bold())
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func uploadRow(buttonLabel: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(buttonLabel, systemImage: systemImage)
                .padding(.horizontal, 14).padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
    }

    private func fileGrid(_ urls: [URL], onDelete: @escaping (URL) -> Void) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
            ForEach(urls, id: \.self) { url in
                VStack(spacing: 6) {
                    HStack {
                        Spacer()
                        Button {
                            onDelete(url)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                    Image(systemName: "doc")
                        .font(.system(size: 28))
                    Text(url.lastPathComponent)
                        .font(.caption)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>, kind: LibraryStore.ImportKind) {
        switch result {
        case .success(let urls):
            for url in urls {
                let gotAccess = url.startAccessingSecurityScopedResource()
                defer { if gotAccess { url.stopAccessingSecurityScopedResource() } }
                store.importFile(from: url, into: kind)
            }
            importStatus = "Imported \(urls.count) file(s)."
        case .failure(let error):
            importStatus = "Import failed: \(error.localizedDescription)"
        }
    }
}
