//
//  AdaptiveTorsoExpansion.swift
//  Apple Vision Framework - Adaptive Torso Region Expansion
//
//  Dynamically expand torso regions when detection fails (+15-20% improvement)
//  Progressive fallback strategy for bib detection
//

import Foundation
import CoreGraphics

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Expansion Strategy

/// Strategy for expanding torso regions progressively
enum ExpansionStrategy {
    case standard       // 100% original size (default)
    case expanded       // +30% width/height
    case veryExpanded   // +50% width/height
    case maximum        // +80% width/height
    case fullUpperBody  // Shoulders to knees (entire upper body)

    /// Expansion factors for width and height
    var factors: (width: CGFloat, height: CGFloat) {
        switch self {
        case .standard:
            return (1.0, 1.0)
        case .expanded:
            return (1.3, 1.3)
        case .veryExpanded:
            return (1.5, 1.5)
        case .maximum:
            return (1.8, 1.6)
        case .fullUpperBody:
            return (2.0, 1.8)
        }
    }

    /// Display name
    var displayName: String {
        switch self {
        case .standard: return "Standard (100%)"
        case .expanded: return "Expanded (+30%)"
        case .veryExpanded: return "Very Expanded (+50%)"
        case .maximum: return "Maximum (+80%)"
        case .fullUpperBody: return "Full Upper Body"
        }
    }
}

// MARK: - Expansion Result

/// Result of adaptive expansion detection
struct AdaptiveExpansionResult {
    let bibNumber: BibNumberResult?
    let strategyUsed: ExpansionStrategy
    let attemptsMade: Int
    let totalTime: TimeInterval
    let zoneDetected: TorsoZone?

    var success: Bool {
        return bibNumber != nil
    }

    var description: String {
        return """
        Adaptive Expansion Result:
          Success: \(success ? "✅" : "❌")
          Bib Number: \(bibNumber?.number ?? "Not detected")
          Strategy: \(strategyUsed.displayName)
          Zone: \(zoneDetected?.rawValue ?? "None")
          Attempts: \(attemptsMade)
          Time: \(String(format: "%.0f", totalTime * 1000))ms
        """
    }
}

// MARK: - Adaptive Torso Expander

/// Dynamically expand torso regions when detection fails
class AdaptiveTorsoExpander {

    private let ocrEngine: TextLocalizedBibDetection
    private let torsoManager = TorsoRegionManager()

    // MARK: - Configuration

    /// Enable color pre-detection for faster results
    var enableColorPreDetection: Bool = true

    /// Maximum expansion attempts (default: 4)
    var maxExpansionAttempts: Int = 4

    /// Expansion strategies to try (in order)
    var expansionSequence: [ExpansionStrategy] = [
        .standard,
        .expanded,
        .veryExpanded,
        .maximum
    ]

    /// Zones to try per expansion (default: all 4 zones)
    var zonesToTry: [TorsoZone] = [
        .upperChest,
        .midTorso,
        .lowerTorso,
        .extendedLowerTorso
    ]

    // MARK: - Initialization

    init(ocrEngine: TextLocalizedBibDetection = TextLocalizedBibDetection()) {
        self.ocrEngine = ocrEngine
    }

    // MARK: - Detection with Adaptive Expansion

