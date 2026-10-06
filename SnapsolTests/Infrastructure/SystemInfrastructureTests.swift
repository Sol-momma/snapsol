import AppKit
import Testing

@MainActor
struct SystemInfrastructureTests {
    /// 白地に黒文字の PNG を作る（Vision の実認識を確かめるため）
    private func renderTextImage(_ lines: [String]) throws -> URL {
        let size = NSSize(width: 800, height: 300)
        let image = NSImage(size: size, flipped: true) { rect in
            NSColor.white.setFill()
            rect.fill()
            for (index, text) in lines.enumerated() {
                (text as NSString).draw(
                    at: NSPoint(x: 40, y: 40 + index * 120),
                    withAttributes: [.font: NSFont.systemFont(ofSize: 64), .foregroundColor: NSColor.black]
                )
            }
            return true
        }
        let rep = try #require(image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
        let url = try makeTemporaryDirectory().appending(path: "text.png")
        try #require(rep.representation(using: .png, properties: [:])).write(to: url)
        return url
    }

    @Test func Visionで日本語と英語を上から順に認識する() async throws {
        let url = try renderTextImage(["Snapsol", "日本語テキスト"])
        let lines = try await VisionTextRecognizer().recognizeText(at: url)
        let text = ReadingOrderSorter.sort(lines)

        #expect(text.contains("Snapsol"))
        #expect(text.contains("日本語"))
        #expect(text.range(of: "Snapsol")!.lowerBound < text.range(of: "日本語")!.lowerBound)
    }

    @Test func 画像コピーは1つのitemにfileURLとPNGとTIFFを載せる() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("SnapsolTests-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let url = try renderTextImage(["copy"])

        try PasteboardClipboard(pasteboard: pasteboard).copyImage(at: url)

        let items = try #require(pasteboard.pasteboardItems)
        #expect(items.count == 1)
        #expect(Set(items[0].types).isSuperset(of: [.fileURL, .png, .tiff]))
        #expect(items[0].string(forType: .fileURL) == url.absoluteString)
    }
}
