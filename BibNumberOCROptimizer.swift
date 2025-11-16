import Foundation
import Vision
import CoreImage
import CoreGraphics

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Character Set Configuration

/// Character sets for OCR optimization
enum OCRCharacterSet {
    case digitsOnly              // 0-9 only
    case digitsAndUppercase      // 0-9, A-Z
    case alphanumeric            // 0-9, A-Z, a-z
    case full                    // No restrictions

    var customWords: [String]? {
        switch self {
        case .digitsOnly:
            return ["0","1","2","3","4","5","6","7","8","9"]

        case .digitsAndUppercase:
            return ["0","1","2","3","4","5","6","7","8","9",
                   "A","B","C","D","E","F","G","H","I","J",
                   "K","L","M","N","O","P","Q","R","S","T",
                   "U","V","W","X","Y","Z"]

        case .alphanumeric:
            // Too many for custom words, return nil to use default
            return nil

        case .full:
            return nil
        }
    }

    var displayName: String {
        switch self {
        case .digitsOnly: return "Digits Only (0-9)"
        case .digitsAndUppercase: return "Digits + Uppercase (0-9, A-Z)"
        case .alphanumeric: return "Alphanumeric (0-9, A-Z, a-z)"
        case .full: return "Full Character Set"
        }
    }
}

// MARK: - OCR Settings

/// Complete OCR configuration
struct OCRSettings {
    var characterSet: OCRCharacterSet = .digitsOnly
    var recognitionLevel: VNRequestTextRecognitionLevel = .accurate
    var recognitionLanguages: [String] = ["en-US"]
    var usesLanguageCorrection: Bool = false  // Disable for numbers
    var minimumTextHeight: Float = 0.0        // 0 = no minimum (0-1 range)
    var minimumConfidence: Float = 0.5
    var revision: Int = VNRecognizeTextRequestRevision3

    // Custom preprocessing hints
    var expectsHighContrast: Bool = true
    var expectsLargeText: Bool = true
    var expectsNumericContent: Bool = true
}

// MARK: - Bib Number OCR Optimizer

/// Optimizes Vision OCR requests specifically for bib numbers
class BibNumberOCROptimizer {

    // MARK: - Predefined Configurations

    /// Fast configuration for large, clear bib numbers
    static var fastLargeNumbers: OCRSettings {
        return OCRSettings(
            characterSet: .digitsOnly,
            recognitionLevel: .fast,
            usesLanguageCorrection: false,
            minimumTextHeight: 0.15,      // Large text only
            minimumConfidence: 0.7,
            expectsHighContrast: true,
            expectsLargeText: true,
            expectsNumericContent: true
        )
    }

    /// Accurate configuration for clear bib numbers
    static var accurateLargeNumbers: OCRSettings {
        return OCRSettings(
            characterSet: .digitsOnly,
            recognitionLevel: .accurate,
            usesLanguageCorrection: false,
            minimumTextHeight: 0.10,
            minimumConfidence: 0.6,
            expectsHighContrast: true,
            expectsLargeText: true,
            expectsNumericContent: true
        )
    }

    /// Configuration for bib numbers with division markers (A123, M456)
    static var withDivisionMarkers: OCRSettings {
        return OCRSettings(
            characterSet: .digitsAndUppercase,
            recognitionLevel: .accurate,
            usesLanguageCorrection: false,
            minimumTextHeight: 0.10,
            minimumConfidence: 0.55,
            expectsHighContrast: true,
            expectsLargeText: true,
            expectsNumericContent: true
        )
    }

    /// Configuration for medium-sized bib numbers
    static var mediumSizedBibs: OCRSettings {
        return OCRSettings(
            characterSet: .digitsAndUppercase,
            recognitionLevel: .accurate,
            usesLanguageCorrection: false,
            minimumTextHeight: 0.05,
            minimumConfidence: 0.5,
            expectsHighContrast: true,
            expectsLargeText: false,
            expectsNumericContent: true
        )
    }

    /// Configuration for small/distant bib numbers (after upscaling)
    static var smallDistantBibs: OCRSettings {
        return OCRSettings(
            characterSet: .digitsAndUppercase,
            recognitionLevel: .accurate,
            usesLanguageCorrection: false,
            minimumTextHeight: 0.0,       // Accept any size after scaling
            minimumConfidence: 0.45,
            expectsHighContrast: false,   // May have degraded after scaling
            expectsLargeText: false,
            expectsNumericContent: true
        )
    }

