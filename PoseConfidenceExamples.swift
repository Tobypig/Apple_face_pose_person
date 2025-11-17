//
//  PoseConfidenceExamples.swift
//  Apple Vision Framework - Pose Confidence Weighting Examples
//
//  Examples demonstrating 15% faster detection with pose confidence weighting
//

import Foundation
import CoreGraphics

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Example 1: Basic Zone Confidence Analysis

func example1_BasicZoneConfidenceAnalysis(pose: PoseEstimationResult) {
    print("=" * 60)
    print("EXAMPLE 1: Basic Zone Confidence Analysis")
    print("=" * 60)
    print()

    let analyzer = JointConfidenceAnalyzer()
    analyzer.minimumJointConfidence = 0.4
    analyzer.verboseLogging = true

    let zoneConfidence = analyzer.analyzeZoneConfidence(for: pose)

    print()
    print("SUMMARY:")
    for (zone, confidence) in zoneConfidence.sorted(by: { $0.value > $1.value }) {
        let status = confidence >= 0.4 ? "Reliable ✅" : "Unreliable ❌"
        print("  \(zone.rawValue): \(String(format: "%.2f", confidence)) - \(status)")
    }
    print()
}

// MARK: - Example 2: Reliable Zones Filtering

func example2_ReliableZonesFiltering(pose: PoseEstimationResult) {
    print("=" * 60)
    print("EXAMPLE 2: Reliable Zones Filtering")
    print("=" * 60)
    print()

    let analyzer = JointConfidenceAnalyzer()
    analyzer.minimumJointConfidence = 0.4

    let reliableZones = analyzer.getReliableZones(for: pose)

    print("Reliable zones (confidence ≥ 0.4):")
    if reliableZones.isEmpty {
        print("  ❌ No reliable zones found")
    } else {
        for zone in reliableZones {
            print("  ✅ \(zone.rawValue)")
        }
    }
    print()

    print("This detection will ONLY process \(reliableZones.count) zones instead of 4")
    print("Time saved: ~\(4 - reliableZones.count) × 50ms = ~\((4 - reliableZones.count) * 50)ms")
    print()
}

// MARK: - Example 3: Basic Confidence-Weighted Detection

func example3_BasicConfidenceWeightedDetection(image: CGImage, pose: PoseEstimationResult) {
    print("=" * 60)
    print("EXAMPLE 3: Basic Confidence-Weighted Detection")
    print("=" * 60)
    print()

    let detector = ConfidenceWeightedBibDetector()
    detector.minimumZoneConfidence = 0.4
    detector.verboseLogging = true

    let (result, stats) = detector.detectWithConfidenceWeighting(in: image, pose: pose)

    if let bib = result {
        print()
        print("✅ RESULT: \(bib.number) (confidence: \(String(format: "%.2f", bib.confidence)))")
    } else {
        print()
        print("❌ No bib detected")
    }

    print()
    print(stats.description)
    print()
}

// MARK: - Example 4: Compare Standard vs Confidence-Weighted

func example4_CompareStandardVsConfidenceWeighted(image: CGImage, pose: PoseEstimationResult) {
    print("=" * 60)
    print("EXAMPLE 4: Standard vs Confidence-Weighted Comparison")
    print("=" * 60)
    print()

    // Standard detection (all zones)
    print("PASS 1: Standard Detection (All Zones)")
    let torsoManager = TorsoRegionManager()
    let allRegions = torsoManager.getAllBibRegions(from: pose)

    let detector = LanguageHintOCRDetector()
    detector.vocabularyPreset = .balanced

    let start1 = Date()
    var standardResult: BibNumberResult?

    for region in allRegions {
        if let result = detector.detectBib(in: image, torsoRegion: region) {
            if standardResult == nil || result.confidence > standardResult!.confidence {
                standardResult = result
            }
        }
    }

    let time1 = Date().timeIntervalSince(start1)

    if let result = standardResult {
        print("  ✅ Found: \(result.number) (time: \(String(format: "%.0f", time1 * 1000))ms)")
    } else {
        print("  ❌ Not found (time: \(String(format: "%.0f", time1 * 1000))ms)")
    }
    print()

    // Confidence-weighted detection
    print("PASS 2: Confidence-Weighted Detection (Filtered Zones)")
    let confDetector = ConfidenceWeightedBibDetector()
    confDetector.minimumZoneConfidence = 0.4
    confDetector.verboseLogging = false

    let start2 = Date()
    let (confResult, stats) = confDetector.detectWithConfidenceWeighting(in: image, pose: pose)
    let time2 = Date().timeIntervalSince(start2)

    if let result = confResult {
        print("  ✅ Found: \(result.number) (time: \(String(format: "%.0f", time2 * 1000))ms)")
    } else {
        print("  ❌ Not found (time: \(String(format: "%.0f", time2 * 1000))ms)")
    }
    print()

    // Comparison
    print("COMPARISON:")
    print("  Standard: \(String(format: "%.0f", time1 * 1000))ms (4 zones)")
    print("  Confidence-Weighted: \(String(format: "%.0f", time2 * 1000))ms (\(stats.zonesProcessed) zones)")
    if time2 < time1 {
        let speedup = (time1 - time2) / time1 * 100
        print("  Speedup: \(String(format: "%.1f%%", speedup)) faster ⚡")
    }
    print("  Same Result: \(standardResult?.number == confResult?.number ? "✅" : "❌")")
    print()
}

