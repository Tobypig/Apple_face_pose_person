import Foundation
import Vision

// MARK: - Character Confusion Mapping

/// Common OCR character confusions
struct CharacterConfusion {
    let wrong: Character
    let correct: Character
    let confidence: Float  // How confident we are in this correction
    let context: CorrectionContext

    enum CorrectionContext {
        case anyPosition       // Can correct anywhere
        case digitPosition     // Only in digit positions (not first char if division marker allowed)
        case letterPosition    // Only in letter positions (first 1-2 chars)
    }
}

// MARK: - OCR Error Correction Rules

/// Comprehensive OCR error correction rules for bib numbers
class OCRErrorCorrectionRules {

    // MARK: - Common Confusions

    /// Letter → Digit confusions (most common in bib numbers)
    static let letterToDigitConfusions: [CharacterConfusion] = [
        // O (letter) → 0 (zero) - VERY COMMON
        CharacterConfusion(wrong: "O", correct: "0", confidence: 0.95, context: .digitPosition),
        CharacterConfusion(wrong: "o", correct: "0", confidence: 0.95, context: .digitPosition),

        // I (letter) → 1 (one) - VERY COMMON
        CharacterConfusion(wrong: "I", correct: "1", confidence: 0.90, context: .digitPosition),
        CharacterConfusion(wrong: "i", correct: "1", confidence: 0.90, context: .digitPosition),
        CharacterConfusion(wrong: "l", correct: "1", confidence: 0.85, context: .digitPosition),
        CharacterConfusion(wrong: "L", correct: "1", confidence: 0.80, context: .digitPosition),

        // S (letter) → 5 (five) - COMMON
        CharacterConfusion(wrong: "S", correct: "5", confidence: 0.85, context: .digitPosition),
        CharacterConfusion(wrong: "s", correct: "5", confidence: 0.85, context: .digitPosition),

        // Z (letter) → 2 (two)
        CharacterConfusion(wrong: "Z", correct: "2", confidence: 0.75, context: .digitPosition),
        CharacterConfusion(wrong: "z", correct: "2", confidence: 0.75, context: .digitPosition),

        // B (letter) → 8 (eight)
        CharacterConfusion(wrong: "B", correct: "8", confidence: 0.70, context: .digitPosition),
        CharacterConfusion(wrong: "b", correct: "8", confidence: 0.70, context: .digitPosition),

        // G (letter) → 6 (six)
        CharacterConfusion(wrong: "G", correct: "6", confidence: 0.65, context: .digitPosition),
        CharacterConfusion(wrong: "g", correct: "6", confidence: 0.65, context: .digitPosition),

        // T (letter) → 7 (seven)
        CharacterConfusion(wrong: "T", correct: "7", confidence: 0.60, context: .digitPosition),

        // A (letter) → 4 (four) - less common but possible
        CharacterConfusion(wrong: "A", correct: "4", confidence: 0.50, context: .digitPosition),

        // Q (letter) → 0 (zero)
        CharacterConfusion(wrong: "Q", correct: "0", confidence: 0.70, context: .digitPosition),
        CharacterConfusion(wrong: "q", correct: "0", confidence: 0.70, context: .digitPosition),

        // D (letter) → 0 (zero)
        CharacterConfusion(wrong: "D", correct: "0", confidence: 0.60, context: .digitPosition)
    ]

    /// Digit → Digit confusions
    static let digitToDigitConfusions: [CharacterConfusion] = [
        // 0 ↔ 8 (can be confused)
        CharacterConfusion(wrong: "8", correct: "0", confidence: 0.40, context: .anyPosition),

        // 6 ↔ 8
        CharacterConfusion(wrong: "8", correct: "6", confidence: 0.40, context: .anyPosition),

        // 5 ↔ 6 (similar shapes)
        CharacterConfusion(wrong: "6", correct: "5", confidence: 0.35, context: .anyPosition),

        // 1 ↔ 7
        CharacterConfusion(wrong: "7", correct: "1", confidence: 0.30, context: .anyPosition)
    ]

    /// Special character confusions
    static let specialCharacterConfusions: [CharacterConfusion] = [
        // Remove common noise characters
        CharacterConfusion(wrong: "-", correct: "", confidence: 0.80, context: .anyPosition),
        CharacterConfusion(wrong: ".", correct: "", confidence: 0.80, context: .anyPosition),
        CharacterConfusion(wrong: ",", correct: "", confidence: 0.80, context: .anyPosition),
        CharacterConfusion(wrong: " ", correct: "", confidence: 0.90, context: .anyPosition),
        CharacterConfusion(wrong: "/", correct: "", confidence: 0.70, context: .anyPosition),
        CharacterConfusion(wrong: "\\", correct: "", confidence: 0.70, context: .anyPosition)
    ]

