import Foundation

// MARK: - OCR Error Correction Examples

class OCRCorrectionExamples {

    // MARK: - Example 1: Basic Corrections (Your Examples!)

    static func example1_BasicCorrections() {
        print("=== Example 1: Basic OCR Error Corrections ===\n")

        let corrector = OCRErrorCorrector()

        let testCases = [
            "5O25",  // O → 0
            "5I23",  // I → 1
            "SO25",  // S → 5, O → 0
        ]

        for bibNumber in testCases {
            let result = corrector.correct(bibNumber)
            print("✅ \(result.original) → \(result.corrected)")
            if result.wasCorrected {
                for correction in result.correctionsMade {
                    print("   Position \(correction.position): '\(correction.wrongChar)' → '\(correction.correctChar)'")
                }
            }
            print("")
        }
    }

    // MARK: - Example 2: All Common Confusions

    static func example2_AllCommonConfusions() {
        print("\n=== Example 2: All Common Character Confusions ===\n")

        let corrector = OCRErrorCorrector()

        let confusions = [
            ("O to 0", "5O25", "5025"),
            ("I to 1", "5I23", "5123"),
            ("S to 5", "SO25", "5025"),
            ("Z to 2", "Z123", "2123"),
            ("B to 8", "B456", "8456"),
            ("Q to 0", "Q789", "0789"),
            ("l to 1", "5l23", "5123"),
            ("G to 6", "G234", "6234"),
            ("T to 7", "T890", "7890"),
        ]

        print("Common OCR Confusions:\n")

        for (description, input, expected) in confusions {
            let result = corrector.correct(input)
            let success = result.corrected == expected ? "✅" : "❌"
            print("\(success) \(description.padding(toLength: 10, withPad: " ", startingAt: 0)) : '\(input)' → '\(result.corrected)' (expected: '\(expected)')")
        }
    }

    // MARK: - Example 3: Multiple Corrections in One Number

    static func example3_MultipleCorrections() {
        print("\n=== Example 3: Multiple Corrections in One Number ===\n")

        let corrector = OCRErrorCorrector()

        let testCases = [
            "SOIZ",    // S→5, O→0, I→1, Z→2  = "5012"
            "BOOB",    // B→8, O→0, O→0, B→8  = "8008"
            "OOII",    // O→0, O→0, I→1, I→1  = "0011"
            "SIZZ",    // S→5, I→1, Z→2, Z→2  = "5122"
            "lOOl",    // l→1, O→0, O→0, l→1  = "1001"
        ]

        for bibNumber in testCases {
            let result = corrector.correct(bibNumber)
            print("Input:  '\(bibNumber)'")
            print("Output: '\(result.corrected)'")
            print("Corrections: \(result.correctionCount)")
            for (i, correction) in result.correctionsMade.enumerated() {
                print("  \(i+1). Position \(correction.position): '\(correction.wrongChar)' → '\(correction.correctChar)' (conf: \(String(format: "%.2f", correction.confidence)))")
            }
            print("")
        }
    }

    // MARK: - Example 4: Division Markers (DON'T Correct!)

    static func example4_DivisionMarkers() {
        print("\n=== Example 4: Division Markers (Valid Letters) ===\n")

        let corrector = OCRErrorCorrector()
        corrector.config.allowDivisionMarkers = true

        print("Division markers are VALID letters at the start of bib numbers.\n")
        print("Examples: A123 (Division A), M456 (Men's division), F789 (Women's division)\n")

        let testCases = [
            ("A123", "A123"),   // A is valid division marker, keep it
            ("M456", "M456"),   // M is valid, keep it
            ("F789", "F789"),   // F is valid, keep it
            ("AO23", "A023"),   // A is division, but O → 0
            ("AI23", "A123"),   // A is division, but I → 1
            ("AB5O2", "AB502"), // AB are divisions, O → 0
            ("5A23", "5423"),   // A not at start → convert to 4
        ]

        for (input, expected) in testCases {
            let result = corrector.correct(input)
            let success = result.corrected == expected ? "✅" : "❌"

            print("\(success) '\(input)' → '\(result.corrected)' (expected: '\(expected)')")

            if result.wasCorrected {
                print("   Corrections made:")
                for correction in result.correctionsMade {
                    print("     Position \(correction.position): '\(correction.wrongChar)' → '\(correction.correctChar)'")
                }
            } else {
                print("   No corrections (division marker preserved)")
            }
            print("")
        }
    }

