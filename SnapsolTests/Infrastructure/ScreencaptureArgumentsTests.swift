import Foundation
import Testing

struct ScreencaptureArgumentsTests {
    private let output = URL(filePath: "/tmp/out.png")

    @Test(arguments: [
        (CaptureMode.fullscreen, ["-D", "2"]),
        (.window, ["-w"]),
        (.area, ["-s"]),
    ])
    func モードごとの引数(mode: CaptureMode, expectedPrefix: [String]) {
        let arguments = ScreencaptureArguments.make(mode: mode, output: output, displayIndex: 2)
        #expect(arguments == expectedPrefix + ["-x", "-t", "png", "/tmp/out.png"])
    }
}