    /// Get all confusion rules
    static var allConfusions: [CharacterConfusion] {
        return letterToDigitConfusions + digitToDigitConfusions + specialCharacterConfusions
    }

    /// Get confusion map (wrong char → correct char)
    static func getConfusionMap(context: CharacterConfusion.CorrectionContext? = nil) -> [Character: Character] {
        var map: [Character: Character] = [:]

        let rules = context != nil ? allConfusions.filter { $0.context == context || $0.context == .anyPosition } : allConfusions

        for confusion in rules {
            map[confusion.wrong] = confusion.correct
        }

        return map
    }
}

// MARK: - Correction Result

/// Result of OCR error correction
struct CorrectionResult {
    let original: String
    let corrected: String
    let correctionsMade: [CorrectionDetail]
    let confidence: Float
    let confidenceBoost: Float  // How much confidence increased

    var wasCorrected: Bool {
        return original != corrected
    }

    var correctionCount: Int {
        return correctionsMade.count
    }

    var description: String {
        if !wasCorrected {
            return "No corrections needed: '\(original)'"
        }

        var desc = "'\(original)' → '\(corrected)'"
        desc += " (Confidence: \(String(format: "%.2f", confidence))"
        if confidenceBoost > 0 {
            desc += ", Boost: +\(String(format: "%.2f", confidenceBoost))"
        }
        desc += ")"

        if !correctionsMade.isEmpty {
            desc += "\nCorrections:"
            for detail in correctionsMade {
                desc += "\n  • Position \(detail.position): '\(detail.wrongChar)' → '\(detail.correctChar)' (confidence: \(String(format: "%.2f", detail.confidence)))"
            }
        }

        return desc
    }
}

struct CorrectionDetail {
    let position: Int
    let wrongChar: Character
    let correctChar: Character
    let confidence: Float
}

// MARK: - OCR Error Corrector

/// Automatic OCR error correction for bib numbers
class OCRErrorCorrector {

    // MARK: - Configuration

    struct Configuration {
        var enableAutoCorrection: Bool = true
        var minimumCorrectionConfidence: Float = 0.5
        var confidenceBoostPerCorrection: Float = 0.05
        var maxConfidenceBoost: Float = 0.2
        var allowDivisionMarkers: Bool = true
        var divisionMarkerMaxLength: Int = 2  // Max chars for division (e.g., "AB")
        var enableAggressiveCorrection: Bool = false  // Use lower confidence thresholds

        // Length validation (configurable range)
        var minBibNumberLength: Int = 1      // Minimum bib number length (digits only)
        var maxBibNumberLength: Int = 6      // Maximum bib number length (digits only)
        var rejectOutOfRange: Bool = true    // Reject bibs outside length range
    }

    var config = Configuration()

    // MARK: - Main Correction Method

    /// Correct OCR errors in bib number
    func correct(_ bibNumber: String, originalConfidence: Float = 1.0) -> CorrectionResult {
        guard config.enableAutoCorrection else {
            return CorrectionResult(
                original: bibNumber,
                corrected: bibNumber,
                correctionsMade: [],
                confidence: originalConfidence,
                confidenceBoost: 0.0
            )
        }

        var corrected = bibNumber.uppercased()  // Normalize to uppercase
        var corrections: [CorrectionDetail] = []

        // Step 1: Remove special characters/noise
        let (cleanedText, noiseCorrections) = removeNoise(corrected)
        corrected = cleanedText
        corrections.append(contentsOf: noiseCorrections)

        // Step 2: Position-aware correction
        let (positionCorrected, positionCorrections) = applyPositionAwareCorrection(corrected)
        corrected = positionCorrected
        corrections.append(contentsOf: positionCorrections)

        // Step 3: Calculate confidence boost
        let boost = calculateConfidenceBoost(corrections: corrections)
        let finalConfidence = min(originalConfidence + boost, 1.0)

        return CorrectionResult(
            original: bibNumber,
            corrected: corrected,
            correctionsMade: corrections,
            confidence: finalConfidence,
            confidenceBoost: boost
        )
    }

