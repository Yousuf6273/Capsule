import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

/// Extracts the two dominant theme colors from a cover photo using Core Image's
/// k-means quantizer (`CIKMeans`) — proper clustering, not a naive average.
enum ThemeExtractor {

    /// Returns a TripTheme, or a deterministic fallback from the palette pool
    /// when extraction fails or produces muddy colors.
    static func extractTheme(from image: UIImage, fallbackSeed: String = "") -> TripTheme {
        guard let clusters = dominantColors(in: image, count: 8) else {
            return fallback(seed: fallbackSeed)
        }

        // Score clusters: prefer saturated, mid-lightness colors (gradient-worthy),
        // penalize near-black/near-white which kill the mesh contrast.
        let scored = clusters
            .map { (color: $0, score: vibrancy(of: $0)) }
            .sorted { $0.score > $1.score }

        guard let first = scored.first, first.score > 0.15 else {
            return fallback(seed: fallbackSeed)
        }

        // Second color: best remaining cluster that contrasts with the first.
        let second = scored.dropFirst().max { a, b -> Bool in
            let scoreA: Double = pairScore(first.color, a.color) * a.score
            let scoreB: Double = pairScore(first.color, b.color) * b.score
            return scoreA < scoreB
        }?.color ?? UIColor(Color.poolGold)

        return TripTheme(primaryHex: hex(first.color), secondaryHex: hex(second))
    }

    // ── CIKMeans pipeline ────────────────────────────────────────

    private static func dominantColors(in image: UIImage, count: Int) -> [UIColor]? {
        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])

        // Downsample first — k-means over a 64px image is plenty and fast.
        let scale = 64.0 / max(ciImage.extent.width, ciImage.extent.height)
        let small = ciImage.transformed(by: .init(scaleX: scale, y: scale))

        let kMeans = CIFilter.kMeans()
        kMeans.inputImage = small
        kMeans.extent = small.extent
        kMeans.count = count
        kMeans.passes = 8
        kMeans.perceptual = true

        guard let output = kMeans.outputImage else { return nil }
        // Output is a `count`×1 image; read the palette pixels.
        let paletteImage = output.settingAlphaOne(in: output.extent)
        var bitmap = [UInt8](repeating: 0, count: count * 4)
        context.render(paletteImage,
                       toBitmap: &bitmap,
                       rowBytes: count * 4,
                       bounds: CGRect(x: 0, y: 0, width: count, height: 1),
                       format: .RGBA8,
                       colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)

        return (0..<count).map { i -> UIColor in
            let r: CGFloat = CGFloat(bitmap[i * 4]) / 255
            let g: CGFloat = CGFloat(bitmap[i * 4 + 1]) / 255
            let b: CGFloat = CGFloat(bitmap[i * 4 + 2]) / 255
            return UIColor(red: r, green: g, blue: b, alpha: 1)
        }
    }

    // ── Scoring ──────────────────────────────────────────────────

    private static func hsb(_ color: UIColor) -> (h: CGFloat, s: CGFloat, b: CGFloat) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h, s, b)
    }

    /// 0…1 — how well a color anchors a rich gradient.
    private static func vibrancy(of color: UIColor) -> Double {
        let (_, s, b) = hsb(color)
        let midLightness = 1 - abs(Double(b) - 0.55) / 0.55 // peak at b == 0.55
        return Double(s) * 0.7 + midLightness * 0.3
    }

    /// Rewards hue separation and brightness contrast between the pair.
    private static func pairScore(_ a: UIColor, _ b: UIColor) -> Double {
        let (h1, _, b1) = hsb(a), (h2, _, b2) = hsb(b)
        var hueDelta = abs(Double(h1 - h2))
        if hueDelta > 0.5 { hueDelta = 1 - hueDelta }   // hue is circular
        return hueDelta * 2 * 0.6 + abs(Double(b1 - b2)) * 0.4 + 0.1
    }

    private static func hex(_ color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X",
                      Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
    }

    private static func fallback(seed: String) -> TripTheme {
        guard !seed.isEmpty else { return .default }
        let idx = abs(seed.hashValue) % TripTheme.fallbackPool.count
        return TripTheme.fallbackPool[idx]
    }
}