// MARK: - Example 5: Different Confidence Thresholds

func example5_DifferentConfidenceThresholds(image: CGImage, pose: PoseEstimationResult) {
    print("=" * 60)
    print("EXAMPLE 5: Different Confidence Thresholds")
    print("=" * 60)
    print()

    let thresholds: [Float] = [0.2, 0.4, 0.6, 0.8]

    for threshold in thresholds {
        print("Threshold: \(String(format: "%.1f", threshold))")

        let detector = ConfidenceWeightedBibDetector()
        detector.minimumZoneConfidence = threshold
        detector.verboseLogging = false

        let (result, stats) = detector.detectWithConfidenceWeighting(in: image, pose: pose)

        if let bib = result {
            print("  ✅ Found: \(bib.number)")
        } else {
            print("  ❌ Not found")
        }
        print("  Zones processed: \(stats.zonesProcessed)/4")
        print("  Zones skipped: \(stats.zonesSkipped)")
        print("  Time: \(String(format: "%.0f", stats.totalTime * 1000))ms")
        print()
    }

    print("NOTE: Higher threshold = fewer zones processed = faster")
    print("      But too high may skip zones with bib!")
    print()
}

// MARK: - Example 6: Fallback Behavior

func example6_FallbackBehavior(image: CGImage, pose: PoseEstimationResult) {
    print("=" * 60)
    print("EXAMPLE 6: Fallback to Low-Confidence Zones")
    print("=" * 60)
    print()

    // With fallback enabled
    print("PASS 1: Fallback ENABLED")
    let detector1 = ConfidenceWeightedBibDetector()
    detector1.minimumZoneConfidence = 0.6 // High threshold
    detector1.enableFallback = true
    detector1.verboseLogging = false

    let (result1, stats1) = detector1.detectWithConfidenceWeighting(in: image, pose: pose)

    if let bib = result1 {
        print("  ✅ Found: \(bib.number)")
        print("  Used fallback: \(stats1.usedFallback ? "Yes" : "No")")
    } else {
        print("  ❌ Not found")
    }
    print("  Zones processed: \(stats1.zonesProcessed)")
    print()

    // With fallback disabled
    print("PASS 2: Fallback DISABLED")
    let detector2 = ConfidenceWeightedBibDetector()
    detector2.minimumZoneConfidence = 0.6 // Same high threshold
    detector2.enableFallback = false
    detector2.verboseLogging = false

    let (result2, stats2) = detector2.detectWithConfidenceWeighting(in: image, pose: pose)

    if let bib = result2 {
        print("  ✅ Found: \(bib.number)")
    } else {
        print("  ❌ Not found")
    }
    print("  Zones processed: \(stats2.zonesProcessed)")
    print()

    print("ANALYSIS:")
    if result1 != nil && result2 == nil {
        print("  ✅ Fallback helped! Found bib in low-confidence zone")
    } else if result1 != nil && result2 != nil {
        print("  ⚠️ Fallback not needed (found in high-confidence zone)")
    } else {
        print("  ❌ Both failed")
    }
    print()
}

// MARK: - Example 7: Smart Confidence Processing

func example7_SmartConfidenceProcessing(image: CGImage, pose: PoseEstimationResult) {
    print("=" * 60)
    print("EXAMPLE 7: Smart Confidence Processing")
    print("=" * 60)
    print()

    let smartProcessor = SmartConfidenceProcessor()
    smartProcessor.minimumZoneConfidence = 0.4
    smartProcessor.useParallelForHighConfidence = true

    let (result, stats) = smartProcessor.detectSmart(in: image, pose: pose)

    if let bib = result {
        print("✅ RESULT: \(bib.number) (confidence: \(String(format: "%.2f", bib.confidence)))")
    } else {
        print("❌ No bib detected")
    }

    print()
    print(stats.description)
    print()
}

