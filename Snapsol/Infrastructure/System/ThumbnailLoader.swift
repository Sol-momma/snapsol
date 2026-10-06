import Foundation
import ImageIO

/// ImageIO でフル画像を読まずに縮小版だけをデコードし、NSCache に保持する。
/// NSCache はスレッドセーフなので @unchecked Sendable で共有する。
final class ThumbnailLoader: ThumbnailProviding, @unchecked Sendable {
    private let cache = NSCache<NSString, CGImage>()

    init() {
        cache.countLimit = 200
    }

    func thumbnail(at url: URL, version: Date, maxPixelSize: Int) -> CGImage? {
        let key = "\(url.path)|\(version.timeIntervalSince1970)|\(maxPixelSize)" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}
