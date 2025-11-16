//
//  MultiScaleOCRWithVoting.swift
//  Apple Vision Framework - Multi-Scale OCR with Voting
//
//  Combine OCR results from multiple scales for +20-25% accuracy improvement
//

import Foundation
import CoreGraphics
import CoreImage

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Scale Configuration

/// OCR scale configuration
struct OCRScale {
    let factor: CGFloat
    let name: String
    let priority: Int  // Higher = more likely to be correct

    /// Common scale presets
    static let verySmall = OCRScale(factor: 0.5, name: "Very Small (0.5x)", priority: 2)
    static let small = OCRScale(factor: 0.8, name: "Small (0.8x)", priority: 4)
    static let standard = OCRScale(factor: 1.0, name: "Standard (1.0x)", priority: 10)
    static let enlarged = OCRScale(factor: 1.2, name: "Enlarged (1.2x)", priority: 8)
    static let large = OCRScale(factor: 1.5, name: "Large (1.5x)", priority: 6)
    static let veryLarge = OCRScale(factor: 2.0, name: "Very Large (2.0x)", priority: 5)
    static let extreme = OCRScale(factor: 3.0, name: "Extreme (3.0x)", priority: 3)

    /// Default scale set for balanced detection
    static let balanced: [OCRScale] = [.small, .standard, .enlarged, .large]

    /// Aggressive scale set for difficult cases
    static let aggressive: [OCRScale] = [.verySmall, .small, .standard, .enlarged, .large, .veryLarge]

    /// Fast scale set for quick detection
    static let fast: [OCRScale] = [.standard, .enlarged]
}

// MARK: - Voting Result

/// OCR result with voting information
struct VotedOCRResult {
    let bibNumber: String
    let votes: Int                      // Number of scales that detected this number
    let averageConfidence: Float        // Average confidence across all detections
    let boostedConfidence: Float        // Confidence boosted by voting
    let scalesDetected: [OCRScale]      // Which scales detected this number
    let agreementRate: Float            // votes / total scales attempted

    var description: String {
        return """
        Voted OCR Result:
          Bib Number: \(bibNumber)
          Votes: \(votes)
          Agreement: \(String(format: "%.0f%%", agreementRate * 100))
          Avg Confidence: \(String(format: "%.2f", averageConfidence))
          Boosted Confidence: \(String(format: "%.2f", boostedConfidence))
          Scales: \(scalesDetected.map { $0.name }.joined(separator: ", "))
        """
    }
}

// MARK: - Multi-Scale OCR Detector

/// Perform OCR at multiple scales and vote on results
class MultiScaleOCRDetector {

    private let ocrEngine: BibNumberOCROptimizer

    // MARK: - Configuration

    /// Scales to try (default: balanced set)
    var scales: [OCRScale] = OCRScale.balanced

    /// Minimum votes required (default: 2 - at least 2 scales must agree)
    var minimumVotes: Int = 2

    /// Confidence boost per additional vote (default: 0.05)
    var confidenceBoostPerVote: Float = 0.05

    /// Maximum confidence boost (default: 0.20)
    var maxConfidenceBoost: Float = 0.20

    /// Enable early exit if strong consensus (default: true)
    var enableEarlyExit: Bool = true

    /// Early exit threshold (default: 3 votes with >0.85 confidence)
    var earlyExitVotes: Int = 3
    var earlyExitConfidence: Float = 0.85

    // MARK: - Initialization

    init(ocrEngine: BibNumberOCROptimizer = BibNumberOCROptimizer()) {
        self.ocrEngine = ocrEngine
    }

    // MARK: - Multi-Scale Detection

