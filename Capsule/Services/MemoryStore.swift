import AVFoundation
import SwiftUI

/// Poster frames for videos — extracted once, cached.
enum MediaPoster {
    private static let cache = NSCache<NSString, UIImage>()

    static func firstFrame(of url: URL) -> UIImage? {
        let key = url.lastPathComponent as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1200, height: 1200)
        // Sample slightly in so we skip black lead-in frames.
        let time = CMTime(seconds: 0.4, preferredTimescale: 600)
        var cgImage = try? generator.copyCGImage(at: time, actualTime: nil)
        if cgImage == nil {
            cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil)
        }
        guard let cg = cgImage else { return nil }
        let image = UIImage(cgImage: cg)
        cache.setObject(image, forKey: key)
        return image
    }
}

/// Persistent store of memory records (disk-backed JSON in the mock stack;
/// replaced by Firestore in the live stack). Placeholder art stands in for
/// media in sample vaults so reveal/quiz/recap are demoable without a backend.
@MainActor
@Observable
final class MemoryStore {
    private(set) var memories: [Memory] = []
    private let fileURL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("memories.json")

    init() {
        load()
    }

    func memories(for vaultId: String) -> [Memory] {
        var result = memories.filter { $0.vaultId == vaultId }
        if result.isEmpty, vaultId.hasPrefix("sample-") {
            result = Self.generateSampleMemories(vaultId: vaultId)
            memories.append(contentsOf: result)
            persist()
        }
        return result.sorted { $0.capturedAt < $1.capturedAt }
    }

    func add(_ memory: Memory) {
        memories.append(memory)
        persist()
    }

    func myDrops(vaultId: String, userId: String) -> [Memory] {
        memories(for: vaultId).filter { $0.uploaderId == userId }
    }

    /// Original media (poster frame for videos) — only call on unlocked
    /// vaults; sealed UI uses lockedThumb.
    func image(for memory: Memory) -> UIImage? {
        if let name = memory.mediaFileName {
            if memory.mediaType == .video {
                if let poster = MediaPoster.firstFrame(of: LocalStore.url(for: name)) {
                    return poster
                }
            } else if let img = LocalStore.image(named: name) {
                return img
            }
        }
        return PlaceholderArt.image(seed: memory.id, size: CGSize(width: 500, height: 900))
    }

    /// Playable URL for an unlocked video memory.
    func videoURL(for memory: Memory) -> URL? {
        guard memory.mediaType == .video, let name = memory.mediaFileName else { return nil }
        let url = LocalStore.url(for: name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func lockedThumb(for memory: Memory) -> UIImage? {
        if let name = memory.lockedThumbFileName, let img = LocalStore.image(named: name) {
            return img
        }
        // Sample memories: derive the locked look from the placeholder.
        guard let art = PlaceholderArt.image(seed: memory.id, size: CGSize(width: 120, height: 120)) else { return nil }
        return CollectingView.lockedThumbnail(from: art)
    }

    // ── Day grouping ─────────────────────────────────────────────

    /// 1-based trip day index for a memory within its vault's memories.
    func dayIndex(of memory: Memory, in vaultMemories: [Memory]) -> Int {
        guard let first = vaultMemories.map(\.capturedAt).min() else { return 1 }
        let start = Calendar.current.startOfDay(for: first)
        let day = Calendar.current.startOfDay(for: memory.capturedAt)
        return (Calendar.current.dateComponents([.day], from: start, to: day).day ?? 0) + 1
    }

    // ── Persistence ──────────────────────────────────────────────

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Memory].self, from: data) else { return }
        memories = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(memories) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    // ── Sample data ──────────────────────────────────────────────

    private static let sampleCaptions = [
        "first swim of the trip, water was freezing",
        "the water was somehow more blue than the photos even show",
        "got lost finding this place, worth every wrong turn",
        "nobody believed we'd actually wake up for sunrise",
        "last night, same table, same argument about dessert",
        "found the best bakery entirely by accident",
        "this view did not feel real",
        "the walk back took three hours. no regrets",
    ]

