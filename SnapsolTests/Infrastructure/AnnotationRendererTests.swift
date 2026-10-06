import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

struct AnnotationRendererTests {
    private let renderer = CoreGraphicsAnnotationRenderer()

    /// 左半分が黒・右半分が白の画像を、指定 DPI 付きの PNG で保存する
    private func makeBaseImage(width: Int = 200, height: Int = 100, dpi: Double = 144) throws -> URL {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        let image = try #require(context.makeImage())

        let url = try makeTemporaryDirectory().appending(path: "base.png")
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return url
    }

    /// PNG を RGBA に展開し、左上原点で (x, y) の画素を返す
    private func pixel(_ data: Data, x: Int, y: Int) throws -> (r: UInt8, g: UInt8, b: UInt8) {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        var buffer = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = try #require(CGContext(
            data: &buffer, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        // ビットマップのメモリは上の行から並ぶ
        let offset = (y * image.width + x) * 4
        return (buffer[offset], buffer[offset + 1], buffer[offset + 2])
    }

    @Test func 元画像と同じピクセルサイズとDPIで書き出す() throws {
        let data = try renderer.renderPNG(baseImageAt: try makeBaseImage(), annotations: [])
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])

        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 200)
        #expect(properties[kCGImagePropertyPixelHeight] as? Int == 100)
        #expect(properties[kCGImagePropertyDPIWidth] as? Double == 144)
    }

    @Test func 矩形は左上原点の座標どおりに描かれる() throws {
        let rect = Annotation(id: UUID(), kind: .rectangle(CGRect(x: 120, y: 10, width: 60, height: 40)), color: .blue, lineWidth: 4)
        let data = try renderer.renderPNG(baseImageAt: try makeBaseImage(), annotations: [rect])

        let topEdge = try pixel(data, x: 150, y: 10)
        #expect(topEdge.b > 200 && topEdge.r < 50)
        // 上下が反転していれば、下端付近（y = 90）に線が出てしまう
        let mirrored = try pixel(data, x: 150, y: 90)
        #expect(mirrored == (255, 255, 255))
        let inside = try pixel(data, x: 150, y: 30)
        #expect(inside == (255, 255, 255))
    }

    @Test func モザイクは範囲内だけを粗くし範囲外は変えない() throws {
        // 白黒の境目（x = 100）をまたぐモザイク
        let mosaic = Annotation(id: UUID(), kind: .mosaic(CGRect(x: 80, y: 0, width: 40, height: 50)), color: .red, lineWidth: 4)
        let data = try renderer.renderPNG(baseImageAt: try makeBaseImage(), annotations: [mosaic])

        // 境目のブロックは白と黒の中間色になる
        let blended = try pixel(data, x: 99, y: 10)
        #expect(blended.r > 20 && blended.r < 235)
        #expect(try pixel(data, x: 99, y: 80) == (0, 0, 0))
        #expect(try pixel(data, x: 150, y: 10) == (255, 255, 255))
    }

    @Test func テキストの大きさは文字数に応じて伸びる() {
        let short = renderer.textSize("A", fontSize: 40)
        let long = renderer.textSize("AAAA", fontSize: 40)
        #expect(long.width > short.width * 3)
        #expect(short.height >= 40)
    }
}
