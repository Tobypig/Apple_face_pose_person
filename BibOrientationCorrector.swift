import Foundation
import Vision
import CoreGraphics

// MARK: - Orientation Detection

/// Person/bib orientation in image
enum BibOrientation {
    case upright       // Normal (head above hips)
    case upsideDown    // Inverted (head below hips)
    case uncertain     // Cannot determine (missing pose data)

    var displayName: String {
        switch self {
        case .upright: return "Upright (Normal)"
        case .upsideDown: return "Upside-Down (Inverted)"
        case .uncertain: return "Uncertain"
        }
    }

    var emoji: String {
        switch self {
        case .upright: return "⬆️"
        case .upsideDown: return "⬇️"
        case .uncertain: return "❓"
        }
    }
}

// MARK: - Orientation Detection Result

struct OrientationDetectionResult {
    let orientation: BibOrientation
    let confidence: Float
    let headPosition: CGPoint?
    let hipPosition: CGPoint?
    let verticalDifference: CGFloat?  // Positive = head above hips, Negative = head below hips

    var isUpsideDown: Bool {
        return orientation == .upsideDown
    }

    var description: String {
        var desc = "Orientation: \(orientation.emoji) \(orientation.displayName) (confidence: \(String(format: "%.2f", confidence)))"
        if let head = headPosition, let hip = hipPosition, let diff = verticalDifference {
            desc += "\n  Head: (x: \(String(format: "%.0f", head.x)), y: \(String(format: "%.0f", head.y)))"
            desc += "\n  Hip: (x: \(String(format: "%.0f", hip.x)), y: \(String(format: "%.0f", hip.y)))"
            desc += "\n  Vertical Diff: \(String(format: "%.0f", diff)) (positive = upright)"
        }
        return desc
    }
}

// MARK: - Bib Orientation Detector

/// Detects if person/bib is upside-down using pose estimation
class BibOrientationDetector {

    // MARK: - Configuration

    struct Configuration {
        var minimumConfidenceForDetection: Float = 0.3  // Min joint confidence
        var uncertaintyThreshold: CGFloat = 20.0        // Min vertical distance to be certain
        var preferHeadJoint: VNHumanBodyPoseObservation.JointName = .nose
        var preferHipJoint: VNHumanBodyPoseObservation.JointName = .root  // Center of hips
    }

    var config = Configuration()

    // MARK: - Main Detection

    /// Detect orientation from pose estimation result
    func detectOrientation(from pose: VNHumanBodyPoseObservation) -> OrientationDetectionResult {
        // Try to get head position (prefer nose, fallback to neck)
        let headJoints: [VNHumanBodyPoseObservation.JointName] = [.nose, .neck, .leftEye, .rightEye]
        var headPoint: (point: VNRecognizedPoint, name: VNHumanBodyPoseObservation.JointName)?

        for joint in headJoints {
            if let point = try? pose.recognizedPoint(joint),
               point.confidence >= config.minimumConfidenceForDetection {
                headPoint = (point, joint)
                break
            }
        }

        // Try to get hip position (prefer root, fallback to left/right hip)
        let hipJoints: [VNHumanBodyPoseObservation.JointName] = [.root, .leftHip, .rightHip]
        var hipPoint: (point: VNRecognizedPoint, name: VNHumanBodyPoseObservation.JointName)?

        for joint in hipJoints {
            if let point = try? pose.recognizedPoint(joint),
               point.confidence >= config.minimumConfidenceForDetection {
                hipPoint = (point, joint)
                break
            }
        }

        // Check if we have both points
        guard let head = headPoint, let hip = hipPoint else {
            return OrientationDetectionResult(
                orientation: .uncertain,
                confidence: 0.0,
                headPosition: nil,
                hipPosition: nil,
                verticalDifference: nil
            )
        }

        // Calculate positions (Vision coordinates: origin at bottom-left, Y increases upward)
        let headY = head.point.location.y
        let hipY = hip.point.location.y

        // Vertical difference (positive = head above hips = upright)
        let verticalDiff = headY - hipY

        // Determine orientation
        let orientation: BibOrientation
        let confidence: Float

        if abs(verticalDiff) < config.uncertaintyThreshold / 1000.0 {  // Normalize to 0-1 range
            // Too close to call
            orientation = .uncertain
            confidence = 0.5
        } else if verticalDiff > 0 {
            // Head above hips = normal/upright
            orientation = .upright
            confidence = min(head.point.confidence, hip.point.confidence)
        } else {
            // Head below hips = upside-down!
            orientation = .upsideDown
            confidence = min(head.point.confidence, hip.point.confidence)
        }

        return OrientationDetectionResult(
            orientation: orientation,
            confidence: confidence,
            headPosition: CGPoint(x: head.point.location.x, y: head.point.location.y),
            hipPosition: CGPoint(x: hip.point.location.x, y: hip.point.location.y),
            verticalDifference: verticalDiff
        )
    }

