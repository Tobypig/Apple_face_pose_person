//
//  BibOrientationExamples.swift
//  Apple Vision Framework - Bib Orientation Detection & Correction Examples
//
//  Demonstrates upside-down detection using pose estimation and 180° flip correction
//

import Foundation
import Vision
import CoreGraphics

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Example 1: Basic Orientation Detection

/// Detect if person is upside-down using head/hip position
func example1_basicOrientationDetection() {
    print("\n=== Example 1: Basic Orientation Detection ===\n")

    let detector = BibOrientationDetector()

    // Simulate upright pose (head Y > hip Y in Vision coordinates)
    let uprightPose = createMockPose(headY: 0.8, hipY: 0.5)
    let uprightResult = detector.detectOrientation(from: uprightPose)

    print("UPRIGHT POSE:")
    print(uprightResult.description)
    print("✅ Is Upright: \(uprightResult.orientation == .upright)")

    // Simulate upside-down pose (head Y < hip Y)
    let upsideDownPose = createMockPose(headY: 0.3, hipY: 0.6)
    let upsideDownResult = detector.detectOrientation(from: upsideDownPose)

    print("\nUPSIDE-DOWN POSE:")
    print(upsideDownResult.description)
    print("⚠️ Is Upside-Down: \(upsideDownResult.isUpsideDown)")

    print("\n✅ Example 1 Complete")
}

// MARK: - Example 2: Number Flip Correction

/// Demonstrate 180° flip correction (reverse + 6↔9 swap)
func example2_numberFlipCorrection() {
    print("\n=== Example 2: Number Flip Correction ===\n")

    let corrector = NumberFlipCorrector()

    // Test cases: what OCR reads vs actual bib number
    let testCases: [(ocr: String, actual: String)] = [
        ("6908", "8096"),  // Classic case: 8096 upside-down
        ("9621", "1296"),  // Multiple 6/9 swaps
        ("8068", "8608"),  // 8 and 0 stay same
        ("1001", "1001"),  // Symmetric number
        ("6969", "6969"),  // Palindrome with 6/9
    ]

    for (ocr, actual) in testCases {
        let flipped = corrector.flip(ocr)
        let isCorrect = flipped == actual
        let symbol = isCorrect ? "✅" : "❌"

        print("\(symbol) OCR: '\(ocr)' → Flipped: '\(flipped)' (Expected: '\(actual)')")

        if corrector.canFlip(ocr) {
            print("   Contains 6/9: Can flip")
        }

        if corrector.isAmbiguous(ocr) {
            print("   ⚠️ Ambiguous (all symmetric digits)")
        }
    }

    print("\n✅ Example 2 Complete")
}

// MARK: - Example 3: Integrated Orientation Correction

/// Full orientation detection + correction using pose estimation
func example3_integratedCorrection() {
    print("\n=== Example 3: Integrated Orientation Correction ===\n")

    let corrector = BibOrientationCorrector()

    // Scenario 1: Upside-down photo, OCR reads "6908" but actual is "8096"
    print("SCENARIO 1: Upside-Down Photo")
    let upsideDownPose = createMockPose(headY: 0.3, hipY: 0.6)
    let result1 = corrector.correct("6908", pose: upsideDownPose, originalConfidence: 0.92)

    print(result1.description)
    print("✅ Corrected: '\(result1.original)' → '\(result1.corrected)'")

    // Scenario 2: Normal photo, OCR reads "8096" correctly
    print("\nSCENARIO 2: Normal/Upright Photo")
    let uprightPose = createMockPose(headY: 0.8, hipY: 0.5)
    let result2 = corrector.correct("8096", pose: uprightPose, originalConfidence: 0.95)

    print(result2.description)
    print("✅ No correction needed: '\(result2.corrected)'")

    // Scenario 3: Uncertain orientation (use score validation)
    print("\nSCENARIO 3: Uncertain Orientation (Score-Based Validation)")
    let result3 = corrector.correct("9621", pose: nil, originalConfidence: 0.85)

    print(result3.description)
    print("Original Score: \(String(format: "%.2f", result3.originalScore))")
    print("Flipped Score: \(String(format: "%.2f", result3.flippedScore))")

    print("\n✅ Example 3 Complete")
}

// MARK: - Example 4: OCR Pipeline Integration