    private static func generateSampleMemories(vaultId: String) -> [Memory] {
        let uploaders: [String]
        let count: Int
        switch vaultId {
        case "sample-heilbronn":
            uploaders = ["friend-maya", "friend-rhys", "friend-sana"]
            count = 28
        default:
            uploaders = ["friend-maya", "friend-rhys"]
            count = 12
        }
        let tripStart = Date.now.addingTimeInterval(-86400 * 30)
        var rng = SeededRandom(seed: vaultId)
        return (0..<count).map { i in
            let day = i * 4 / count // spread across 4 days
            let hour = 7 + Int(rng.next() * 15)
            let capturedAt = tripStart.addingTimeInterval(TimeInterval(day * 86400 + hour * 3600 + i * 60))
            return Memory(
                id: "\(vaultId)-mem-\(i)",
                vaultId: vaultId,
                uploaderId: i % 4 == 0 ? "CURRENT_USER" : uploaders[i % uploaders.count],
                mediaType: .photo,
                lockedThumbFileName: nil,
                mediaFileName: nil,
                capturedAt: capturedAt,
                uploadedAt: capturedAt.addingTimeInterval(3600),
                caption: i % 3 == 0 ? sampleCaptions[i % sampleCaptions.count] : nil,
                byteSize: Int64(2_000_000 + rng.next() * 6_000_000))
        }
    }
}

/// Deterministic seeded generator so sample art/data is stable across launches.
struct SeededRandom {
    private var state: UInt64

    init(seed: String) {
        state = seed.utf8.reduce(UInt64(5381)) { ($0 << 5) &+ $0 &+ UInt64($1) }
        if state == 0 { state = 0x9E3779B9 }
    }

    /// 0..<1
    mutating func next() -> Double {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Double(state % 100_000) / 100_000
    }
}

/// Rich gradient placeholder "photos" for sample vaults — deterministic per seed.
enum PlaceholderArt {
    private static var cache = NSCache<NSString, UIImage>()

    static func image(seed: String, size: CGSize) -> UIImage? {
        let key = "\(seed)-\(Int(size.width))x\(Int(size.height))" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        var rng = SeededRandom(seed: seed)
        let palette: [UIColor] = [
            UIColor(Color.poolPurple), UIColor(Color.poolGold),
            UIColor(Color.poolCoral), UIColor(Color.poolEmerald),
            UIColor(hue: rng.next(), saturation: 0.65, brightness: 0.8, alpha: 1),
        ]
        let c1 = palette[Int(rng.next() * 4.99)]
        var c2 = palette[Int(rng.next() * 4.99)]
        if c2 == c1 { c2 = palette[(palette.firstIndex(of: c1)! + 2) % palette.count] }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let angle = rng.next() * .pi
        let blobs = (0..<5).map { _ in
            (x: rng.next(), y: rng.next(), r: 0.15 + rng.next() * 0.3, a: 0.15 + rng.next() * 0.25)
        }
        let img = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            let colors = [c1.darker(0.25).cgColor, c1.cgColor, c2.cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: colors, locations: [0, 0.45, 1])!
            let end = CGPoint(x: size.width * (0.5 + 0.5 * cos(angle)),
                              y: size.height * (0.5 + 0.5 * sin(angle)))
            cg.drawLinearGradient(gradient, start: .zero, end: end, options: [])
            for blob in blobs {
                cg.setFillColor(UIColor.white.withAlphaComponent(blob.a * 0.4).cgColor)
                let r = blob.r * size.width
                cg.fillEllipse(in: CGRect(x: blob.x * size.width - r / 2,
                                          y: blob.y * size.height - r / 2,
                                          width: r, height: r))
            }
        }
        cache.setObject(img, forKey: key)
        return img
    }
}

private extension UIColor {
    func darker(_ amount: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h, saturation: s, brightness: max(0, b - amount), alpha: a)
    }
}