    /// Fallback configuration (most permissive)
    static var fallback: OCRSettings {
        return OCRSettings(
            characterSet: .alphanumeric,
            recognitionLevel: .accurate,
            usesLanguageCorrection: false,
            minimumTextHeight: 0.0,
            minimumConfidence: 0.4,
            expectsHighContrast: false,
            expectsLargeText: false,
            expectsNumericContent: false
        )
    }

    // MARK: - Adaptive Configuration

    /// Generate optimal configuration based on text region analysis
    static func configureFor(_ analysis: TextRegionAnalysis) -> OCRSettings {
        switch (analysis.sizeClass, analysis.contrast, analysis.isNumericLikely) {

        // Very large, high contrast, numeric-likely → FASTEST
        case (.veryLarge, .high, true):
            return fastLargeNumbers

        // Very large, any contrast, numeric-likely → ACCURATE
        case (.veryLarge, _, true):
            return accurateLargeNumbers

        // Large, good quality → ACCURATE
        case (.large, .high, _), (.large, .medium, true):
            return accurateLargeNumbers

        // Large with division markers possible
        case (.large, _, _):
            return withDivisionMarkers

        // Medium size
        case (.medium, _, _):
            return mediumSizedBibs

        // Small (likely upscaled)
        case (.small, _, _):
            return smallDistantBibs
        }
    }

    // MARK: - Request Creation

    /// Create configured VNRecognizeTextRequest
    static func createRequest(with settings: OCRSettings,
                             completionHandler: @escaping (VNRequest, Error?) -> Void) -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest(completionHandler: completionHandler)

        // Character set restriction
        if let customWords = settings.characterSet.customWords {
            request.customWords = customWords
        }

        // Recognition settings
        request.recognitionLevel = settings.recognitionLevel
        request.recognitionLanguages = settings.recognitionLanguages
        request.usesLanguageCorrection = settings.usesLanguageCorrection
        request.minimumTextHeight = settings.minimumTextHeight
        request.revision = settings.revision

        return request
    }

    /// Create request for specific text region
    static func createRequest(for analysis: TextRegionAnalysis,
                             completionHandler: @escaping (VNRequest, Error?) -> Void) -> VNRecognizeTextRequest {
        let settings = configureFor(analysis)
        return createRequest(with: settings, completionHandler: completionHandler)
    }

    // MARK: - Quick Request Creators

    /// Create fast request for large, clear bib numbers
    static func createFastRequest(completionHandler: @escaping (VNRequest, Error?) -> Void) -> VNRecognizeTextRequest {
        return createRequest(with: fastLargeNumbers, completionHandler: completionHandler)
    }

    /// Create accurate request for bib numbers
    static func createAccurateRequest(completionHandler: @escaping (VNRequest, Error?) -> Void) -> VNRecognizeTextRequest {
        return createRequest(with: accurateLargeNumbers, completionHandler: completionHandler)
    }

    /// Create request with division marker support
    static func createDivisionMarkerRequest(completionHandler: @escaping (VNRequest, Error?) -> Void) -> VNRecognizeTextRequest {
        return createRequest(with: withDivisionMarkers, completionHandler: completionHandler)
    }

    // MARK: - Region-Of-Interest Optimization

    /// Create request optimized for specific region in image
    static func createRequest(for region: CGRect,
                             in imageSize: CGSize,
                             settings: OCRSettings,
                             completionHandler: @escaping (VNRequest, Error?) -> Void) -> VNRecognizeTextRequest {
        let request = createRequest(with: settings, completionHandler: completionHandler)

        // Set region of interest (normalized coordinates)
        let normalizedRegion = CGRect(
            x: region.origin.x / imageSize.width,
            y: region.origin.y / imageSize.height,
            width: region.width / imageSize.width,
            height: region.height / imageSize.height
        )

        request.regionOfInterest = normalizedRegion

        return request
    }

    // MARK: - Batch Optimization

    /// Create multiple requests for different strategies (parallel processing)
    static func createMultiStrategyRequests(completionHandler: @escaping (VNRequest, Error?) -> Void) -> [VNRecognizeTextRequest] {
        return [
            createRequest(with: fastLargeNumbers, completionHandler: completionHandler),
            createRequest(with: withDivisionMarkers, completionHandler: completionHandler),
            createRequest(with: mediumSizedBibs, completionHandler: completionHandler)
        ]
    }
}

// MARK: - OCR Result Processing

/// Processes and filters OCR results for bib numbers
class OCRResultProcessor {

    // MARK: - Filtering

    /// Filter OCR results by confidence threshold
    static func filter(_ results: [VNRecognizedText],
                      minimumConfidence: Float) -> [VNRecognizedText] {
        return results.filter { $0.confidence >= minimumConfidence }
    }

