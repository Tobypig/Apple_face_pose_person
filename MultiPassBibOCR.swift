import Foundation
import Vision
import CoreImage
import CoreGraphics

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Bib Number Result

/// Final bib number detection result
struct BibNumberResult: Codable {
    let number: String
    let confidence: Float
    let boundingBox: CGRect?
    let passName: String?              // Which OCR pass succeeded
    let adjustedConfidence: Float      // After pattern validation adjustment
    let isValidPattern: Bool
    let detectionTime: TimeInterval?

    var description: String {
        return """
        Bib Number: \(number)
        Confidence: \(String(format: "%.2f", confidence)) → \(String(format: "%.2f", adjustedConfidence))
        Valid Pattern: \(isValidPattern)
        \(passName != nil ? "Detected via: \(passName!)" : "")
        """
    }
}

// MARK: - Validation Result

enum ValidationResult {
    case valid
    case invalid(reason: String)

    var isValid: Bool {
        if case .valid = self {
            return true
        }
        return false
    }
}

// MARK: - Bib Number Validator

/// Validates and filters bib number candidates
class BibNumberValidator {

    // MARK: - Pattern Definitions

    /// Typical bib number patterns
    private let validPatterns: [String] = [
        "^\\d{1,6}$",               // Pure numbers: 1-6 digits (e.g., "123", "45678")
        "^[A-Z]\\d{1,5}$",          // Division + number (e.g., "A123", "M456")
        "^\\d{1,4}-\\d{1,3}$",      // Hyphenated (e.g., "123-45")
        "^[A-Z]{1,2}\\d{2,5}$",     // Multi-letter division (e.g., "AB123", "MW456")
        "^\\d{1,3}[A-Z]\\d{1,3}$"   // Mixed format (e.g., "12A34")
    ]

    // MARK: - Validation Configuration

    struct Config {
        var minLength: Int = 1
        var maxLength: Int = 8
        var minDigitRatio: Float = 0.5      // At least 50% digits
        var minNumericValue: Int = 1
        var maxNumericValue: Int = 99999
        var allowHyphens: Bool = true
        var allowDivisionMarkers: Bool = true
    }

    var config = Config()

    // MARK: - Validation

    /// Validate bib number candidate
    func validate(_ text: String) -> ValidationResult {
        // 1. Length check
        guard text.count >= config.minLength && text.count <= config.maxLength else {
            return .invalid(reason: "Length \(text.count) out of range (\(config.minLength)-\(config.maxLength))")
        }

        // 2. Pattern matching
        let matchesPattern = validPatterns.contains { pattern in
            text.range(of: pattern, options: .regularExpression) != nil
        }

        guard matchesPattern else {
            return .invalid(reason: "Does not match bib number pattern")
        }

        // 3. Digit ratio check
        let digitCount = text.filter { $0.isNumber }.count
        let digitRatio = Float(digitCount) / Float(text.count)

        guard digitRatio >= config.minDigitRatio else {
            return .invalid(reason: "Insufficient digit ratio: \(String(format: "%.2f", digitRatio))")
        }

        // 4. Numeric value range (for the numeric part)
        let numericPart = String(text.filter { $0.isNumber })
        if let numericValue = Int(numericPart) {
            guard numericValue >= config.minNumericValue &&
                  numericValue <= config.maxNumericValue else {
                return .invalid(reason: "Numeric value \(numericValue) out of range")
            }
        }

        // 5. Character validity
        let validChars = text.allSatisfy { char in
            char.isNumber || char.isUppercase ||
            (config.allowHyphens && char == "-") ||
            (config.allowDivisionMarkers && char.isLetter)
        }

        guard validChars else {
            return .invalid(reason: "Contains invalid characters")
        }

        return .valid
    }

    // MARK: - Confidence Adjustment

    /// Adjust confidence based on bib number characteristics
    func adjustConfidence(_ baseConfidence: Float, for text: String) -> Float {
        var adjusted = baseConfidence

        // Boost confidence for pure digits
        if text.allSatisfy({ $0.isNumber }) {
            adjusted *= 1.2
        }

        // Boost for typical lengths (3-5 digits)
        if text.count >= 3 && text.count <= 5 {
            adjusted *= 1.1
        }

        // Boost for very high original confidence
        if baseConfidence >= 0.9 {
            adjusted *= 1.05
        }

        // Penalize unusual patterns
        if text.contains("-") {
            adjusted *= 0.9
        }

        // Penalize very short (likely noise)
        if text.count == 1 {
            adjusted *= 0.7
        }

        // Penalize very long
        if text.count > 6 {
            adjusted *= 0.8
        }

        // Penalize mixed case (shouldn't happen with proper OCR config)
        if text.contains(where: { $0.isLowercase }) {
            adjusted *= 0.6
        }

        return min(adjusted, 1.0)
    }

    // MARK: - Filtering

