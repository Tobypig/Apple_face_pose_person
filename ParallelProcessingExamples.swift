//
//  ParallelProcessingExamples.swift
//  Apple Vision Framework - Parallel Zone Processing Examples
//
//  Examples demonstrating 3-4x faster detection with parallel processing
//

import Foundation
import CoreGraphics

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Example 1: Basic Parallel Processing

func example1_BasicParallelProcessing(image: CGImage, pose: PoseEstimationResult) {
    print("=" * 60)
    print("EXAMPLE 1: Basic Parallel Zone Processing")
    print("=" * 60)
    print()

    let processor = ParallelZoneProcessor()
    processor.detectionMethod = .languageHints
    processor.verboseLogging = true

    let (result, stats) = processor.detectInParallel(in: image, pose: pose)

    if let bib = result {
        print("✅ RESULT: \(bib.number) (confidence: \(String(format: "%.2f", bib.confidence)))")
    } else {
        print("❌ No bib detected")
    }
    print()
    print(stats.description)
    print()
}

// MARK: - Example 2: Compare Sequential vs Parallel

func example2_CompareSequentialVsParallel(image: CGImage, pose: PoseEstimationResult) {
    print("=" * 60)
    print("EXAMPLE 2: Sequential vs Parallel Performance")
    print("=" * 60)
    print()

    // Sequential processing
    print("PASS 1: Sequential Processing")
    let sequentialStart = Date()

    let torsoManager = TorsoRegionManager()
    let regions = torsoManager.getAllBibRegions(from: pose)

    var sequentialResult: BibNumberResult?
    let detector = LanguageHintOCRDetector()
    detector.vocabularyPreset = .balanced

    for region in regions {
        print("  Processing \(region.zone.rawValue)...")
        if let result = detector.detectBib(in: image, torsoRegion: region) {
            if sequentialResult == nil || result.confidence > sequentialResult!.confidence {
                sequentialResult = result
            }
        }
    }

    let sequentialTime = Date().timeIntervalSince(sequentialStart)

    if let result = sequentialResult {
        print("  ✅ Found: \(result.number) (confidence: \(String(format: "%.2f", result.confidence)))")
    } else {
        print("  ❌ Not found")
    }
    print("  Time: \(String(format: "%.0f", sequentialTime * 1000))ms")
    print()

    // Parallel processing
    print("PASS 2: Parallel Processing")
    let processor = ParallelZoneProcessor()
    processor.detectionMethod = .languageHints
    processor.verboseLogging = false

    let parallelStart = Date()
    let (parallelResult, stats) = processor.detectInParallel(in: image, pose: pose)
    let parallelTime = Date().timeIntervalSince(parallelStart)

    if let result = parallelResult {
        print("  ✅ Found: \(result.number) (confidence: \(String(format: "%.2f", result.confidence)))")
    } else {
        print("  ❌ Not found")
    }
    print("  Time: \(String(format: "%.0f", parallelTime * 1000))ms")
    print()

    // Comparison
    print("COMPARISON:")
    print("  Sequential Time: \(String(format: "%.0f", sequentialTime * 1000))ms")
    print("  Parallel Time: \(String(format: "%.0f", parallelTime * 1000))ms")
    print("  Speedup: \(String(format: "%.1f", sequentialTime / parallelTime))x faster ⚡")
    print("  Same Result: \(sequentialResult?.number == parallelResult?.number ? "✅" : "❌")")
    print()
}

// MARK: - Example 3: Different Detection Methods

func example3_DifferentDetectionMethods(image: CGImage, pose: PoseEstimationResult) {
    print("=" * 60)
    print("EXAMPLE 3: Parallel Processing with Different Methods")
    print("=" * 60)
    print()

    let methods: [ParallelZoneProcessor.DetectionMethod] = [
        .languageHints,
        .textLocalization,
        .colorEnhanced,
        .multiScale
    ]

    for method in methods {
        print("Method: \(method.displayName)")

        let processor = ParallelZoneProcessor()
        processor.detectionMethod = method
        processor.verboseLogging = false

        let (result, stats) = processor.detectInParallel(in: image, pose: pose)

        if let bib = result {
            print("  ✅ Found: \(bib.number) (conf: \(String(format: "%.2f", bib.confidence)), time: \(String(format: "%.0f", stats.totalTime * 1000))ms, speedup: \(String(format: "%.1f", stats.speedupFactor))x)")
        } else {
            print("  ❌ Not found (time: \(String(format: "%.0f", stats.totalTime * 1000))ms)")
        }
        print()
    }
}