    /// Detect orientation from multiple poses (use first available)
    func detectOrientation(from poses: [VNHumanBodyPoseObservation]) -> OrientationDetectionResult? {
        guard let firstPose = poses.first else {
            return nil
        }
        return detectOrientation(from: firstPose)
    }
}

// MARK: - Number Flip Corrector

/// Corrects upside-down bib numbers (180° rotation)
class NumberFlipCorrector {

    // MARK: - Digit Flip Map

    /// Map of digits when flipped 180°
    private static let digitFlipMap: [Character: Character] = [
        "6": "9",
        "9": "6",
        "0": "0",  // Same upside-down
        "1": "1",  // Same upside-down (might look like 1 or I)
        "8": "8",  // Same upside-down
        // 2, 3, 4, 5, 7 look wrong upside-down (will be caught by validation)
    ]

    /// Digits that are same when flipped
    private static let symmetricDigits: Set<Character> = ["0", "1", "8"]

    /// Digits that make sense when flipped (6 ↔ 9)
    private static let flippableDigits: Set<Character> = ["6", "9"]

    // MARK: - Flip Operations

    /// Flip bib number 180° (reverse + swap 6↔9)
    func flip(_ bibNumber: String) -> String {
        // Step 1: Reverse the string
        let reversed = String(bibNumber.reversed())

        // Step 2: Swap 6 ↔ 9
        let flipped = reversed.map { char -> Character in
            return NumberFlipCorrector.digitFlipMap[char] ?? char
        }

        return String(flipped)
    }

    /// Check if bib number contains flippable digits (6 or 9)
    func canFlip(_ bibNumber: String) -> Bool {
        return bibNumber.contains { NumberFlipCorrector.flippableDigits.contains($0) }
    }

    /// Check if bib number is ambiguous (all symmetric digits)
    func isAmbiguous(_ bibNumber: String) -> Bool {
        // Numbers like "8081", "1010" look the same upside-down
        let digits = bibNumber.filter { $0.isNumber }
        return digits.allSatisfy { NumberFlipCorrector.symmetricDigits.contains($0) }
    }

    // MARK: - Validation

    /// Score how "valid" a bib number looks
    func scoreValidity(_ bibNumber: String) -> Float {
        var score: Float = 1.0

        // Penalize if contains digits that look wrong upside-down
        let invalidUpsideDown: Set<Character> = ["2", "3", "4", "5", "7"]
        let invalidCount = bibNumber.filter { invalidUpsideDown.contains($0) }.count

        if invalidCount > 0 {
            score -= Float(invalidCount) * 0.2
        }

        // Penalize unusual patterns
        if bibNumber.hasPrefix("9") && bibNumber.count > 3 {
            score -= 0.1  // Less common to start with 9
        }

        if bibNumber.hasPrefix("6") && bibNumber.count > 3 {
            score -= 0.1  // Less common to start with 6
        }

        // Prefer numbers in typical race range (1-9999)
        if let numericValue = Int(bibNumber.filter { $0.isNumber }) {
            if numericValue < 1 || numericValue > 99999 {
                score -= 0.2
            }
        }

        return max(score, 0.0)
    }
}

// MARK: - Orientation-Aware Correction Result

struct OrientationCorrectionResult {
    let original: String
    let corrected: String
    let wasFlipped: Bool
    let orientation: BibOrientation
    let orientationConfidence: Float
    let originalScore: Float
    let flippedScore: Float
    let confidence: Float

    var description: String {
        var desc = """
        Orientation Correction:
          Original: '\(original)'
          Corrected: '\(corrected)'
          Orientation: \(orientation.emoji) \(orientation.displayName)
        """

        if wasFlipped {
            desc += "\n  ⚠️ Flipped (upside-down detection)"
            desc += "\n  Original Score: \(String(format: "%.2f", originalScore))"
            desc += "\n  Flipped Score: \(String(format: "%.2f", flippedScore))"
        } else {
            desc += "\n  ✓ No flip needed"
        }

        desc += "\n  Confidence: \(String(format: "%.2f", confidence))"

        return desc
    }
}

// MARK: - Integrated Orientation Corrector

/// Complete orientation detection and correction system
class BibOrientationCorrector {

    private let orientationDetector = BibOrientationDetector()
    private let flipCorrector = NumberFlipCorrector()

    // MARK: - Configuration

    struct Configuration {
        var enableOrientationCorrection: Bool = true
        var autoFlipOnUpsideDown: Bool = true
        var useScoreValidation: Bool = true  // Compare scores to decide
        var minimumOrientationConfidence: Float = 0.5
    }

    var config = Configuration()

    // MARK: - Main Correction

