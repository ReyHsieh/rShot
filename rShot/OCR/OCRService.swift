//
//  OCRService.swift
//  rShot
//
//  Vision VNRecognizeTextRequest 封装（离线）
//  对应 PRD：O-01 识别、O-04 语言切换 (P1)
//

import Vision
import AppKit

enum OCRLanguage: String, CaseIterable {
    case zhHans = "zh-Hans"
    case en = "en-US"
    case zhAndEn = "zh-Hans+en-US"

    var displayName: String {
        switch self {
        case .zhHans: return "中文"
        case .en: return "英文"
        case .zhAndEn: return "中英"
        }
    }
}

struct OCRResult: Equatable {
    var lines: [String]
    var fullText: String { lines.joined(separator: "\n") }
}

final class OCRService {
    static let shared = OCRService()
    private init() {}

    var language: OCRLanguage = .zhAndEn

    func recognize(image: NSImage, completion: @escaping (OCRResult) -> Void) {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion(OCRResult(lines: []))
            return
        }
        let request = VNRecognizeTextRequest { req, _ in
            let observations = req.results as? [VNRecognizedTextObservation] ?? []
            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            DispatchQueue.main.async {
                completion(OCRResult(lines: lines))
            }
        }
        request.recognitionLevel = .accurate
        request.recognitionLanguages = recognitionLanguages()
        request.usesLanguageCorrection = true

        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            try? handler.perform([request])
        }
    }

    private func recognitionLanguages() -> [String] {
        switch language {
        case .zhHans: return ["zh-Hans", "zh-Hans(ISO2)"]
        case .en: return ["en-US"]
        case .zhAndEn: return ["zh-Hans", "en-US"]
        }
    }
}