// MARK: - Example 4: Smart Parallel with Early Exit

func example4_SmartParallelWithEarlyExit(image: CGImage, pose: PoseEstimationResult) {
    print("=" * 60)
    print("EXAMPLE 4: Smart Parallel with Early Exit")
    print("=" * 60)
    print()

    let smartProcessor = SmartParallelProcessor()
    smartProcessor.earlyExitConfidence = 0.85
    smartProcessor.enableEarlyExit = true

    let (result, stats) = smartProcessor.detectWithEarlyExit(in: image, pose: pose)

    if let bib = result {
        print("✅ RESULT: \(bib.number) (confidence: \(String(format: "%.2f", bib.confidence)))")
        print()
        print("Early exit saved processing on zones that weren't evaluated!")
    } else {
        print("❌ No bib detected")
    }
    print()
}

// MARK: - Example 5: Early Exit On vs Off Comparison

func example5_EarlyExitComparison(image: CGImage, pose: PoseEstimationResult) {
    print("=" * 60)
    print("EXAMPLE 5: Early Exit ON vs OFF Comparison")
    print("=" * 60)
    print()

    // With early exit OFF
    print("PASS 1: Early Exit OFF (process all zones)")
    let processor1 = SmartParallelProcessor()
    processor1.enableEarlyExit = false
    processor1.processor.verboseLogging = false

    let start1 = Date()
    let (result1, stats1) = processor1.detectWithEarlyExit(in: image, pose: pose)
    let time1 = Date().timeIntervalSince(start1)

    if let bib = result1 {
        print("  ✅ Found: \(bib.number) (time: \(String(format: "%.0f", time1 * 1000))ms)")
    } else {
        print("  ❌ Not found")
    }
    print()

    // With early exit ON
    print("PASS 2: Early Exit ON (stop on high confidence)")
    let processor2 = SmartParallelProcessor()
    processor2.enableEarlyExit = true
    processor2.earlyExitConfidence = 0.85
    processor2.processor.verboseLogging = false

    let start2 = Date()
    let (result2, stats2) = processor2.detectWithEarlyExit(in: image, pose: pose)
    let time2 = Date().timeIntervalSince(start2)

    if let bib = result2 {
        print("  ✅ Found: \(bib.number) (time: \(String(format: "%.0f", time2 * 1000))ms)")
    } else {
        print("  ❌ Not found")
    }
    print()

    // Comparison
    print("COMPARISON:")
    print("  Early Exit OFF: \(String(format: "%.0f", time1 * 1000))ms")
    print("  Early Exit ON: \(String(format: "%.0f", time2 * 1000))ms")
    if time2 < time1 {
        let timeSaved = (time1 - time2) / time1 * 100
        print("  Time Saved: \(String(format: "%.1f%%", timeSaved)) ⚡")
    }
    print()
}

// MARK: - Example 6: Custom Zone Priority

func example6_CustomZonePriority(image: CGImage, pose: PoseEstimationResult) {
    print("=" * 60)
    print("EXAMPLE 6: Custom Zone Priority Order")
    print("=" * 60)
    print()

    let smartProcessor = SmartParallelProcessor()

    // Custom priority: Start with lower torso (unusual but demonstrates concept)
    smartProcessor.zonePriority = [
        .lowerTorso,
        .midTorso,
        .upperChest,
        .extendedLowerTorso
    ]

    print("Custom Priority: Lower Torso → Mid → Upper → Extended")
    print()

    let (result, stats) = smartProcessor.detectWithEarlyExit(in: image, pose: pose)

    if let bib = result {
        print("✅ Result: \(bib.number)")
    } else {
        print("❌ No bib detected")
    }
    print()
}

// MARK: - Example 7: Batch Parallel Processing

func example7_BatchParallelProcessing(imagePosePairs: [(CGImage, PoseEstimationResult)]) {
    print("=" * 60)
    print("EXAMPLE 7: Batch Parallel Processing")
    print("=" * 60)
    print()

    let batchProcessor = BatchParallelProcessor()
    batchProcessor.maxConcurrentImages = 4
    batchProcessor.enableProgressReporting = true

    let results = batchProcessor.processBatch(imagePosePairs)

    // Show results summary
    print("RESULTS SUMMARY:")
    for (index, (result, stats)) in results.enumerated() {
        if let bib = result {
            print("  Image \(index + 1): \(bib.number) (speedup: \(String(format: "%.1f", stats.speedupFactor))x)")
        } else {
            print("  Image \(index + 1): Not detected")
        }
    }
    print()
}