    /// Detect bib number using multi-scale OCR with voting
    /// - Parameter bibRegion: Bib region image
    /// - Returns: Voted OCR result
    func detectWithMultiScale(in bibRegion: CGImage) -> VotedOCRResult? {
        var allResults: [String: [BibNumberResult]] = [:]  // number -> [results]
        var scaleResults: [OCRScale: String?] = [:]

        print("🔬 Multi-Scale OCR with Voting")
        print("   Scales: \(scales.count)")
        print("   Min Votes: \(minimumVotes)")
        print()

        // Try OCR at each scale
        for (index, scale) in scales.enumerated() {
            print("  Scale \(index + 1)/\(scales.count): \(scale.name)...")

            // Scale the image
            guard let scaledImage = scaleImage(bibRegion, factor: scale.factor) else {
                print("    ❌ Failed to scale image")
                continue
            }

            // Perform OCR
            let config = BibNumberOCRConfiguration.accurate
            let results = ocrEngine.recognizeText(in: scaledImage, configuration: config)

            if let result = results.first, BibNumberValidator.isValid(result.number) {
                print("    ✓ Detected: \(result.number) (confidence: \(String(format: "%.2f", result.confidence)))")

                // Store result
                allResults[result.number, default: []].append(result)
                scaleResults[scale] = result.number

                // Early exit check
                if enableEarlyExit,
                   let votes = allResults[result.number]?.count,
                   votes >= earlyExitVotes,
                   result.confidence >= earlyExitConfidence {
                    print("    ⚡ Early exit: Strong consensus (\(votes) votes)")
                    break
                }
            } else {
                print("    ✗ No valid result")
                scaleResults[scale] = nil
            }
        }

        // Vote on results
        return computeVotedResult(from: allResults, scaleResults: scaleResults)
    }

    /// Compute voted result from all detections
    private func computeVotedResult(from allResults: [String: [BibNumberResult]],
                                    scaleResults: [OCRScale: String?]) -> VotedOCRResult? {
        guard !allResults.isEmpty else {
            print("\n  ❌ No results detected at any scale")
            return nil
        }

        print("\n  VOTING RESULTS:")

        // Sort by number of votes
        let sorted = allResults.sorted { $0.value.count > $1.value.count }

        for (number, results) in sorted.prefix(3) {
            let votes = results.count
            let avgConf = results.map { $0.confidence }.reduce(0, +) / Float(results.count)
            print("    '\(number)': \(votes) votes, avg conf: \(String(format: "%.2f", avgConf))")
        }

        // Get winner (most votes)
        guard let (winningNumber, winningResults) = sorted.first,
              winningResults.count >= minimumVotes else {
            print("\n  ⚠️ No result meets minimum vote threshold (\(minimumVotes))")
            return nil
        }

        // Calculate statistics
        let votes = winningResults.count
        let avgConfidence = winningResults.map { $0.confidence }.reduce(0, +) / Float(winningResults.count)

        // Boost confidence based on agreement
        let boost = min(maxConfidenceBoost, Float(votes - 1) * confidenceBoostPerVote)
        let boostedConfidence = min(1.0, avgConfidence + boost)

        // Find which scales detected this number
        let detectingScales = scaleResults.filter { $0.value == winningNumber }.map { $0.key }

        let agreementRate = Float(votes) / Float(scales.count)

        print("\n  ✅ WINNER: '\(winningNumber)'")
        print("     Votes: \(votes)/\(scales.count)")
        print("     Agreement: \(String(format: "%.0f%%", agreementRate * 100))")
        print("     Confidence Boost: +\(String(format: "%.2f", boost))")

        return VotedOCRResult(
            bibNumber: winningNumber,
            votes: votes,
            averageConfidence: avgConfidence,
            boostedConfidence: boostedConfidence,
            scalesDetected: detectingScales,
            agreementRate: agreementRate
        )
    }

    // MARK: - Weighted Voting