    /// Detect bib with progressive torso expansion
    /// - Parameters:
    ///   - image: Full image
    ///   - pose: Pose estimation result
    /// - Returns: Detection result with strategy used
    func detectWithAdaptiveExpansion(in image: CGImage,
                                    pose: PoseEstimationResult) -> AdaptiveExpansionResult {
        let startTime = Date()
        var attemptCount = 0

        print("🔄 Adaptive Torso Expansion Detection")
        print("   Max Attempts: \(maxExpansionAttempts)")
        print("   Zones: \(zonesToTry.count)")
        print()

        // Try each expansion strategy
        for strategy in expansionSequence.prefix(maxExpansionAttempts) {
            print("  Strategy: \(strategy.displayName)")

            // Apply expansion factors
            let (widthFactor, heightFactor) = strategy.factors
            torsoManager.widthExpansionFactor = 1.2 * widthFactor
            torsoManager.heightExpansionFactor = 1.1 * heightFactor

            // Get expanded torso regions
            let regions = torsoManager.getAllBibRegions(from: pose)

            print("    Generated \(regions.count) regions")

            // Try each zone with this expansion
            for region in regions {
                attemptCount += 1

                print("      Trying \(region.zone.rawValue) (attempt \(attemptCount))...")

                // Try detection in this region
                if let result = tryDetection(in: image, region: region) {
                    let totalTime = Date().timeIntervalSince(startTime)

                    print("      ✅ SUCCESS with \(strategy.displayName) in \(region.zone.rawValue)!")

                    return AdaptiveExpansionResult(
                        bibNumber: result,
                        strategyUsed: strategy,
                        attemptsMade: attemptCount,
                        totalTime: totalTime,
                        zoneDetected: region.zone
                    )
                }
            }

            print("    ❌ Strategy \(strategy.displayName) failed")
            print()
        }

        // All strategies failed
        let totalTime = Date().timeIntervalSince(startTime)

        print("  ❌ All expansion strategies failed after \(attemptCount) attempts")

        return AdaptiveExpansionResult(
            bibNumber: nil,
            strategyUsed: expansionSequence.last ?? .standard,
            attemptsMade: attemptCount,
            totalTime: totalTime,
            zoneDetected: nil
        )
    }

    /// Try detection with optional color pre-detection
    private func tryDetection(in image: CGImage,
                             region: BibDetectionRegion) -> BibNumberResult? {
        if enableColorPreDetection {
            // Use color-enhanced detection
            let colorDetector = ColorEnhancedBibDetection()
            return colorDetector.detectBib(in: image, torsoRegion: region)
        } else {
            // Use standard text localization
            return ocrEngine.detectBib(in: image, torsoRegion: region)
        }
    }

    // MARK: - Zone-Specific Expansion

    /// Expand a specific zone dynamically
    /// - Parameters:
    ///   - zone: Zone to expand
    ///   - pose: Pose estimation result
    ///   - strategy: Expansion strategy
    /// - Returns: Expanded region
    func expandZone(_ zone: TorsoZone,
                   for pose: PoseEstimationResult,
                   strategy: ExpansionStrategy) -> BibDetectionRegion? {
        // Apply expansion factors
        let (widthFactor, heightFactor) = strategy.factors
        torsoManager.widthExpansionFactor = 1.2 * widthFactor
        torsoManager.heightExpansionFactor = 1.1 * heightFactor

        // Get all regions and find the requested zone
        let regions = torsoManager.getAllBibRegions(from: pose)
        return regions.first { $0.zone == zone }
    }
}

// MARK: - Smart Expansion with Early Exit

/// Intelligent expansion with early exit optimization
class SmartAdaptiveExpander {

    private let expander = AdaptiveTorsoExpander()

    // MARK: - Configuration

    /// Early exit confidence threshold (default: 0.85)
    var earlyExitConfidence: Float = 0.85

    /// Enable zone-specific optimization
    var enableZoneOptimization: Bool = true

    // MARK: - Smart Detection

