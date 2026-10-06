import Foundation
import ImageIO
import Vision

struct VisionTextRecognizer: TextRecognizing {
    struct UnreadableImage: Error {}

    func recognizeText(at url: URL) async throws -> [RecognizedLine] {
        // perform() は同期で重いので、協調スレッドプールを塞がないよう GCD に逃がす
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(with: Result { try recognize(at: url) })
            }
        }
    }

    private func recognize(at url: URL) throws -> [RecognizedLine] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw UnreadableImage() }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        // 指定しないと英語のみになり、日本語が認識されない
        request.recognitionLanguages = ["ja-JP", "en-US"]
        try VNImageRequestHandler(cgImage: image).perform([request])

        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let box = observation.boundingBox
            // Vision は左下原点。Domain の約束（左上原点）に合わせて y を反転する
            return RecognizedLine(
                text: candidate.string,
                bounds: CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height)
            )
        }
    }
}