// MARK: - Example 8: Quality of Service Comparison

func example8_QoSComparison(image: CGImage, pose: PoseEstimationResult) {
    print("=" * 60)
    print("EXAMPLE 8: Quality of Service (QoS) Comparison")
    print("=" * 60)
    print()

    let qosLevels: [DispatchQoS] = [
        .background,
        .utility,
        .userInitiated,
        .userInteractive
    ]

    for qos in qosLevels {
        let processor = ParallelZoneProcessor()
        processor.qos = qos
        processor.verboseLogging = false

        let start = Date()
        let (result, stats) = processor.detectInParallel(in: image, pose: pose)
        let time = Date().timeIntervalSince(start)

        let qosName: String
        switch qos.qosClass {
        case .background: qosName = "Background"
        case .utility: qosName = "Utility"
        case .userInitiated: qosName = "User Initiated"
        case .userInteractive: qosName = "User Interactive"
        default: qosName = "Default"
        }

        if let bib = result {
            print("\(qosName): ✅ \(bib.number) (time: \(String(format: "%.0f", time * 1000))ms, speedup: \(String(format: "%.1f", stats.speedupFactor))x)")
        } else {
            print("\(qosName): ❌ Not found")
        }
    }
    print()
}

// MARK: - Example 9: Statistics Analysis

func example9_StatisticsAnalysis(image: CGImage, pose: PoseEstimationResult) {
    print("=" * 60)
    print("EXAMPLE 9: Detailed Statistics Analysis")
    print("=" * 60)
    print()

    let processor = ParallelZoneProcessor()
    processor.detectionMethod = .languageHints
    processor.verboseLogging = true

    let (result, stats) = processor.detectInParallel(in: image, pose: pose)

    print()
    print("DETAILED ANALYSIS:")
    print()
    print(stats.description)
    print()

    // Analysis insights
    print("INSIGHTS:")

    let efficiency = stats.speedupFactor / Double(stats.threadsUsed)
    print("  Thread Efficiency: \(String(format: "%.2f", efficiency)) (ideal: 1.0)")

    let parallelismRatio = stats.averageZoneTime / stats.totalTime
    print("  Parallelism Ratio: \(String(format: "%.2f", parallelismRatio)) (higher = better parallelism)")

    if stats.speedupFactor < 2.0 {
        print("  ⚠️ Low speedup - may be I/O bound or limited cores")
    } else if stats.speedupFactor >= 3.0 {
        print("  ✅ Excellent speedup - effective parallelization!")
    }

    if let bib = result {
        print()
        print("Best Result: \(bib.number) (confidence: \(String(format: "%.2f", bib.confidence)))")
    }
    print()
}

// MARK: - Example 10: Full Pipeline with Parallel Processing

func example10_FullPipelineWithParallel(image: CGImage) {
    print("=" * 60)
    print("EXAMPLE 10: Full Pipeline with Parallel Processing")
    print("=" * 60)
    print()

    // Step 1: Pose detection
    print("STEP 1: Pose Detection")
    let poseDetector = PoseEstimator()
    guard let pose = poseDetector.detectPose(in: image) else {
        print("  ❌ Pose detection failed")
        return
    }
    print("  ✅ Pose detected")
    print()

    // Step 2: Parallel zone processing
    print("STEP 2: Parallel Zone Processing")
    let result = ParallelZoneProcessor.detect(in: image, pose: pose)

    if let bib = result {
        print()
        print("✅ FINAL RESULT: \(bib.number) (confidence: \(String(format: "%.2f", bib.confidence)))")
    } else {
        print()
        print("❌ No bib detected")
    }
    print()
}

// MARK: - Example 11: Parallel vs Adaptive Expansion