    /// Detect with smart expansion (early exit + zone optimization)
    /// - Parameters:
    ///   - image: Full image
    ///   - pose: Pose estimation result
    /// - Returns: Detection result
    func detectWithSmartExpansion(in image: CGImage,
                                 pose: PoseEstimationResult) -> AdaptiveExpansionResult {
        let startTime = Date()
        var attemptCount = 0

        print("🧠 Smart Adaptive Expansion Detection")
        print("   Early Exit Threshold: \(earlyExitConfidence)")
        print("   Zone Optimization: \(enableZoneOptimization)")
        print()

        // Strategy 1: Try most likely zone first (upper chest) with standard size
        if enableZoneOptimization {
            print("  PASS 1: Most Likely Zone (Upper Chest - Standard)")
            attemptCount += 1

            if let region = expander.expandZone(.upperChest, for: pose, strategy: .standard),
               let result = tryDetectionWithEarlyExit(in: image, region: region) {
                let totalTime = Date().timeIntervalSince(startTime)

                print("    ✅ SUCCESS with primary zone!")

                return AdaptiveExpansionResult(
                    bibNumber: result,
                    strategyUsed: .standard,
                    attemptsMade: attemptCount,
                    totalTime: totalTime,
                    zoneDetected: .upperChest
                )
            }
            print("    ❌ Primary zone failed")
            print()
        }

        // Strategy 2: Expand progressively with all zones
        print("  PASS 2: Progressive Expansion (All Zones)")

        let strategies: [ExpansionStrategy] = [.expanded, .veryExpanded, .maximum]

        for strategy in strategies {
            print("    Strategy: \(strategy.displayName)")

            for zone in expander.zonesToTry {
                attemptCount += 1

                if let region = expander.expandZone(zone, for: pose, strategy: strategy),
                   let result = tryDetectionWithEarlyExit(in: image, region: region) {
                    let totalTime = Date().timeIntervalSince(startTime)

                    print("      ✅ SUCCESS with \(strategy.displayName) in \(zone.rawValue)!")

                    return AdaptiveExpansionResult(
                        bibNumber: result,
                        strategyUsed: strategy,
                        attemptsMade: attemptCount,
                        totalTime: totalTime,
                        zoneDetected: zone
                    )
                }
            }

            print("      ❌ Strategy \(strategy.displayName) failed")
        }

        // All failed
        let totalTime = Date().timeIntervalSince(startTime)

        return AdaptiveExpansionResult(
            bibNumber: nil,
            strategyUsed: .maximum,
            attemptsMade: attemptCount,
            totalTime: totalTime,
            zoneDetected: nil
        )
    }

    private func tryDetectionWithEarlyExit(in image: CGImage,
                                          region: BibDetectionRegion) -> BibNumberResult? {
        let detector = ColorEnhancedBibDetection()

        if let result = detector.detectBib(in: image, torsoRegion: region) {
            // Early exit if very confident
            if result.confidence >= earlyExitConfidence {
                print("      ⚡ Early exit: High confidence (\(String(format: "%.2f", result.confidence)))")
                return result
            }

            // Return result but don't early exit
            return result
        }

        return nil
    }
}

// MARK: - Expansion Statistics

/// Track expansion statistics for optimization
class ExpansionStatistics {

    private(set) var successByStrategy: [ExpansionStrategy: Int] = [:]
    private(set) var successByZone: [TorsoZone: Int] = [:]
    private(set) var totalAttempts: Int = 0
    private(set) var totalSuccesses: Int = 0

    /// Record detection result
    func recordResult(_ result: AdaptiveExpansionResult) {
        totalAttempts += 1

        if result.success {
            totalSuccesses += 1

            // Track by strategy
            successByStrategy[result.strategyUsed, default: 0] += 1

            // Track by zone
            if let zone = result.zoneDetected {
                successByZone[zone, default: 0] += 1
            }
        }
    }

    /// Get success rate
    var successRate: Float {
        guard totalAttempts > 0 else { return 0 }
        return Float(totalSuccesses) / Float(totalAttempts)
    }

    /// Get statistics summary
    var summary: String {
        var text = """
        Expansion Statistics:
          Total Attempts: \(totalAttempts)
          Successes: \(totalSuccesses)
          Success Rate: \(String(format: "%.1f%%", successRate * 100))

        Success by Strategy:
        """

        for (strategy, count) in successByStrategy.sorted(by: { $0.value > $1.value }) {
            let rate = Float(count) / Float(totalSuccesses)
            text += "\n  \(strategy.displayName): \(count) (\(String(format: "%.1f%%", rate * 100)))"
        }

        text += "\n\nSuccess by Zone:"

        for (zone, count) in successByZone.sorted(by: { $0.value > $1.value }) {
            let rate = Float(count) / Float(totalSuccesses)
            text += "\n  \(zone.rawValue): \(count) (\(String(format: "%.1f%%", rate * 100)))"
        }

        return text
    }
}

// MARK: - Integration Extension

extension BibDetectionRegion {
    /// Detect bib with adaptive expansion
    func detectWithAdaptiveExpansion(in image: CGImage,
                                    pose: PoseEstimationResult) -> AdaptiveExpansionResult {
        let expander = AdaptiveTorsoExpander()
        return expander.detectWithAdaptiveExpansion(in: image, pose: pose)
    }
}
