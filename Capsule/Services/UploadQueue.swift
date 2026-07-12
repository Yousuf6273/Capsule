import SwiftUI
import Network

// ── Milestone 2: blind contribution + offline-tolerant upload queue ──
// Media is copied into the app container and queued on disk immediately
// (the "sealed" moment is instant and offline-safe). A drain loop pushes
// queued items through the transport whenever connectivity allows.

struct PendingUpload: Identifiable, Codable, Equatable {
    let id: String
    let vaultId: String
    let originalFileName: String     // full-res original, staged locally
    let lockedThumbFileName: String  // blurred derivative for the sealed grid
    let mediaType: MediaType
    let capturedAt: Date
    let enqueuedAt: Date
    let byteSize: Int64
    var attemptCount: Int = 0
}

protocol UploadTransporting: Sendable {
    /// Pushes one item to the backend; returns the committed Memory record.
    func upload(_ item: PendingUpload, uploaderId: String) async throws -> Memory
}

/// Mock transport: "server" is the local disk. Simulates latency; the real
/// FirebaseTransport (Storage resumable upload + Firestore doc) slots in here.
struct MockUploadTransport: UploadTransporting {
    func upload(_ item: PendingUpload, uploaderId: String) async throws -> Memory {
        try await Task.sleep(for: .milliseconds(400))
        return Memory(
            id: item.id,
            vaultId: item.vaultId,
            uploaderId: uploaderId,
            mediaType: item.mediaType,
            lockedThumbFileName: item.lockedThumbFileName,
            mediaFileName: item.originalFileName,
            capturedAt: item.capturedAt,
            uploadedAt: .now,
            caption: nil,
            byteSize: item.byteSize)
    }
}

@MainActor
@Observable
final class UploadQueue {
    private(set) var pending: [PendingUpload] = []
    private(set) var isOnline = true
    private(set) var isDraining = false

    private let transport: UploadTransporting
    private let monitor = NWPathMonitor()
    private let fileURL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("uploadQueue.json")

    weak var memoryStore: MemoryStore?
    var uploaderId: String = ""
    var onUploaded: ((Memory) -> Void)?

    init(transport: UploadTransporting = MockUploadTransport()) {
        self.transport = transport
        load()
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let wasOffline = !self.isOnline
                self.isOnline = path.status == .satisfied
                if wasOffline && self.isOnline { self.drain() }
            }
        }
        monitor.start(queue: DispatchQueue(label: "capsule.netmonitor"))
        drain()
    }

    func pendingCount(vaultId: String) -> Int {
        pending.filter { $0.vaultId == vaultId }.count
    }

    /// Seals a memory: stages the original + locked thumb on disk, queues, drains.
    /// Returns the locked thumbnail for immediate UI feedback.
    @discardableResult
    func enqueue(imageData: Data, vaultId: String, capturedAt: Date, mediaType: MediaType = .photo) -> UIImage? {
        guard let image = UIImage(data: imageData),
              let locked = CollectingView.lockedThumbnail(from: image),
              let lockedData = locked.jpegData(compressionQuality: 0.7) else { return nil }

        let id = UUID().uuidString
        let originalName = "sealed-\(id).jpg"
        let thumbName = "thumb-\(id).jpg"
        do {
            try LocalStore.save(data: imageData, fileName: originalName)
            try LocalStore.save(data: lockedData, fileName: thumbName)
        } catch {
            return nil
        }

        let item = PendingUpload(
            id: id, vaultId: vaultId,
            originalFileName: originalName, lockedThumbFileName: thumbName,
            mediaType: mediaType, capturedAt: capturedAt, enqueuedAt: .now,
            byteSize: Int64(imageData.count))
        pending.append(item)
        persist()
        drain()
        return locked
    }

    /// Pushes queued items while online; backs off on failure, never drops items.
    func drain() {
        guard !isDraining else { return }
        isDraining = true
        Task {
            defer { isDraining = false }
            while isOnline, let item = pending.first {
                do {
                    let memory = try await transport.upload(item, uploaderId: uploaderId)
                    memoryStore?.add(memory)
                    pending.removeAll { $0.id == item.id }
                    persist()
                    onUploaded?(memory)
                } catch {
                    if let idx = pending.firstIndex(of: item) {
                        pending[idx].attemptCount += 1
                    }
                    persist()
                    // Exponential-ish backoff; the path monitor also re-triggers.
                    try? await Task.sleep(for: .seconds(min(30, 2 << min(pending.first?.attemptCount ?? 0, 3))))
                }
            }
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([PendingUpload].self, from: data) else { return }
        pending = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(pending) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