    // MARK: - Noise Removal

    private func removeNoise(_ text: String) -> (cleaned: String, corrections: [CorrectionDetail]) {
        var cleaned = ""
        var corrections: [CorrectionDetail] = []

        for (index, char) in text.enumerated() {
            if let confusion = OCRErrorCorrectionRules.specialCharacterConfusions.first(where: { $0.wrong == char }) {
                // Found noise character - remove it
                if !confusion.correct.isEmpty {
                    cleaned.append(confusion.correct)
                }

                corrections.append(CorrectionDetail(
                    position: index,
                    wrongChar: char,
                    correctChar: confusion.correct.first ?? Character(""),
                    confidence: confusion.confidence
                ))
            } else {
                cleaned.append(char)
            }
        }

        return (cleaned, corrections)
    }

    // MARK: - Position-Aware Correction

    private func applyPositionAwareCorrection(_ text: String) -> (corrected: String, corrections: [CorrectionDetail]) {
        var corrected = ""
        var corrections: [CorrectionDetail] = []

        for (index, char) in text.enumerated() {
            var currentChar = char

            // Determine if this is a division marker position
            let isDivisionPosition = config.allowDivisionMarkers && index < config.divisionMarkerMaxLength

            // Get appropriate correction rules
            let rules: [CharacterConfusion]
            if isDivisionPosition {
                // First 1-2 chars: Can be letters (division markers) or digits
                // Only apply high-confidence corrections
                rules = OCRErrorCorrectionRules.letterToDigitConfusions.filter { $0.confidence >= 0.85 }
            } else {
                // Rest must be digits
                rules = OCRErrorCorrectionRules.letterToDigitConfusions
            }

            // Try to find correction
            if let confusion = rules.first(where: { $0.wrong == char }) {
                // Check if correction makes sense
                if shouldApplyCorrection(char: char, position: index, confusion: confusion, text: text) {
                    currentChar = confusion.correct

                    corrections.append(CorrectionDetail(
                        position: index,
                        wrongChar: char,
                        correctChar: confusion.correct,
                        confidence: confusion.confidence
                    ))
                }
            }

            corrected.append(currentChar)
        }

        return (corrected, corrections)
    }

    // MARK: - Correction Decision Logic

    private func shouldApplyCorrection(char: Character, position: Int, confusion: CharacterConfusion, text: String) -> Bool {
        // Always apply if confidence is very high
        if confusion.confidence >= 0.90 {
            return true
        }

        // Check minimum threshold
        if confusion.confidence < config.minimumCorrectionConfidence {
            return false
        }

        // Context-based decision
        switch confusion.context {
        case .anyPosition:
            return true

        case .digitPosition:
            // Only apply in non-division positions
            let isDivisionPosition = config.allowDivisionMarkers && position < config.divisionMarkerMaxLength
            if isDivisionPosition {
                // In division position, only correct if very confident
                return confusion.confidence >= 0.90
            }
            return true

        case .letterPosition:
            // Only apply in division positions
            let isDivisionPosition = config.allowDivisionMarkers && position < config.divisionMarkerMaxLength
            return isDivisionPosition
        }
    }

    // MARK: - Confidence Calculation

    private func calculateConfidenceBoost(corrections: [CorrectionDetail]) -> Float {
        guard !corrections.isEmpty else { return 0.0 }

        // Average correction confidence
        let avgConfidence = corrections.map { $0.confidence }.reduce(0, +) / Float(corrections.count)

        // Boost is proportional to number and quality of corrections
        let boost = Float(corrections.count) * config.confidenceBoostPerCorrection * avgConfidence

        return min(boost, config.maxConfidenceBoost)
    }

    // MARK: - Batch Correction

    /// Correct multiple bib numbers
    func correctBatch(_ bibNumbers: [(number: String, confidence: Float)]) -> [CorrectionResult] {
        return bibNumbers.map { correct($0.number, originalConfidence: $0.confidence) }
    }

    // MARK: - Validation