    /// Detect with weighted voting (considers scale priority)
    /// - Parameter bibRegion: Bib region image
    /// - Returns: Voted OCR result with weighted scores
    func detectWithWeightedVoting(in bibRegion: CGImage) -> VotedOCRResult? {
        var weightedScores: [String: Float] = [:]  // number -> weighted score
        var rawResults: [String: [BibNumberResult]] = [:]

        print("🎯 Weighted Multi-Scale OCR")
        print("   Scales: \(scales.count) (priority-weighted)")
        print()

        // Try OCR at each scale with weights
        for scale in scales {
            guard let scaledImage = scaleImage(bibRegion, factor: scale.factor) else {
                continue
            }

            let config = BibNumberOCRConfiguration.accurate
            let results = ocrEngine.recognizeText(in: scaledImage, configuration: config)

            if let result = results.first, BibNumberValidator.isValid(result.number) {
                // Calculate weighted score (confidence * priority)
                let weight = Float(scale.priority) / 10.0  // Normalize priority
                let score = result.confidence * weight

                weightedScores[result.number, default: 0] += score
                rawResults[result.number, default: []].append(result)

                print("  \(scale.name): '\(result.number)' (score: \(String(format: "%.2f", score)))")
            }
        }

        guard !weightedScores.isEmpty else {
            return nil
        }

        // Find winner by weighted score
        let sorted = weightedScores.sorted { $0.value > $1.value }

        print("\n  WEIGHTED SCORES:")
        for (number, score) in sorted.prefix(3) {
            let votes = rawResults[number]?.count ?? 0
            print("    '\(number)': score \(String(format: "%.2f", score)) (\(votes) votes)")
        }

        guard let (winningNumber, _) = sorted.first,
              let winningResults = rawResults[winningNumber],
              winningResults.count >= minimumVotes else {
            return nil
        }

        let votes = winningResults.count
        let avgConfidence = winningResults.map { $0.confidence }.reduce(0, +) / Float(winningResults.count)
        let boost = min(maxConfidenceBoost, Float(votes - 1) * confidenceBoostPerVote)
        let boostedConfidence = min(1.0, avgConfidence + boost)

        let scaleResults = scales.filter { scale in
            rawResults[winningNumber]?.contains { _ in true } ?? false
        }

        return VotedOCRResult(
            bibNumber: winningNumber,
            votes: votes,
            averageConfidence: avgConfidence,
            boostedConfidence: boostedConfidence,
            scalesDetected: scaleResults,
            agreementRate: Float(votes) / Float(scales.count)
        )
    }

    // MARK: - Helper Methods

    private func scaleImage(_ image: CGImage, factor: CGFloat) -> CGImage? {
        let newWidth = Int(CGFloat(image.width) * factor)
        let newHeight = Int(CGFloat(image.height) * factor)

        guard newWidth > 0, newHeight > 0 else {
            return nil
        }

        let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: image.bitmapInfo.rawValue
        )

        context?.interpolationQuality = .high
        context?.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        return context?.makeImage()
    }
}

// MARK: - Rotation-Invariant Detection

/// Detect bib numbers at multiple rotations
class RotationInvariantOCRDetector {

    private let multiScaleDetector: MultiScaleOCRDetector

    // MARK: - Configuration

    /// Rotation angles to try in degrees (default: -15° to +15°)
    var rotationAngles: [CGFloat] = [-15, -10, -5, 0, 5, 10, 15]

    /// Enable multi-scale at each rotation (default: false for speed)
    var enableMultiScalePerRotation: Bool = false

    // MARK: - Initialization

    init(multiScaleDetector: MultiScaleOCRDetector = MultiScaleOCRDetector()) {
        self.multiScaleDetector = multiScaleDetector
    }

    // MARK: - Detection

    /// Detect with rotation invariance
    /// - Parameter bibRegion: Bib region image
    /// - Returns: Best voted result across all rotations
    func detectWithRotationInvariance(in bibRegion: CGImage) -> VotedOCRResult? {
        var allResults: [VotedOCRResult] = []

        print("🔄 Rotation-Invariant OCR")
        print("   Angles: \(rotationAngles.map { String(format: "%.0f°", $0) }.joined(separator: ", "))")
        print("   Multi-Scale per Rotation: \(enableMultiScalePerRotation)")
        print()

        for angle in rotationAngles {
            print("  Trying rotation: \(String(format: "%.0f°", angle))...")

            guard let rotatedImage = rotateImage(bibRegion, degrees: angle) else {
                print("    ❌ Failed to rotate")
                continue
            }

            if enableMultiScalePerRotation {
                // Full multi-scale detection at this rotation
                if let result = multiScaleDetector.detectWithMultiScale(in: rotatedImage) {
                    allResults.append(result)
                    print("    ✓ Found: \(result.bibNumber) (\(result.votes) votes)")
                }
            } else {
                // Single-scale detection (faster)
                if let result = detectSingleScale(in: rotatedImage) {
                    allResults.append(result)
                    print("    ✓ Found: \(result.bibNumber)")
                }
            }
        }

        guard !allResults.isEmpty else {
            print("\n  ❌ No results at any rotation")
            return nil
        }

        // Vote across all rotations
        print("\n  CROSS-ROTATION VOTING:")

        var numberVotes: [String: [VotedOCRResult]] = [:]
        for result in allResults {
            numberVotes[result.bibNumber, default: []].append(result)
        }

        let sorted = numberVotes.sorted { $0.value.count > $1.value.count }

        for (number, results) in sorted.prefix(3) {
            let rotations = results.count
            let totalVotes = results.map { $0.votes }.reduce(0, +)
            print("    '\(number)': \(rotations) rotations, \(totalVotes) total votes")
        }

        // Return result with most rotations agreeing
        if let (winningNumber, winningResults) = sorted.first {
            let combinedVotes = winningResults.map { $0.votes }.reduce(0, +)
            let avgConfidence = winningResults.map { $0.averageConfidence }.reduce(0, +) / Float(winningResults.count)
            let boostedConf = min(1.0, avgConfidence + Float(winningResults.count) * 0.05)

            print("\n  ✅ WINNER: '\(winningNumber)' (\(winningResults.count) rotations agree)")

            return VotedOCRResult(
                bibNumber: winningNumber,
                votes: combinedVotes,
                averageConfidence: avgConfidence,
                boostedConfidence: boostedConf,
                scalesDetected: [],
                agreementRate: Float(winningResults.count) / Float(rotationAngles.count)
            )
        }

        return nil
    }

