#if canImport(Vision) && canImport(ImageIO)
    import Foundation
    import ImageIO
    import VellumCore
    import Vision

    /// Real OCR via the Vision framework. On-device only; never touches
    /// the network (Vision text recognition runs locally). M2 upgrades
    /// this to the table-aware `RecognizeDocumentsRequest`.
    public struct VisionOCRProvider: DocumentOCRProviding {
        public init() {}

        public func recognizePage(from data: Data) async throws -> OCRPage {
            guard
                let source = CGImageSourceCreateWithData(data as CFData, nil),
                let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else {
                throw OCRError.unreadableInput
            }
            return try recognize(in: image)
        }

        private func recognize(in image: CGImage) throws -> OCRPage {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                throw OCRError.recognitionFailed(String(describing: error))
            }
            let observations = request.results ?? []
            let lines = observations.compactMap { observation -> OCRLine? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                let box = observation.boundingBox
                return OCRLine(
                    text: candidate.string,
                    boundingBox: NormalizedRect(
                        x: box.origin.x,
                        // Vision uses a bottom-left origin; OCRPage is top-left.
                        y: 1 - box.origin.y - box.size.height,
                        width: box.size.width,
                        height: box.size.height
                    ),
                    confidence: Double(candidate.confidence)
                )
            }
            return OCRPage(id: UUID(), lines: lines)
        }
    }
#endif