/// Integrate orientation correction into OCR pipeline
func example4_ocrPipelineIntegration() {
    print("\n=== Example 4: OCR Pipeline Integration ===\n")

    let corrector = BibOrientationCorrector()

    // Simulate OCR results
    let ocrResults = [
        BibNumberResult(number: "6908", confidence: 0.92, boundingBox: CGRect.zero, passName: "Fast", adjustedConfidence: 0.92, isValidPattern: true, detectionTime: 0.1),
        BibNumberResult(number: "1296", confidence: 0.88, boundingBox: CGRect.zero, passName: "Accurate", adjustedConfidence: 0.88, isValidPattern: true, detectionTime: 0.2),
        BibNumberResult(number: "8081", confidence: 0.95, boundingBox: CGRect.zero, passName: "Fast", adjustedConfidence: 0.95, isValidPattern: true, detectionTime: 0.1),
    ]

    // Simulate pose (upside-down)
    let pose = createMockPose(headY: 0.3, hipY: 0.6)

    print("Processing OCR results with orientation correction...\n")

    for (index, ocrResult) in ocrResults.enumerated() {
        let (correctedResult, correction) = ocrResult.withOrientationCorrection(pose: pose, corrector: corrector)

        print("Result \(index + 1):")
        print("  Original OCR: '\(ocrResult.number)' (confidence: \(String(format: "%.2f", ocrResult.confidence)))")
        print("  Corrected: '\(correctedResult.number)' (confidence: \(String(format: "%.2f", correctedResult.confidence)))")

        if correction.wasFlipped {
            print("  ⚠️ FLIPPED (upside-down detected)")
        } else {
            print("  ✓ No flip needed")
        }
        print()
    }

    print("✅ Example 4 Complete")
}

// MARK: - Example 5: Real-World Scenarios

/// Real-world race photo scenarios
func example5_realWorldScenarios() {
    print("\n=== Example 5: Real-World Scenarios ===\n")

    let corrector = BibOrientationCorrector()

    // Scenario 1: Runner doing handstand (upside-down!)
    print("SCENARIO 1: Runner doing handstand 🤸")
    let handstandPose = createMockPose(headY: 0.2, hipY: 0.7)  // Head well below hips
    let handstand = corrector.correct("6908", pose: handstandPose, originalConfidence: 0.90)
    print("  Bib shows: 8096")
    print("  OCR reads: \(handstand.original) (upside-down!)")
    print("  Corrected: \(handstand.corrected) ✅")
    print("  Orientation: \(handstand.orientation.emoji) \(handstand.orientation.displayName)")

    // Scenario 2: Photo taken from above (camera upside-down)
    print("\nSCENARIO 2: Camera held upside-down 📸")
    let upsideDownCamera = createMockPose(headY: 0.35, hipY: 0.65)
    let camera = corrector.correct("9621", pose: upsideDownCamera, originalConfidence: 0.87)
    print("  Actual bib: 1296")
    print("  OCR reads: \(camera.original)")
    print("  Corrected: \(camera.corrected) ✅")

    // Scenario 3: Normal race photo
    print("\nSCENARIO 3: Normal race photo 🏃")
    let normalPose = createMockPose(headY: 0.75, hipY: 0.45)
    let normal = corrector.correct("8096", pose: normalPose, originalConfidence: 0.95)
    print("  Bib shows: 8096")
    print("  OCR reads: \(normal.original)")
    print("  Corrected: \(normal.corrected) ✅")
    print("  Orientation: \(normal.orientation.emoji) \(normal.orientation.displayName)")

    // Scenario 4: Ambiguous symmetric number
    print("\nSCENARIO 4: Symmetric number (looks same upside-down) 🔄")
    let symmetricPose = createMockPose(headY: 0.3, hipY: 0.6)
    let symmetric = corrector.correct("8081", pose: symmetricPose, originalConfidence: 0.93)
    print("  Bib shows: 8081 or 1808? (ambiguous!)")
    print("  OCR reads: \(symmetric.original)")
    print("  Corrected: \(symmetric.corrected)")
    print("  ⚠️ Flipped: \(symmetric.wasFlipped)")

    print("\n✅ Example 5 Complete")
}

// MARK: - Example 6: Score-Based Validation

/// Use scoring to decide flip when orientation is uncertain
func example6_scoreBasedValidation() {
    print("\n=== Example 6: Score-Based Validation ===\n")

    let corrector = NumberFlipCorrector()

    let testNumbers = [
        "6234",  // Starts with 6
        "9876",  // Starts with 9
        "8096",  // Contains 6/9
        "1296",  // Good number
        "2345",  // No 6/9
    ]

    for number in testNumbers {
        let flipped = corrector.flip(number)
        let originalScore = corrector.scoreValidity(number)
        let flippedScore = corrector.scoreValidity(flipped)

        print("\nNumber: '\(number)'")
        print("  Original Score: \(String(format: "%.2f", originalScore))")
        print("  Flipped ('\(flipped)') Score: \(String(format: "%.2f", flippedScore))")

        if flippedScore > originalScore + 0.2 {
            print("  → Recommend FLIP")
        } else if originalScore > flippedScore + 0.2 {
            print("  → Keep original")
        } else {
            print("  → Uncertain (scores similar)")
        }
    }

    print("\n✅ Example 6 Complete")
}