    /// Filter OCR candidates and return valid bib numbers
    func filterCandidates(_ ocrResults: [VNRecognizedText]) -> [BibNumberResult] {
        return ocrResults.compactMap { recognized in
            let text = recognized.string.uppercased() // Normalize to uppercase

            // Validate pattern
            let validation = validate(text)
            guard validation.isValid else {
                return nil
            }

            // Adjust confidence
            let adjustedConfidence = adjustConfidence(recognized.confidence, for: text)

            // Get bounding box
            let boundingBox = try? recognized.boundingBox(
                for: text.startIndex..<text.endIndex
            )?.boundingBox

            return BibNumberResult(
                number: text,
                confidence: recognized.confidence,
                boundingBox: boundingBox,
                passName: nil,
                adjustedConfidence: adjustedConfidence,
                isValidPattern: true,
                detectionTime: nil
            )
        }
        .sorted { $0.adjustedConfidence > $1.adjustedConfidence }
    }
}

// MARK: - OCR Pass Definition

/// Single OCR pass configuration
struct OCRPass {
    let name: String
    let settings: OCRSettings
    let preprocessingProfile: PreprocessingProfile
    let minimumConfidence: Float

    var description: String {
        return """
        Pass: \(name)
        Character Set: \(settings.characterSet.displayName)
        Recognition Level: \(settings.recognitionLevel == .accurate ? "Accurate" : "Fast")
        Preprocessing: \(preprocessingProfile.displayName)
        Min Confidence: \(String(format: "%.2f", minimumConfidence))
        """
    }
}

// MARK: - Multi-Pass Bib OCR System

/// Multi-pass OCR strategy for maximum accuracy
class MultiPassBibOCR {

    private let preprocessor = SizeAdaptivePreprocessor()
    private let validator = BibNumberValidator()
    private let ciContext = CIContext()

    // MARK: - Pass Definitions

    /// Standard 5-pass strategy
    private let standardPasses: [OCRPass] = [
        // Pass 1: Fast, number-only, large text
        OCRPass(
            name: "Fast Large Numbers",
            settings: BibNumberOCROptimizer.fastLargeNumbers,
            preprocessingProfile: .minimal,
            minimumConfidence: 0.8
        ),

        // Pass 2: Accurate, numbers + division letters
        OCRPass(
            name: "Accurate with Division Markers",
            settings: BibNumberOCROptimizer.withDivisionMarkers,
            preprocessingProfile: .standard,
            minimumConfidence: 0.7
        ),

        // Pass 3: Enhanced preprocessing
        OCRPass(
            name: "Enhanced Preprocessing",
            settings: BibNumberOCROptimizer.accurateLargeNumbers,
            preprocessingProfile: .enhanced,
            minimumConfidence: 0.6
        ),

        // Pass 4: Aggressive enhancement
        OCRPass(
            name: "Aggressive Enhancement",
            settings: BibNumberOCROptimizer.mediumSizedBibs,
            preprocessingProfile: .aggressive,
            minimumConfidence: 0.5
        ),

        // Pass 5: Fallback
        OCRPass(
            name: "Fallback",
            settings: BibNumberOCROptimizer.fallback,
            preprocessingProfile: .veryAggressive,
            minimumConfidence: 0.4
        )
    ]

    var passes: [OCRPass]

    // MARK: - Configuration

    struct Configuration {
        var enableEarlyExit: Bool = true      // Exit on first success
        var maxPasses: Int = 5                // Maximum passes to attempt
        var minimumGlobalConfidence: Float = 0.4
        var keepAllResults: Bool = false      // Keep results from all passes
    }

    var config = Configuration()

    init(customPasses: [OCRPass]? = nil) {
        self.passes = customPasses ?? standardPasses
    }

    // MARK: - Main OCR Method

    /// Perform multi-pass OCR on image region
    func recognizeBibNumber(in image: CGImage,
                           region: CGRect? = nil) -> BibNumberResult? {
        let startTime = Date()
        var allResults: [BibNumberResult] = []

        for (index, pass) in passes.prefix(config.maxPasses).enumerated() {
            print("Attempting pass \(index + 1): \(pass.name)")

            // 1. Preprocess image
            let processedImage: CGImage
            if let processed = preprocessor.preprocess(image, profile: pass.preprocessingProfile) {
                processedImage = processed
            } else {
                processedImage = image
            }

            // 2. Crop to region if specified
            let targetImage: CGImage
            if let region = region,
               let cropped = processedImage.cropping(to: region) {
                targetImage = cropped
            } else {
                targetImage = processedImage
            }

            // 3. Perform OCR
            guard let ocrResults = performOCR(on: targetImage, settings: pass.settings) else {
                continue
            }

            // 4. Validate and filter results
            var candidates = validator.filterCandidates(ocrResults)

            // Add pass information
            candidates = candidates.map { candidate in
                var updated = candidate
                updated = BibNumberResult(
                    number: updated.number,
                    confidence: updated.confidence,
                    boundingBox: updated.boundingBox,
                    passName: pass.name,
                    adjustedConfidence: updated.adjustedConfidence,
                    isValidPattern: updated.isValidPattern,
                    detectionTime: Date().timeIntervalSince(startTime)
                )
                return updated
            }

            // 5. Check for success
            if let bestCandidate = candidates.first,
               bestCandidate.adjustedConfidence >= pass.minimumConfidence {
                print("✓ Success with pass '\(pass.name)': \(bestCandidate.number) (confidence: \(String(format: "%.2f", bestCandidate.adjustedConfidence)))")

                if config.enableEarlyExit {
                    return bestCandidate
                }
            }

            // Store results if configured
            if config.keepAllResults {
                allResults.append(contentsOf: candidates)
            } else if let best = candidates.first {
                allResults.append(best)
            }
        }

        // Return best result from all passes
        let finalResult = allResults.max { $0.adjustedConfidence < $1.adjustedConfidence }

        if let result = finalResult {
            print("✓ Best result: \(result.number) from pass '\(result.passName ?? "unknown")' (confidence: \(String(format: "%.2f", result.adjustedConfidence)))")
        } else {
            print("✗ No valid bib number detected after \(passes.prefix(config.maxPasses).count) passes")
        }

        return finalResult
    }