func example11_ParallelVsAdaptiveExpansion(image: CGImage, pose: PoseEstimationResult) {
    print("=" * 60)
    print("EXAMPLE 11: Parallel vs Adaptive Expansion")
    print("=" * 60)
    print()

    // Parallel processing (all zones at once, standard size)
    print("APPROACH 1: Parallel Processing (Standard Size)")
    let parallel = ParallelZoneProcessor()
    parallel.verboseLogging = false

    let start1 = Date()
    let (result1, stats1) = parallel.detectInParallel(in: image, pose: pose)
    let time1 = Date().timeIntervalSince(start1)

    if let bib = result1 {
        print("  ✅ Found: \(bib.number) (time: \(String(format: "%.0f", time1 * 1000))ms, speedup: \(String(format: "%.1f", stats1.speedupFactor))x)")
    } else {
        print("  ❌ Not found (time: \(String(format: "%.0f", time1 * 1000))ms)")
    }
    print()

    // Adaptive expansion (sequential, progressive sizing)
    print("APPROACH 2: Adaptive Expansion (Progressive Size)")
    let adaptive = AdaptiveTorsoExpander()

    let start2 = Date()
    let result2 = adaptive.detectWithAdaptiveExpansion(in: image, pose: pose)
    let time2 = Date().timeIntervalSince(start2)

    if result2.success {
        print("  ✅ Found: \(result2.bibNumber!.number) (time: \(String(format: "%.0f", time2 * 1000))ms)")
    } else {
        print("  ❌ Not found (time: \(String(format: "%.0f", time2 * 1000))ms)")
    }
    print()

    // Recommendation
    print("RECOMMENDATION:")
    if result1 != nil && result2.success {
        if time1 < time2 {
            print("  ✅ Use parallel processing - Faster and successful")
        } else {
            print("  ⚠️ Use adaptive expansion - More thorough")
        }
    } else if result1 != nil {
        print("  ✅ Parallel processing won - Found bib, adaptive failed")
    } else if result2.success {
        print("  ✅ Adaptive expansion won - Found bib, parallel failed")
    } else {
        print("  ❌ Both failed - Need more aggressive strategies")
    }
    print()
}

// MARK: - Example 12: Hybrid Parallel + Adaptive

func example12_HybridParallelAdaptive(image: CGImage, pose: PoseEstimationResult) {
    print("=" * 60)
    print("EXAMPLE 12: Hybrid Parallel + Adaptive Expansion")
    print("=" * 60)
    print()

    // Try parallel first (fast)
    print("PHASE 1: Parallel Processing (Fast Attempt)")
    let parallel = ParallelZoneProcessor()
    parallel.verboseLogging = false

    let (result1, stats1) = parallel.detectInParallel(in: image, pose: pose)

    if let bib = result1 {
        print("  ✅ SUCCESS in Phase 1!")
        print("  Result: \(bib.number) (confidence: \(String(format: "%.2f", bib.confidence)))")
        print("  Time: \(String(format: "%.0f", stats1.totalTime * 1000))ms")
        print()
        return
    }

    print("  ❌ Phase 1 failed, trying adaptive expansion...")
    print()

    // Fallback to adaptive (thorough)
    print("PHASE 2: Adaptive Expansion (Thorough Fallback)")
    let adaptive = AdaptiveTorsoExpander()
    let result2 = adaptive.detectWithAdaptiveExpansion(in: image, pose: pose)

    if result2.success {
        print("  ✅ SUCCESS in Phase 2!")
        print("  Result: \(result2.bibNumber!.number) (confidence: \(String(format: "%.2f", result2.bibNumber!.confidence)))")
        print("  Strategy: \(result2.strategyUsed.displayName)")
    } else {
        print("  ❌ Both phases failed")
    }
    print()
}

// MARK: - Helper: Run All Examples

func runAllParallelProcessingExamples() {
    print("\n")
    print("=" * 60)
    print("PARALLEL ZONE PROCESSING - ALL EXAMPLES")
    print("=" * 60)
    print("\n")

    print("NOTE: These examples require image and pose data")
    print("      Load your images and poses, then call examples individually")
    print("\n")

    print("Available Examples:")
    print("  1. Basic Parallel Processing")
    print("  2. Sequential vs Parallel Comparison")
    print("  3. Different Detection Methods")
    print("  4. Smart Parallel with Early Exit")
    print("  5. Early Exit ON vs OFF")
    print("  6. Custom Zone Priority")
    print("  7. Batch Parallel Processing")
    print("  8. Quality of Service (QoS) Comparison")
    print("  9. Statistics Analysis")
    print("  10. Full Pipeline with Parallel")
    print("  11. Parallel vs Adaptive Expansion")
    print("  12. Hybrid Parallel + Adaptive")
    print("\n")
}

// MARK: - Main Entry Point

#if DEBUG
// Uncomment to run:
// runAllParallelProcessingExamples()
#endif