// MARK: - Example 7: Batch Processing

/// Process multiple OCR results with orientation correction
func example7_batchProcessing() {
    print("\n=== Example 7: Batch Processing ===\n")

    let corrector = BibOrientationCorrector()
    let pose = createMockPose(headY: 0.3, hipY: 0.6)  // Upside-down

    let ocrResults = [
        "6908", "9621", "8068", "1001", "8096",
        "6969", "1296", "8081", "9999", "0000"
    ]

    print("Processing \(ocrResults.count) OCR results (upside-down pose detected)...\n")

    var flippedCount = 0
    var unflippedCount = 0

    for ocr in ocrResults {
        let result = corrector.correct(ocr, pose: pose, originalConfidence: 0.90)

        if result.wasFlipped {
            print("✓ '\(ocr)' → '\(result.corrected)' (flipped)")
            flippedCount += 1
        } else {
            print("  '\(ocr)' → '\(result.corrected)' (no change)")
            unflippedCount += 1
        }
    }

    print("\nSummary:")
    print("  Flipped: \(flippedCount)")
    print("  Unchanged: \(unflippedCount)")
    print("  Total: \(ocrResults.count)")

    print("\n✅ Example 7 Complete")
}

// MARK: - Example 8: Configuration Options

/// Demonstrate configuration options
func example8_configurationOptions() {
    print("\n=== Example 8: Configuration Options ===\n")

    // Standard configuration
    print("STANDARD CONFIGURATION:")
    let standard = BibOrientationCorrector()
    print("  Orientation Correction: \(standard.config.enableOrientationCorrection)")
    print("  Auto-Flip on Upside-Down: \(standard.config.autoFlipOnUpsideDown)")
    print("  Use Score Validation: \(standard.config.useScoreValidation)")
    print("  Min Confidence: \(standard.config.minimumOrientationConfidence)")

    // Disabled configuration
    print("\nDISABLED CONFIGURATION:")
    let disabled = BibOrientationCorrector()
    disabled.config.enableOrientationCorrection = false
    let result1 = disabled.correct("6908", pose: createMockPose(headY: 0.3, hipY: 0.6))
    print("  Input: '6908'")
    print("  Output: '\(result1.corrected)' (no correction)")

    // High confidence threshold
    print("\nHIGH CONFIDENCE THRESHOLD:")
    let highConfidence = BibOrientationCorrector()
    highConfidence.config.minimumOrientationConfidence = 0.9
    let lowConfPose = createMockPoseLowConfidence(headY: 0.3, hipY: 0.6, confidence: 0.5)
    let result2 = highConfidence.correct("6908", pose: lowConfPose)
    print("  Min Confidence: 0.9")
    print("  Pose Confidence: 0.5")
    print("  Input: '6908'")
    print("  Output: '\(result2.corrected)' (below threshold, may use score validation)")

    print("\n✅ Example 8 Complete")
}

// MARK: - Example 9: Integration with Full Pipeline

/// Complete pipeline: Person → Pose → Torso → OCR → Orientation Correction
func example9_fullPipelineIntegration() {
    print("\n=== Example 9: Full Pipeline Integration ===\n")

    print("COMPLETE PIPELINE:")
    print("1. Detect Person ✅")
    print("2. Estimate Pose ✅")
    print("3. Extract Torso Region ✅")
    print("4. Perform OCR → Result: '6908'")
    print("5. Detect Orientation → Upside-Down!")
    print("6. Correct Orientation → '8096' ✅")

    let pose = createMockPose(headY: 0.3, hipY: 0.6)
    let corrector = BibOrientationCorrector()

    // Simulate pipeline
    let ocrResult = "6908"
    let correction = corrector.correct(ocrResult, pose: pose, originalConfidence: 0.92)

    print("\nPIPELINE RESULT:")
    print(correction.description)

    print("\nFINAL BIB NUMBER: \(correction.corrected)")
    print("Confidence: \(String(format: "%.2f", correction.confidence))")

    print("\n✅ Example 9 Complete")
}

// MARK: - Mock Data Helpers