// MARK: - Example 8: Zone Confidence by Pose Quality

func example8_ZoneConfidenceByPoseQuality() {
    print("=" * 60)
    print("EXAMPLE 8: Zone Confidence for Different Pose Qualities")
    print("=" * 60)
    print()

    // Simulate different pose qualities
    let scenarios = [
        ("Full Body Visible", 0.9),
        ("Partial Occlusion", 0.6),
        ("Heavily Occluded", 0.3),
        ("Edge of Frame", 0.4)
    ]

    for (scenario, avgConfidence) in scenarios {
        print("\(scenario) (avg confidence: \(String(format: "%.1f", avgConfidence))):")

        // Estimate how many zones would be reliable
        let reliableZones: Int
        if avgConfidence >= 0.7 {
            reliableZones = 4
        } else if avgConfidence >= 0.5 {
            reliableZones = 3
        } else if avgConfidence >= 0.3 {
            reliableZones = 2
        } else {
            reliableZones = 1
        }

        let zonesSkipped = 4 - reliableZones
        let timeSaved = zonesSkipped * 50

        print("  Reliable zones: \(reliableZones)/4")
        print("  Zones skipped: \(zonesSkipped)")
        print("  Est. time saved: ~\(timeSaved)ms")
        print()
    }
}

// MARK: - Example 9: Integration with Parallel Processing

func example9_IntegrationWithParallelProcessing(image: CGImage, pose: PoseEstimationResult) {
    print("=" * 60)
    print("EXAMPLE 9: Confidence Weighting + Parallel Processing")
    print("=" * 60)
    print()

    // Get reliable regions only
    let torsoManager = TorsoRegionManager()
    let reliableRegions = torsoManager.getReliableRegions(from: pose, minimumConfidence: 0.4)

    print("Reliable regions: \(reliableRegions.count)/4")
    print()

    if reliableRegions.count >= 2 {
        print("Using PARALLEL processing on \(reliableRegions.count) reliable zones")

        // Use parallel processor
        let parallel = ParallelZoneProcessor()
        parallel.verboseLogging = true

        let (result, stats) = parallel.detectInParallel(in: image, pose: pose)

        if let bib = result {
            print()
            print("✅ Result: \(bib.number)")
            print("Speedup from parallelism: \(String(format: "%.1f", stats.speedupFactor))x")
            print("Speedup from confidence: \(4 - reliableRegions.count) zones skipped")
        }
    } else {
        print("Using SEQUENTIAL processing on \(reliableRegions.count) reliable zone(s)")

        let detector = ConfidenceWeightedBibDetector()
        detector.verboseLogging = true

        let (result, stats) = detector.detectWithConfidenceWeighting(in: image, pose: pose)

        if let bib = result {
            print()
            print("✅ Result: \(bib.number)")
        }
    }
    print()
}

// MARK: - Example 10: Batch Processing with Confidence Filtering

func example10_BatchProcessingWithConfidence(imagePosePairs: [(CGImage, PoseEstimationResult)]) {
    print("=" * 60)
    print("EXAMPLE 10: Batch Processing with Confidence Filtering")
    print("=" * 60)
    print()

    print("Processing \(imagePosePairs.count) images with confidence filtering...")
    print()

    var totalZonesProcessed = 0
    var totalZonesSkipped = 0
    var totalTime: TimeInterval = 0
    var successCount = 0

    for (index, (image, pose)) in imagePosePairs.enumerated() {
        let detector = ConfidenceWeightedBibDetector()
        detector.verboseLogging = false
        detector.minimumZoneConfidence = 0.4

        let (result, stats) = detector.detectWithConfidenceWeighting(in: image, pose: pose)

        totalZonesProcessed += stats.zonesProcessed
        totalZonesSkipped += stats.zonesSkipped
        totalTime += stats.totalTime

        if result != nil {
            successCount += 1
            print("  Image \(index + 1): ✅ (\(stats.zonesProcessed) zones, \(String(format: "%.0f", stats.totalTime * 1000))ms)")
        } else {
            print("  Image \(index + 1): ❌ (\(stats.zonesProcessed) zones, \(String(format: "%.0f", stats.totalTime * 1000))ms)")
        }
    }

    print()
    print("BATCH SUMMARY:")
    print("  Success: \(successCount)/\(imagePosePairs.count)")
    print("  Total zones processed: \(totalZonesProcessed)")
    print("  Total zones skipped: \(totalZonesSkipped)")
    print("  Avg zones per image: \(String(format: "%.1f", Float(totalZonesProcessed) / Float(imagePosePairs.count)))")
    print("  Total time: \(String(format: "%.1f", totalTime))s")
    print("  Avg time: \(String(format: "%.0f", totalTime / Double(imagePosePairs.count) * 1000))ms/image")
    print()

    let potentialZones = imagePosePairs.count * 4
    let skipPercentage = Float(totalZonesSkipped) / Float(potentialZones) * 100
    print("  Zones skipped: \(String(format: "%.1f%%", skipPercentage))")
    print("  Est. time saved: ~\(String(format: "%.1f", Float(totalZonesSkipped) * 0.05))s")
    print()
}