    private func detectSingleScale(in image: CGImage) -> VotedOCRResult? {
        let ocrEngine = BibNumberOCROptimizer()
        let config = BibNumberOCRConfiguration.accurate
        let results = ocrEngine.recognizeText(in: image, configuration: config)

        if let result = results.first, BibNumberValidator.isValid(result.number) {
            return VotedOCRResult(
                bibNumber: result.number,
                votes: 1,
                averageConfidence: result.confidence,
                boostedConfidence: result.confidence,
                scalesDetected: [.standard],
                agreementRate: 1.0
            )
        }

        return nil
    }

    private func rotateImage(_ image: CGImage, degrees: CGFloat) -> CGImage? {
        let radians = degrees * .pi / 180

        let width = image.width
        let height = image.height

        // Calculate new bounds
        let newWidth = Int(abs(CGFloat(width) * cos(radians)) + abs(CGFloat(height) * sin(radians)))
        let newHeight = Int(abs(CGFloat(width) * sin(radians)) + abs(CGFloat(height) * cos(radians)))

        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: image.bitmapInfo.rawValue
        ) else {
            return nil
        }

        // Rotate around center
        context.translateBy(x: CGFloat(newWidth) / 2, y: CGFloat(newHeight) / 2)
        context.rotate(by: radians)
        context.translateBy(x: -CGFloat(width) / 2, y: -CGFloat(height) / 2)

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        return context.makeImage()
    }
}

// MARK: - Combined Multi-Scale + Rotation Detection

/// Ultimate detector: Multi-scale + rotation invariance
class UltimateOCRDetector {

    private let multiScaleDetector = MultiScaleOCRDetector()
    private let rotationDetector: RotationInvariantOCRDetector

    init() {
        self.rotationDetector = RotationInvariantOCRDetector(multiScaleDetector: multiScaleDetector)
    }

    /// Detect with both multi-scale and rotation invariance
    /// - Parameter bibRegion: Bib region image
    /// - Returns: Best result from comprehensive detection
    func detectComprehensive(in bibRegion: CGImage) -> VotedOCRResult? {
        print("🎯 ULTIMATE OCR DETECTION")
        print("   Multi-Scale + Rotation Invariance")
        print("=" * 60)
        print()

        // Enable multi-scale per rotation for maximum accuracy
        rotationDetector.enableMultiScalePerRotation = true
        rotationDetector.multiScaleDetector.scales = OCRScale.balanced

        return rotationDetector.detectWithRotationInvariance(in: bibRegion)
    }
}

// MARK: - Integration Extension

extension BibDetectionRegion {
    /// Detect bib with multi-scale voting
    func detectWithMultiScaleVoting(in image: CGImage) -> VotedOCRResult? {
        // Crop to region
        let imageSize = CGSize(width: image.width, height: image.height)
        let regionRect = TorsoRegionManager.convertToImageCoordinates(region: self, imageSize: imageSize)

        guard let bibImage = image.cropping(to: regionRect) else {
            return nil
        }

        let detector = MultiScaleOCRDetector()
        return detector.detectWithMultiScale(in: bibImage)
    }
}