/// Create mock upright pose for testing
func createMockPose(headY: CGFloat, hipY: CGFloat) -> VNHumanBodyPoseObservation {
    // In a real implementation, this would create a proper VNHumanBodyPoseObservation
    // For testing, we'll use a mock implementation
    return MockPoseObservation(headY: headY, hipY: hipY, confidence: 0.95)
}

/// Create mock pose with low confidence
func createMockPoseLowConfidence(headY: CGFloat, hipY: CGFloat, confidence: Float) -> VNHumanBodyPoseObservation {
    return MockPoseObservation(headY: headY, hipY: hipY, confidence: confidence)
}

// MARK: - Mock VNHumanBodyPoseObservation

class MockPoseObservation: VNHumanBodyPoseObservation {
    private let mockHeadY: CGFloat
    private let mockHipY: CGFloat
    private let mockConfidence: Float

    init(headY: CGFloat, hipY: CGFloat, confidence: Float) {
        self.mockHeadY = headY
        self.mockHipY = hipY
        self.mockConfidence = confidence
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func recognizedPoint(_ jointName: VNHumanBodyPoseObservation.JointName) throws -> VNRecognizedPoint {
        switch jointName {
        case .nose, .neck, .leftEye, .rightEye:
            return MockRecognizedPoint(x: 0.5, y: mockHeadY, confidence: mockConfidence)
        case .root, .leftHip, .rightHip:
            return MockRecognizedPoint(x: 0.5, y: mockHipY, confidence: mockConfidence)
        default:
            throw NSError(domain: "MockPose", code: 1, userInfo: [NSLocalizedDescriptionKey: "Joint not available"])
        }
    }
}

// MARK: - Mock VNRecognizedPoint

class MockRecognizedPoint: VNRecognizedPoint {
    private let mockLocation: CGPoint
    private let mockConfidence: Float

    init(x: CGFloat, y: CGFloat, confidence: Float) {
        self.mockLocation = CGPoint(x: x, y: y)
        self.mockConfidence = confidence
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override var location: CGPoint {
        return mockLocation
    }

    override var confidence: VNConfidence {
        return mockConfidence
    }
}

// MARK: - Run All Examples

func runAllOrientationCorrectionExamples() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║   Bib Orientation Detection & Correction Examples         ║")
    print("║   Fix upside-down reading: 8096 → 6908 ✅                  ║")
    print("╚════════════════════════════════════════════════════════════╝")

    example1_basicOrientationDetection()
    example2_numberFlipCorrection()
    example3_integratedCorrection()
    example4_ocrPipelineIntegration()
    example5_realWorldScenarios()
    example6_scoreBasedValidation()
    example7_batchProcessing()
    example8_configurationOptions()
    example9_fullPipelineIntegration()

    print("\n╔════════════════════════════════════════════════════════════╗")
    print("║   ✅ All Orientation Correction Examples Complete!        ║")
    print("╚════════════════════════════════════════════════════════════╝\n")
}

// MARK: - Usage

/*
 Run all examples:

 runAllOrientationCorrectionExamples()

 Or run individual examples:

 example1_basicOrientationDetection()
 example2_numberFlipCorrection()
 example3_integratedCorrection()
 etc.

 Key Features Demonstrated:

 1. **Orientation Detection**
    - Uses pose estimation (head Y vs hip Y position)
    - Vision coordinates: origin at bottom-left, Y increases upward
    - Head above hips (headY > hipY) = upright
    - Head below hips (headY < hipY) = upside-down

 2. **Number Flip Correction**
    - Reverses string
    - Swaps 6 ↔ 9
    - Preserves symmetric digits (0, 1, 8)
    - Example: "6908" → reverse → "8096" → swap → "8096" ✅

 3. **Score-Based Validation**
    - When orientation is uncertain, use scoring
    - Penalizes numbers starting with 6/9
    - Penalizes digits that look wrong upside-down (2, 3, 4, 5, 7)
    - Prefer numbers in typical race range (1-99999)

 4. **OCR Pipeline Integration**
    - Seamlessly integrates with BibNumberResult
    - Applies correction automatically based on pose
    - Preserves original OCR confidence
    - Returns both corrected result and correction details

 Real-World Use Cases:

 - Runner doing handstand in photo
 - Camera held upside-down
 - Photo taken from unusual angle
 - Scanned images rotated incorrectly
 - Automatic correction of upside-down bibs

 Benefits:

 - Prevents catastrophic OCR errors (8096 ≠ 6908!)
 - Uses anatomical landmarks (reliable)
 - Configurable and extensible
 - Works with existing OCR pipeline
 - Handles ambiguous cases gracefully
 */