    // MARK: - Adaptive OCR

    /// Perform OCR with adaptive pass selection based on text analysis
    func recognizeBibNumberAdaptive(in image: CGImage,
                                   analysis: TextRegionAnalysis) -> BibNumberResult? {
        // Select optimal starting pass based on analysis
        let startPassIndex = selectOptimalPassIndex(for: analysis)

        print("Starting with pass \(startPassIndex + 1) based on text analysis:")
        print("  Size: \(analysis.sizeClass.displayName)")
        print("  Contrast: \(analysis.contrast.displayName)")
        print("  Numeric likely: \(analysis.isNumericLikely)")

        // Attempt passes starting from optimal
        var attemptOrder = Array(startPassIndex..<passes.count)
        if startPassIndex > 0 {
            attemptOrder.append(contentsOf: 0..<startPassIndex)
        }

        let originalMaxPasses = config.maxPasses
        let reorderedPasses = attemptOrder.map { passes[$0] }

        // Temporarily replace passes
        let originalPasses = passes
        passes = reorderedPasses

        let result = recognizeBibNumber(in: image)

        // Restore original passes
        passes = originalPasses
        config.maxPasses = originalMaxPasses

        return result
    }

    private func selectOptimalPassIndex(for analysis: TextRegionAnalysis) -> Int {
        switch (analysis.sizeClass, analysis.contrast, analysis.isNumericLikely) {
        case (.veryLarge, .high, true):
            return 0  // Fast Large Numbers

        case (.veryLarge, _, _), (.large, .high, _):
            return 1  // Accurate with Division Markers

        case (.large, _, _), (.medium, .high, _):
            return 2  // Enhanced Preprocessing

        case (.medium, _, _):
            return 3  // Aggressive Enhancement

        case (.small, _, _):
            return 4  // Fallback
        }
    }

    // MARK: - Internal OCR Execution

    private func performOCR(on image: CGImage,
                           settings: OCRSettings) -> [VNRecognizedText]? {
        var results: [VNRecognizedText]?

        let request = BibNumberOCROptimizer.createRequest(with: settings) { visionRequest, error in
            guard error == nil else {
                print("OCR error: \(error!.localizedDescription)")
                return
            }

            results = visionRequest.results as? [VNRecognizedText]
        }

        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform OCR: \(error.localizedDescription)")
            return nil
        }

        return results
    }

    // MARK: - Batch Processing

    /// Process multiple regions
    func recognizeBibNumbers(in image: CGImage,
                            regions: [CGRect]) -> [BibNumberResult] {
        return regions.compactMap { region in
            recognizeBibNumber(in: image, region: region)
        }
    }

    /// Process with text region analyses
    func recognizeBibNumbers(in image: CGImage,
                            analyses: [TextRegionAnalysis]) -> [BibNumberResult] {
        return analyses.compactMap { analysis in
            guard let region = analysis.boundingBox as CGRect? else {
                return nil
            }
            return recognizeBibNumberAdaptive(in: image, analysis: analysis)
        }
    }
}

// MARK: - Example Usage

/*
 Example usage:

 // Method 1: Simple multi-pass OCR
 let ocrSystem = MultiPassBibOCR()
 if let result = ocrSystem.recognizeBibNumber(in: image) {
     print("Detected bib: \(result.number)")
     print("Confidence: \(result.adjustedConfidence)")
     print("Via pass: \(result.passName ?? "unknown")")
 }

 // Method 2: Adaptive OCR with text analysis
 let analyzer = TextRegionAnalyzer()
 if let analysis = try? analyzer.analyze(boundingBox: torsoRegion, in: image) {
     if let result = ocrSystem.recognizeBibNumberAdaptive(in: image, analysis: analysis) {
         print("Detected: \(result.number)")
     }
 }

 // Method 3: Complete pipeline
 let analyzer = TextRegionAnalyzer()
 let ocrSystem = MultiPassBibOCR()

 // Analyze torso regions
 let analyses = analyzer.analyzeRegions(torsoRegions, in: image)
 let bibCandidates = analyzer.filterBibNumberCandidates(analyses)

 // Recognize bib numbers
 let results = ocrSystem.recognizeBibNumbers(in: image, analyses: bibCandidates)

 for result in results {
     print(result.description)
 }
 */