    /// Filter by character content (digits only)
    static func filterDigitsOnly(_ results: [VNRecognizedText]) -> [VNRecognizedText] {
        return results.filter { recognized in
            let text = recognized.string
            return text.allSatisfy { $0.isNumber }
        }
    }

    /// Filter by character content (digits + uppercase letters)
    static func filterDigitsAndLetters(_ results: [VNRecognizedText]) -> [VNRecognizedText] {
        return results.filter { recognized in
            let text = recognized.string
            return text.allSatisfy { $0.isNumber || $0.isUppercase }
        }
    }

    /// Filter by length (typical bib numbers: 1-6 characters)
    static func filterByLength(_ results: [VNRecognizedText],
                              minLength: Int = 1,
                              maxLength: Int = 6) -> [VNRecognizedText] {
        return results.filter { recognized in
            let length = recognized.string.count
            return length >= minLength && length <= maxLength
        }
    }

    // MARK: - Sorting

    /// Sort by confidence (highest first)
    static func sortByConfidence(_ results: [VNRecognizedText]) -> [VNRecognizedText] {
        return results.sorted { $0.confidence > $1.confidence }
    }

    /// Sort by text height (largest first)
    static func sortBySize(_ results: [VNRecognizedText]) -> [VNRecognizedText] {
        return results.sorted { (a, b) in
            // Compare bounding box heights
            guard let aBox = try? a.boundingBox(for: a.string.startIndex..<a.string.endIndex)?.boundingBox,
                  let bBox = try? b.boundingBox(for: b.string.startIndex..<b.string.endIndex)?.boundingBox else {
                return false
            }
            return aBox.height > bBox.height
        }
    }

    // MARK: - Confidence Adjustment

    /// Adjust confidence based on bib number characteristics
    static func adjustConfidence(_ result: VNRecognizedText) -> Float {
        var confidence = result.confidence
        let text = result.string

        // Boost for pure digits
        if text.allSatisfy({ $0.isNumber }) {
            confidence *= 1.2
        }

        // Boost for typical bib lengths (3-5 characters)
        if text.count >= 3 && text.count <= 5 {
            confidence *= 1.1
        }

        // Penalize very short (likely noise)
        if text.count == 1 {
            confidence *= 0.8
        }

        // Penalize very long (likely not a bib)
        if text.count > 6 {
            confidence *= 0.7
        }

        return min(confidence, 1.0)
    }

    // MARK: - Best Result Selection

    /// Select best bib number from multiple OCR results
    static func selectBestBibNumber(_ results: [VNRecognizedText]) -> VNRecognizedText? {
        // Filter and process
        let filtered = filterByLength(
            filterDigitsAndLetters(results),
            minLength: 1,
            maxLength: 6
        )

        guard !filtered.isEmpty else { return nil }

        // Adjust confidences
        let adjusted = filtered.map { result -> (VNRecognizedText, Float) in
            return (result, adjustConfidence(result))
        }

        // Return highest adjusted confidence
        return adjusted.max { $0.1 < $1.1 }?.0
    }

    /// Get top N best bib number candidates
    static func selectTopBibNumbers(_ results: [VNRecognizedText],
                                   count: Int = 3) -> [VNRecognizedText] {
        let filtered = filterByLength(
            filterDigitsAndLetters(results),
            minLength: 1,
            maxLength: 6
        )

        let adjusted = filtered.map { result -> (VNRecognizedText, Float) in
            return (result, adjustConfidence(result))
        }

        return adjusted
            .sorted { $0.1 > $1.1 }
            .prefix(count)
            .map { $0.0 }
    }
}

// MARK: - Example Usage

/*
 Example usage:

 // Create optimized request for large bib numbers
 let request = BibNumberOCROptimizer.createFastRequest { request, error in
     guard error == nil,
           let results = request.results as? [VNRecognizedText] else {
         return
     }

     // Process results
     let filtered = OCRResultProcessor.filterDigitsOnly(results)
     let sorted = OCRResultProcessor.sortByConfidence(filtered)

     if let bestBib = OCRResultProcessor.selectBestBibNumber(results) {
         print("Detected bib number: \(bestBib.string)")
         print("Confidence: \(bestBib.confidence)")
     }
 }

 // Perform OCR
 let handler = VNImageRequestHandler(cgImage: image, options: [:])
 try? handler.perform([request])

 // Or create adaptive request based on text analysis
 let analyzer = TextRegionAnalyzer()
 if let analysis = try? analyzer.analyze(boundingBox: region, in: image) {
     let adaptiveRequest = BibNumberOCROptimizer.createRequest(
         for: analysis,
         completionHandler: { request, error in
             // Handle results
         }
     )
 }
 */