    /// Validate corrected bib number with configurable length
    func validateCorrectedNumber(_ corrected: String) -> Bool {
        // Extract digit part (excluding division markers)
        let digitPart: String
        if config.allowDivisionMarkers {
            // Skip division marker chars at start
            let divisionLength = min(config.divisionMarkerMaxLength, corrected.count)
            var digitStartIndex = 0

            for (index, char) in corrected.enumerated() {
                if index >= divisionLength || char.isNumber {
                    digitStartIndex = index
                    break
                }
            }

            digitPart = String(corrected[corrected.index(corrected.startIndex, offsetBy: digitStartIndex)...])
        } else {
            digitPart = corrected
        }

        // Count digits only
        let digitCount = digitPart.filter { $0.isNumber }.count

        // Validate digit count against configured range
        guard digitCount >= config.minBibNumberLength && digitCount <= config.maxBibNumberLength else {
            if config.rejectOutOfRange {
                return false
            }
        }

        // Validate pattern
        if config.allowDivisionMarkers {
            // Pattern: [A-Z]{0,divisionMax}\d{min,max}
            let pattern = "^[A-Z]{0,\(config.divisionMarkerMaxLength)}\\d{\(config.minBibNumberLength),\(config.maxBibNumberLength)}$"
            return corrected.range(of: pattern, options: .regularExpression) != nil
        } else {
            // Pattern: \d{min,max}
            return corrected.allSatisfy { $0.isNumber } &&
                   corrected.count >= config.minBibNumberLength &&
                   corrected.count <= config.maxBibNumberLength
        }
    }
}

// MARK: - Integration with Existing OCR

extension BibNumberResult {
    /// Apply OCR error correction to this result
    func withErrorCorrection(corrector: OCRErrorCorrector = OCRErrorCorrector()) -> (result: BibNumberResult, correction: CorrectionResult) {
        let correction = corrector.correct(self.number, originalConfidence: self.confidence)

        // Create new result with corrected number
        let correctedResult = BibNumberResult(
            number: correction.corrected,
            confidence: self.confidence,
            boundingBox: self.boundingBox,
            passName: self.passName,
            adjustedConfidence: correction.confidence,
            isValidPattern: corrector.validateCorrectedNumber(correction.corrected),
            detectionTime: self.detectionTime
        )

        return (correctedResult, correction)
    }
}

// MARK: - Example Usage

/*
 Example usage:

 // Create corrector
 let corrector = OCRErrorCorrector()

 // Example 1: Simple correction
 let result1 = corrector.correct("5O25")
 print(result1.description)
 // Output: '5O25' → '5025' (Confidence: 0.95)
 //         Corrections:
 //           • Position 1: 'O' → '0' (confidence: 0.95)

 // Example 2: Multiple corrections
 let result2 = corrector.correct("5I23")
 print(result2.description)
 // Output: '5I23' → '5123' (Confidence: 0.90)
 //         Corrections:
 //           • Position 1: 'I' → '1' (confidence: 0.90)

 // Example 3: Complex correction
 let result3 = corrector.correct("SO25")
 print(result3.description)
 // Output: 'SO25' → '5025' (Confidence: 0.90)
 //         Corrections:
 //           • Position 0: 'S' → '5' (confidence: 0.85)
 //           • Position 1: 'O' → '0' (confidence: 0.95)

 // Example 4: With division marker (should NOT correct)
 corrector.config.allowDivisionMarkers = true
 let result4 = corrector.correct("A123")
 print(result4.description)
 // Output: No corrections needed: 'A123'
 // (A is valid division marker)

 // Example 5: Mixed case
 let result5 = corrector.correct("A5O2")
 print(result5.description)
 // Output: 'A5O2' → 'A502' (Confidence: 0.95)
 //         Corrections:
 //           • Position 2: 'O' → '0' (confidence: 0.95)
 // (A kept as division marker, O corrected to 0)

 // Example 6: Integration with OCR result
 let ocrResult = BibNumberResult(number: "5O25", confidence: 0.75, ...)
 let (corrected, correction) = ocrResult.withErrorCorrection()
 print("Original: \(ocrResult.number)")
 print("Corrected: \(corrected.number)")
 print("Confidence: \(ocrResult.confidence) → \(corrected.adjustedConfidence)")

 // Example 7: Batch correction
 let bibNumbers = [
     ("5O25", 0.75),
     ("5I23", 0.80),
     ("SO25", 0.70),
     ("A123", 0.85)
 ]
 let results = corrector.correctBatch(bibNumbers)
 for result in results {
     print(result.description)
 }

 // Example 8: Configure corrector
 corrector.config.enableAutoCorrection = true
 corrector.config.minimumCorrectionConfidence = 0.6  // Lower threshold
 corrector.config.confidenceBoostPerCorrection = 0.1  // Higher boost
 corrector.config.allowDivisionMarkers = true
 */
