import AppKit
import ImageIO
import UniformTypeIdentifiers

struct CoreGraphicsAnnotationRenderer: AnnotationRendering {
    struct RenderError: Error {}

    func loadImage(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// 元画像を縮小した小さな画像を返す。描画時に補間なしで拡大するとブロック状のモザイクになる
    func mosaicSource(for image: CGImage) -> CGImage? {
        let blockSize = max(8, max(image.width, image.height) / 80)
        let width = max(1, image.width / blockSize)
        let height = max(1, image.height / blockSize)
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    func draw(_ annotations: [Annotation], in context: CGContext, imageSize: CGSize, mosaicSource: CGImage?) {
        // モザイクは下地の画像を隠すものなので、他の注釈より先（一番下）に描く
        for annotation in annotations {
            if case .mosaic(let rect) = annotation.kind, let mosaicSource {
                drawMosaic(rect, source: mosaicSource, in: context, imageSize: imageSize)
            }
        }
        for annotation in annotations {
            let color = annotation.color.cgColor
            switch annotation.kind {
            case .rectangle(let rect):
                context.setStrokeColor(color)
                context.setLineWidth(annotation.lineWidth)
                context.setLineJoin(.round)
                context.stroke(rect)
            case .arrow(let start, let end):
                drawArrow(from: start, to: end, lineWidth: annotation.lineWidth, color: color, in: context)
            case .text(let rect, let string, let fontSize):
                drawText(string, at: rect.origin, fontSize: fontSize, color: annotation.color, in: context)
            case .mosaic:
                break
            }
        }
    }

    func renderPNG(baseImageAt url: URL, annotations: [Annotation]) throws -> Data {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let base = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw RenderError() }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]

        let width = base.width, height = base.height
        // 元画像の色空間（スクリーンショットは Display P3 など）を保つ。使えなければ sRGB
        let space = base.colorSpace.flatMap { $0.supportsOutput ? $0 : nil } ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw RenderError() }

        let imageSize = CGSize(width: width, height: height)
        context.draw(base, in: CGRect(origin: .zero, size: imageSize))
        // ビットマップは左下原点。注釈の約束（左上原点）に合わせて上下を反転してから描く
        context.translateBy(x: 0, y: imageSize.height)
        context.scaleBy(x: 1, y: -1)
        draw(annotations, in: context, imageSize: imageSize, mosaicSource: mosaicSource(for: base))

        guard let image = context.makeImage() else { throw RenderError() }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw RenderError()
        }
        // DPI を引き継がないと、Retina のスクショを貼ったときに 2 倍の大きさで表示される
        var output: [CFString: Any] = [:]
        output[kCGImagePropertyDPIWidth] = properties[kCGImagePropertyDPIWidth]
        output[kCGImagePropertyDPIHeight] = properties[kCGImagePropertyDPIHeight]
        CGImageDestinationAddImage(destination, image, output as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw RenderError() }
        return data as Data
    }

    func textSize(_ string: String, fontSize: CGFloat) -> CGSize {
        let size = (string as NSString).size(withAttributes: textAttributes(fontSize: fontSize, color: .black))
        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }

    func textFont(ofSize size: CGFloat) -> CTFont {
        NSFont.systemFont(ofSize: size, weight: .bold)
    }

    private func textAttributes(fontSize: CGFloat, color: AnnotationColor) -> [NSAttributedString.Key: Any] {
        [
            .font: textFont(ofSize: fontSize),
            .foregroundColor: NSColor(cgColor: color.cgColor) ?? .red,
        ]
    }

    // MARK: - Private

    private func drawMosaic(_ rect: CGRect, source: CGImage, in context: CGContext, imageSize: CGSize) {
        context.saveGState()
        context.clip(to: rect)
        // 画像は y 上向きで描く必要があるので、クリップを決めた後で一時的に反転を戻す
        context.translateBy(x: 0, y: imageSize.height)
        context.scaleBy(x: 1, y: -1)
        context.interpolationQuality = .none
        context.draw(source, in: CGRect(origin: .zero, size: imageSize))
        context.restoreGState()
    }

    private func drawArrow(from start: CGPoint, to end: CGPoint, lineWidth: CGFloat, color: CGColor, in context: CGContext) {
        let length = hypot(end.x - start.x, end.y - start.y)
        guard length > 0 else { return }
        let headLength = min(max(lineWidth * 4, 12), length)
        let headHalfWidth = headLength * 0.45
        let ux = (end.x - start.x) / length, uy = (end.y - start.y) / length
        let base = CGPoint(x: end.x - ux * headLength, y: end.y - uy * headLength)

        context.setStrokeColor(color)
        context.setFillColor(color)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.move(to: start)
        context.addLine(to: base)
        context.strokePath()

        context.move(to: end)
        context.addLine(to: CGPoint(x: base.x - uy * headHalfWidth, y: base.y + ux * headHalfWidth))
        context.addLine(to: CGPoint(x: base.x + uy * headHalfWidth, y: base.y - ux * headHalfWidth))
        context.closePath()
        context.fillPath()
    }

    private func drawText(_ string: String, at origin: CGPoint, fontSize: CGFloat, color: AnnotationColor, in context: CGContext) {
        // context は y 下向きなので flipped: true の NSGraphicsContext として AppKit の文字描画を使う
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        (string as NSString).draw(at: origin, withAttributes: textAttributes(fontSize: fontSize, color: color))
        NSGraphicsContext.restoreGraphicsState()
    }
}

extension AnnotationColor {
    var cgColor: CGColor {
        CGColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    }
}