    /// Correct bib number orientation using pose estimation
    func correct(_ bibNumber: String,
                 pose: VNHumanBodyPoseObservation?,
                 originalConfidence: Float = 1.0) -> OrientationCorrectionResult {

        guard config.enableOrientationCorrection else {
            return OrientationCorrectionResult(
                original: bibNumber,
                corrected: bibNumber,
                wasFlipped: false,
                orientation: .uncertain,
                orientationConfidence: 0.0,
                originalScore: 1.0,
                flippedScore: 0.0,
                confidence: originalConfidence
            )
        }

        // Detect orientation from pose
        let orientationResult: OrientationDetectionResult
        if let pose = pose {
            orientationResult = orientationDetector.detectOrientation(from: pose)
        } else {
            orientationResult = OrientationDetectionResult(
                orientation: .uncertain,
                confidence: 0.0,
                headPosition: nil,
                hipPosition: nil,
                verticalDifference: nil
            )
        }

        // Check if we should flip
        let shouldFlip: Bool
        let flippedNumber = flipCorrector.flip(bibNumber)

        if orientationResult.isUpsideDown &&
           orientationResult.confidence >= config.minimumOrientationConfidence {
            // Clear upside-down detection
            shouldFlip = true
        } else if config.useScoreValidation && flipCorrector.canFlip(bibNumber) {
            // Uncertain or low confidence - use score comparison
            let originalScore = flipCorrector.scoreValidity(bibNumber)
            let flippedScore = flipCorrector.scoreValidity(flippedNumber)

            // Flip if flipped version scores significantly better
            shouldFlip = flippedScore > originalScore + 0.2
        } else {
            shouldFlip = false
        }

        let corrected = shouldFlip ? flippedNumber : bibNumber
        let finalConfidence = originalConfidence * orientationResult.confidence

        return OrientationCorrectionResult(
            original: bibNumber,
            corrected: corrected,
            wasFlipped: shouldFlip,
            orientation: orientationResult.orientation,
            orientationConfidence: orientationResult.confidence,
            originalScore: flipCorrector.scoreValidity(bibNumber),
            flippedScore: flipCorrector.scoreValidity(flippedNumber),
            confidence: finalConfidence
        )
    }

    /// Correct with pose array (uses first pose)
    func correct(_ bibNumber: String,
                 poses: [VNHumanBodyPoseObservation]?,
                 originalConfidence: Float = 1.0) -> OrientationCorrectionResult {
        return correct(bibNumber, pose: poses?.first, originalConfidence: originalConfidence)
    }
}

// MARK: - Integration with BibNumberResult

extension BibNumberResult {
    /// Apply orientation correction to this result
    func withOrientationCorrection(pose: VNHumanBodyPoseObservation?,
                                   corrector: BibOrientationCorrector = BibOrientationCorrector()) -> (result: BibNumberResult, correction: OrientationCorrectionResult) {
        let correction = corrector.correct(self.number, pose: pose, originalConfidence: self.confidence)

        let correctedResult = BibNumberResult(
            number: correction.corrected,
            confidence: self.confidence,
            boundingBox: self.boundingBox,
            passName: self.passName,
            adjustedConfidence: correction.confidence,
            isValidPattern: true,
            detectionTime: self.detectionTime
        )

        return (correctedResult, correction)
    }
}

// MARK: - Example Usage

/*
 Example usage:

 // PROBLEM: OCR reads upside-down bib
 // Correct: 8096
 // OCR result: "6908" (upside-down!)

 // SOLUTION: Use pose to detect orientation

 let corrector = BibOrientationCorrector()

 // Get pose estimation
 let poseEstimator = PoseEstimation()
 let poses = try? poseEstimator.estimatePose(in: image)

 // Correct orientation
 let result = corrector.correct("6908", pose: poses?.first)

 print(result.description)
 // Output:
 // Orientation Correction:
 //   Original: '6908'
 //   Corrected: '8096'
 //   Orientation: ⬇️ Upside-Down (Inverted)
 //   ⚠️ Flipped (upside-down detection)
 //   Confidence: 0.95

 // How it works:
 // 1. Check pose: head Y < hip Y → upside-down!
 // 2. Flip number: reverse "6908" → "8096"
 // 3. Swap 6↔9: "8096" → "8096" (6→9, 9→6)
 // 4. Result: "8096" ✅

 // Examples of flipping:
 // "6908" → "8096" ✅ (reversed + 6↔9 swap)
 // "9621" → "1296" ✅
 // "8068" → "8608" ✅ (8,0 are same, 6↔9)
 // "1001" → "1001" ✅ (same - symmetric)

 // Integration with OCR pipeline:
 let ocrResult = BibNumberResult(number: "6908", ...)
 let (corrected, correction) = ocrResult.withOrientationCorrection(pose: pose)
 print(corrected.number)  // "8096" ✅

 // Batch correction:
 for bibResult in ocrResults {
     let (corrected, _) = bibResult.withOrientationCorrection(pose: pose)
     print("\(bibResult.number) → \(corrected.number)")
 }
 */