    // MARK: - Example 5: Noise Removal

    static func example5_NoiseRemoval() {
        print("\n=== Example 5: Noise and Special Character Removal ===\n")

        let corrector = OCRErrorCorrector()

        let testCases = [
            ("5-025", "5025"),      // Remove hyphen
            ("5.0.2.5", "5025"),    // Remove dots
            ("5 0 25", "5025"),     // Remove spaces
            ("5,025", "5025"),      // Remove comma
            ("5/025", "5025"),      // Remove slash
            ("5\\025", "5025"),     // Remove backslash
        ]

        print("Removing noise characters:\n")

        for (input, expected) in testCases {
            let result = corrector.correct(input)
            let success = result.corrected == expected ? "✅" : "❌"
            print("\(success) '\(input)' → '\(result.corrected)'")
        }
    }

    // MARK: - Example 6: Confidence Boosting

    static func example6_ConfidenceBoost() {
        print("\n=== Example 6: Confidence Boosting After Correction ===\n")

        let corrector = OCRErrorCorrector()

        print("When corrections are made, confidence INCREASES:\n")

        let testCases: [(String, Float)] = [
            ("5O25", 0.65),
            ("5I23", 0.70),
            ("SO25", 0.60),
            ("SOIZ", 0.55),
        ]

        for (bibNumber, originalConfidence) in testCases {
            let result = corrector.correct(bibNumber, originalConfidence: originalConfidence)

            print("Bib: '\(bibNumber)' → '\(result.corrected)'")
            print("  Original Confidence: \(String(format: "%.2f", originalConfidence))")
            print("  After Correction:    \(String(format: "%.2f", result.confidence))")
            print("  Boost:              +\(String(format: "%.2f", result.confidenceBoost))")
            print("  Corrections Made:    \(result.correctionCount)")
            print("")
        }

        print("Why boost confidence?")
        print("  • Corrections fix KNOWN confusions")
        print("  • Makes result MORE reliable")
        print("  • Higher confidence = better ranking")
    }

    // MARK: - Example 7: Integration with OCR Pipeline

    static func example7_IntegrationWithOCR() {
        print("\n=== Example 7: Integration with OCR Pipeline ===\n")

        let corrector = OCRErrorCorrector()

        // Simulate OCR results
        let ocrResults = [
            ("5O25", 0.75),
            ("5I23", 0.80),
            ("SO25", 0.70),
            ("A1O3", 0.85),
        ]

        print("OCR Results → Corrected Results:\n")

        for (bibNumber, confidence) in ocrResults {
            let result = corrector.correct(bibNumber, originalConfidence: confidence)

            print("OCR Output:  '\(bibNumber)' (confidence: \(String(format: "%.2f", confidence)))")
            print("Corrected:   '\(result.corrected)' (confidence: \(String(format: "%.2f", result.confidence)))")

            if result.wasCorrected {
                print("Changes:")
                for correction in result.correctionsMade {
                    print("  • Position \(correction.position): '\(correction.wrongChar)' → '\(correction.correctChar)'")
                }
            }
            print("")
        }
    }

    // MARK: - Example 8: Real-World Scenarios

    static func example8_RealWorldScenarios() {
        print("\n=== Example 8: Real-World Race Bib Scenarios ===\n")

        let corrector = OCRErrorCorrector()
        corrector.config.allowDivisionMarkers = true

        let scenarios = [
            (
                scenario: "Finish Line Photo (Clear)",
                input: "5025",
                description: "Perfect OCR, no corrections needed"
            ),
            (
                scenario: "Distant Runner (Blurry)",
                input: "5O25",
                description: "O misread as letter, should be 0"
            ),
            (
                scenario: "Backlit Photo (Low Contrast)",
                input: "SOIZ",
                description: "Multiple confusions: S→5, O→0, I→1, Z→2"
            ),
            (
                scenario: "Division Marker (Men's)",
                input: "M5O2",
                description: "M is valid division, O→0"
            ),
            (
                scenario: "Motion Blur",
                input: "5I23",
                description: "I confused with 1"
            ),
            (
                scenario: "Dirty Bib",
                input: "B8O6",
                description: "B→8, O→0"
            ),
        ]

        for (scenario, input, description) in scenarios {
            let result = corrector.correct(input)

            print("Scenario: \(scenario)")
            print("  Description: \(description)")
            print("  Input:       '\(input)'")
            print("  Corrected:   '\(result.corrected)'")

            if result.wasCorrected {
                print("  Status:      ✅ Corrected (\(result.correctionCount) changes)")
            } else {
                print("  Status:      ✅ No corrections needed")
            }
            print("")
        }
    }