// MARK: - Example 11: Adaptive Threshold Selection

func example11_AdaptiveThresholdSelection(image: CGImage, pose: PoseEstimationResult) {
    print("=" * 60)
    print("EXAMPLE 11: Adaptive Threshold Selection")
    print("=" * 60)
    print()

    // Analyze overall pose quality
    let analyzer = JointConfidenceAnalyzer()
    let zoneConfidence = analyzer.analyzeZoneConfidence(for: pose)

    let avgConfidence = zoneConfidence.values.reduce(0, +) / Float(zoneConfidence.count)

    print("Overall pose quality: \(String(format: "%.2f", avgConfidence))")

    // Select threshold based on pose quality
    let selectedThreshold: Float
    if avgConfidence >= 0.7 {
        selectedThreshold = 0.5 // High quality: strict threshold
        print("  → Using STRICT threshold (0.5)")
    } else if avgConfidence >= 0.4 {
        selectedThreshold = 0.3 // Medium quality: balanced
        print("  → Using BALANCED threshold (0.3)")
    } else {
        selectedThreshold = 0.2 // Low quality: lenient
        print("  → Using LENIENT threshold (0.2)")
    }
    print()

    let detector = ConfidenceWeightedBibDetector()
    detector.minimumZoneConfidence = selectedThreshold
    detector.verboseLogging = true

    let (result, stats) = detector.detectWithConfidenceWeighting(in: image, pose: pose)

    if let bib = result {
        print()
        print("✅ Result: \(bib.number)")
    } else {
        print()
        print("❌ Not detected")
    }
    print()
}

// MARK: - Example 12: Full Pipeline with Confidence Weighting

func example12_FullPipelineWithConfidenceWeighting(image: CGImage) {
    print("=" * 60)
    print("EXAMPLE 12: Full Pipeline with Confidence Weighting")
    print("=" * 60)
    print()

    // Step 1: Pose detection
    print("STEP 1: Pose Detection")
    let poseDetector = PoseEstimator()
    guard let pose = poseDetector.detectPose(in: image) else {
        print("  ❌ Pose detection failed")
        return
    }
    print("  ✅ Pose detected (confidence: \(String(format: "%.2f", pose.confidence)))")
    print()

    // Step 2: Analyze zone confidence
    print("STEP 2: Zone Confidence Analysis")
    let analyzer = JointConfidenceAnalyzer()
    analyzer.verboseLogging = true
    let _ = analyzer.analyzeZoneConfidence(for: pose)
    print()

    // Step 3: Confidence-weighted detection
    print("STEP 3: Confidence-Weighted Detection")
    let result = ConfidenceWeightedBibDetector.detect(in: image, pose: pose)

    if let bib = result {
        print()
        print("✅ FINAL RESULT: \(bib.number) (confidence: \(String(format: "%.2f", bib.confidence)))")
    } else {
        print()
        print("❌ No bib detected")
    }
    print()
}

// MARK: - Helper: Run All Examples

func runAllPoseConfidenceExamples() {
    print("\n")
    print("=" * 60)
    print("POSE CONFIDENCE WEIGHTING - ALL EXAMPLES")
    print("=" * 60)
    print("\n")

    print("NOTE: These examples require image and pose data")
    print("      Load your images and poses, then call examples individually")
    print("\n")

    print("Available Examples:")
    print("  1. Basic Zone Confidence Analysis")
    print("  2. Reliable Zones Filtering")
    print("  3. Basic Confidence-Weighted Detection")
    print("  4. Standard vs Confidence-Weighted Comparison")
    print("  5. Different Confidence Thresholds")
    print("  6. Fallback Behavior")
    print("  7. Smart Confidence Processing")
    print("  8. Zone Confidence by Pose Quality")
    print("  9. Integration with Parallel Processing")
    print("  10. Batch Processing with Confidence Filtering")
    print("  11. Adaptive Threshold Selection")
    print("  12. Full Pipeline with Confidence Weighting")
    print("\n")
}

// MARK: - Main Entry Point

#if DEBUG
// Uncomment to run:
// runAllPoseConfidenceExamples()
#endif