    // MARK: - Example 9: Configuration Options

    static func example9_ConfigurationOptions() {
        print("\n=== Example 9: Configuration Options ===\n")

        let corrector = OCRErrorCorrector()

        print("Default Configuration:")
        print("  • Auto Correction: \(corrector.config.enableAutoCorrection)")
        print("  • Min Confidence: \(corrector.config.minimumCorrectionConfidence)")
        print("  • Confidence Boost: \(corrector.config.confidenceBoostPerCorrection)")
        print("  • Allow Division Markers: \(corrector.config.allowDivisionMarkers)")
        print("")

        // Test with default config
        let result1 = corrector.correct("5O25")
        print("Default: '5O25' → '\(result1.corrected)'")

        // Disable auto correction
        corrector.config.enableAutoCorrection = false
        let result2 = corrector.correct("5O25")
        print("Disabled: '5O25' → '\(result2.corrected)' (no change)")

        // Re-enable with higher boost
        corrector.config.enableAutoCorrection = true
        corrector.config.confidenceBoostPerCorrection = 0.10  // Higher boost
        let result3 = corrector.correct("5O25", originalConfidence: 0.70)
        print("High Boost: Confidence \(String(format: "%.2f", 0.70)) → \(String(format: "%.2f", result3.confidence)) (+\(String(format: "%.2f", result3.confidenceBoost)))")
    }

    // MARK: - Example 10: Validation

    static func example10_Validation() {
        print("\n=== Example 10: Validation of Corrected Numbers ===\n")

        let corrector = OCRErrorCorrector()
        corrector.config.allowDivisionMarkers = true

        let testCases = [
            "5025",    // Valid: pure digits
            "A123",    // Valid: division + digits
            "AB123",   // Valid: 2-letter division + digits
            "5O25",    // Will be corrected to "5025" (valid)
            "ABCD",    // Invalid: too many letters
            "12345678", // Invalid: too long
        ]

        for input in testCases {
            let result = corrector.correct(input)
            let isValid = corrector.validateCorrectedNumber(result.corrected)

            let status = isValid ? "✅ Valid" : "❌ Invalid"
            print("\(status): '\(input)' → '\(result.corrected)'")
        }
    }

    // MARK: - Run All Examples

    static func runAll() {
        example1_BasicCorrections()
        example2_AllCommonConfusions()
        example3_MultipleCorrections()
        example4_DivisionMarkers()
        example5_NoiseRemoval()
        example6_ConfidenceBoost()
        example7_IntegrationWithOCR()
        example8_RealWorldScenarios()
        example9_ConfigurationOptions()
        example10_Validation()
    }
}

// MARK: - Quick Reference

/*
 QUICK REFERENCE: OCR Error Correction
 ════════════════════════════════════════════════════════════

 COMMON CONFUSIONS:
 ─────────────────
 O, o → 0    "5O25" → "5025" ✅
 I, i, l → 1 "5I23" → "5123" ✅
 S, s → 5    "SO25" → "5025" ✅
 Z, z → 2    "Z123" → "2123" ✅
 B, b → 8    "B456" → "8456" ✅
 Q, q → 0    "Q789" → "0789" ✅
 G, g → 6    "G234" → "6234" ✅
 T → 7       "T890" → "7890" ✅

 USAGE:
 ─────
 let corrector = OCRErrorCorrector()

 // Simple correction
 let result = corrector.correct("5O25")
 print(result.corrected)  // "5025"

 // With confidence
 let result2 = corrector.correct("5O25", originalConfidence: 0.75)
 print(result2.confidence)  // 0.80 (boosted!)

 // With division markers
 corrector.config.allowDivisionMarkers = true
 let result3 = corrector.correct("A123")  // "A123" (A preserved)

 // Integration with OCR
 let (corrected, correction) = ocrResult.withErrorCorrection()

 CONFIDENCE BOOST:
 ────────────────
 Original: 0.75
 After correction: 0.80 (+0.05)

 Why? Fixing known confusions makes result MORE reliable!

 ════════════════════════════════════════════════════════════

 Usage:

 // Run all examples
 OCRCorrectionExamples.runAll()

 // Or run specific
 OCRCorrectionExamples.example1_BasicCorrections()
 */
