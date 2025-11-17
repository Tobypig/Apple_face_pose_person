//
//  IntegrationTests.swift
//  Apple Vision Framework - Integration Tests
//
//  Comprehensive integration tests for the full bib detection pipeline
//  Tests all features working together in realistic scenarios
//

import Foundation
import XCTest
import CoreGraphics

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Test Configuration

/// Configuration for integration tests
struct IntegrationTestConfig {
    var enableVerboseLogging: Bool = false
    var testImagePath: String = ""
    var expectedBibNumber: String = ""
    var minimumConfidence: Float = 0.5
    var timeoutSeconds: TimeInterval = 10.0
}

// MARK: - Integration Test Suite

class BibDetectionIntegrationTests: XCTestCase {

    var testConfig = IntegrationTestConfig()

    // MARK: - Test 1: Full Pipeline with All Features

    func testFullPipelineWithAllFeatures() {
        print("\n=== TEST 1: Full Pipeline with All Features ===\n")

        guard let testImage = loadTestImage() else {
            XCTFail("Failed to load test image")
            return
        }

        // Step 1: Person Detection
        let personDetector = PersonDetector()
        let persons = personDetector.detectPersons(in: testImage)

        XCTAssertGreaterThan(persons.count, 0, "Should detect at least one person")
        print("✅ Person Detection: \(persons.count) person(s) found")

        guard let person = persons.first else {
            XCTFail("No person detected")
            return
        }

        // Step 2: Pose Estimation
        let poseDetector = PoseEstimator()
        guard let pose = poseDetector.detectPose(in: testImage) else {
            XCTFail("Failed to detect pose")
            return
        }

        XCTAssertGreaterThan(pose.confidence, 0.3, "Pose confidence should be reasonable")
        print("✅ Pose Estimation: confidence \(String(format: "%.2f", pose.confidence))")

        // Step 3: Parallel Zone Processing with Language Hints
        let parallelProcessor = ParallelZoneProcessor()
        parallelProcessor.detectionMethod = .languageHints
        parallelProcessor.verboseLogging = testConfig.enableVerboseLogging

        let (result, stats) = parallelProcessor.detectInParallel(in: testImage, pose: pose)

        if let bib = result {
            print("✅ Bib Detection: \(bib.number) (confidence: \(String(format: "%.2f", bib.confidence)))")
            print("   Speedup: \(String(format: "%.1f", stats.speedupFactor))x")

            XCTAssertGreaterThan(bib.confidence, testConfig.minimumConfidence, "Confidence should meet minimum threshold")

            if !testConfig.expectedBibNumber.isEmpty {
                XCTAssertEqual(bib.number, testConfig.expectedBibNumber, "Should detect expected bib number")
            }
        } else {
            XCTFail("Failed to detect bib number")
        }

        print("\n✅ Full pipeline test passed\n")
    }

    // MARK: - Test 2: Sequential Feature Testing

    func testSequentialFeatures() {
        print("\n=== TEST 2: Sequential Feature Testing ===\n")

        guard let testImage = loadTestImage() else {
            XCTFail("Failed to load test image")
            return
        }

        guard let pose = getPoseForImage(testImage) else {
            XCTFail("Failed to get pose")
            return
        }

        // Test 1: Text Localization
        print("Testing: Text Localization")
        let textLocalizer = TextLocalizedBibDetection()
        let torsoManager = TorsoRegionManager()
        if let upperChest = torsoManager.getUpperChestRegion(from: pose) {
            let result1 = textLocalizer.detectBib(in: testImage, torsoRegion: upperChest)
            if let bib = result1 {
                print("  ✅ Text Localization: \(bib.number)")
            } else {
                print("  ⚠️  Text Localization: Not found")
            }
        }

        // Test 2: Color-Based Detection
        print("Testing: Color-Based Detection")
        let colorDetector = ColorEnhancedBibDetection()
        if let upperChest = torsoManager.getUpperChestRegion(from: pose) {
            let result2 = colorDetector.detectBib(in: testImage, torsoRegion: upperChest)
            if let bib = result2 {
                print("  ✅ Color-Based: \(bib.number)")
            } else {
                print("  ⚠️  Color-Based: Not found")
            }
        }

        // Test 3: Language Hints
        print("Testing: Language Hints")
        let languageHints = LanguageHintOCRDetector()
        languageHints.vocabularyPreset = .balanced
        if let upperChest = torsoManager.getUpperChestRegion(from: pose) {
            let result3 = languageHints.detectBib(in: testImage, torsoRegion: upperChest)
            if let bib = result3 {
                print("  ✅ Language Hints: \(bib.number)")
            } else {
                print("  ⚠️  Language Hints: Not found")
            }
        }

        // Test 4: Adaptive Expansion
        print("Testing: Adaptive Expansion")
        let adaptiveExpander = AdaptiveTorsoExpander()
        let result4 = adaptiveExpander.detectWithAdaptiveExpansion(in: testImage, pose: pose)
        if result4.success {
            print("  ✅ Adaptive Expansion: \(result4.bibNumber!.number) (strategy: \(result4.strategyUsed.displayName))")
        } else {
            print("  ⚠️  Adaptive Expansion: Not found")
        }

        print("\n✅ Sequential feature test completed\n")
    }

    // MARK: - Test 3: Performance Comparison

    func testPerformanceComparison() {
        print("\n=== TEST 3: Performance Comparison ===\n")

        guard let testImage = loadTestImage() else {
            XCTFail("Failed to load test image")
            return
        }

        guard let pose = getPoseForImage(testImage) else {
            XCTFail("Failed to get pose")
            return
        }

        var results: [(method: String, time: TimeInterval, found: Bool)] = []

        // Sequential processing
        print("Testing: Sequential Processing")
        let start1 = Date()
        let torsoManager = TorsoRegionManager()
        let regions = torsoManager.getAllBibRegions(from: pose)
        let detector = LanguageHintOCRDetector()

        var sequentialFound = false
        for region in regions {
            if detector.detectBib(in: testImage, torsoRegion: region) != nil {
                sequentialFound = true
                break
            }
        }
        let time1 = Date().timeIntervalSince(start1)
        results.append(("Sequential", time1, sequentialFound))
        print("  Time: \(String(format: "%.0f", time1 * 1000))ms")

        // Parallel processing
        print("Testing: Parallel Processing")
        let start2 = Date()
        let parallel = ParallelZoneProcessor()
        parallel.verboseLogging = false
        let (parallelResult, _) = parallel.detectInParallel(in: testImage, pose: pose)
        let time2 = Date().timeIntervalSince(start2)
        results.append(("Parallel", time2, parallelResult != nil))
        print("  Time: \(String(format: "%.0f", time2 * 1000))ms")

        // Confidence-weighted
        print("Testing: Confidence-Weighted")
        let start3 = Date()
        let confWeighted = ConfidenceWeightedBibDetector()
        confWeighted.verboseLogging = false
        let (confResult, _) = confWeighted.detectWithConfidenceWeighting(in: testImage, pose: pose)
        let time3 = Date().timeIntervalSince(start3)
        results.append(("Confidence-Weighted", time3, confResult != nil))
        print("  Time: \(String(format: "%.0f", time3 * 1000))ms")

        // Performance analysis
        print("\nPerformance Analysis:")
        for result in results {
            let status = result.found ? "✅" : "❌"
            print("  \(result.method): \(String(format: "%.0f", result.time * 1000))ms \(status)")
        }

        if time2 < time1 {
            let speedup = time1 / time2
            print("\n  Parallel speedup: \(String(format: "%.1f", speedup))x faster")
            XCTAssertGreaterThan(speedup, 1.5, "Parallel should be at least 1.5x faster")
        }

        print("\n✅ Performance comparison completed\n")
    }

    // MARK: - Test 4: Fallback Chain

    func testFallbackChain() {
        print("\n=== TEST 4: Fallback Chain ===\n")

        guard let testImage = loadTestImage() else {
            XCTFail("Failed to load test image")
            return
        }

        guard let pose = getPoseForImage(testImage) else {
            XCTFail("Failed to get pose")
            return
        }

        let torsoManager = TorsoRegionManager()
        guard let upperChest = torsoManager.getUpperChestRegion(from: pose) else {
            XCTFail("Failed to get upper chest region")
            return
        }

        var detectionSucceeded = false

        // Try 1: Fast text localization
        print("Pass 1: Fast Text Localization")
        let textLocalizer = TextLocalizedBibDetection()
        if let result = textLocalizer.detectBib(in: testImage, torsoRegion: upperChest) {
            print("  ✅ Success: \(result.number)")
            detectionSucceeded = true
        } else {
            print("  ⚠️  Failed, trying next method...")

            // Try 2: Color-based
            print("Pass 2: Color-Based Detection")
            let colorDetector = ColorEnhancedBibDetection()
            if let result = colorDetector.detectBib(in: testImage, torsoRegion: upperChest) {
                print("  ✅ Success: \(result.number)")
                detectionSucceeded = true
            } else {
                print("  ⚠️  Failed, trying next method...")

                // Try 3: Adaptive expansion
                print("Pass 3: Adaptive Expansion")
                let adaptive = AdaptiveTorsoExpander()
                let result = adaptive.detectWithAdaptiveExpansion(in: testImage, pose: pose)
                if result.success {
                    print("  ✅ Success: \(result.bibNumber!.number)")
                    detectionSucceeded = true
                } else {
                    print("  ❌ All methods failed")
                }
            }
        }

        XCTAssertTrue(detectionSucceeded, "At least one detection method should succeed")

        print("\n✅ Fallback chain test completed\n")
    }

    // MARK: - Test 5: Zone Confidence Analysis

    func testZoneConfidenceAnalysis() {
        print("\n=== TEST 5: Zone Confidence Analysis ===\n")

        guard let testImage = loadTestImage() else {
            XCTFail("Failed to load test image")
            return
        }

        guard let pose = getPoseForImage(testImage) else {
            XCTFail("Failed to get pose")
            return
        }

        let analyzer = JointConfidenceAnalyzer()
        analyzer.verboseLogging = true
        let zoneConfidence = analyzer.analyzeZoneConfidence(for: pose)

        XCTAssertEqual(zoneConfidence.count, 4, "Should analyze all 4 zones")

        let reliableZones = analyzer.getReliableZones(for: pose)
        print("\nReliable zones: \(reliableZones.count)/4")

        for zone in reliableZones {
            print("  ✅ \(zone.rawValue)")
        }

        XCTAssertGreaterThan(reliableZones.count, 0, "Should have at least one reliable zone")

        print("\n✅ Zone confidence analysis test completed\n")
    }

    // MARK: - Test 6: Vocabulary Generation

    func testVocabularyGeneration() {
        print("\n=== TEST 6: Vocabulary Generation ===\n")

        let generator = BibVocabularyGenerator()
        generator.maxBibNumber = 100 // Small for testing
        generator.includeDivisionMarkers = true
        generator.includeVariations = true

        let vocabulary = generator.generateVocabulary()

        XCTAssertGreaterThan(vocabulary.count, 100, "Should generate substantial vocabulary")

        // Check for expected entries
        XCTAssertTrue(vocabulary.contains("1"), "Should contain basic numbers")
        XCTAssertTrue(vocabulary.contains("100"), "Should contain max number")

        if generator.includeDivisionMarkers {
            XCTAssertTrue(vocabulary.contains("A1") || vocabulary.contains { $0.hasPrefix("A") }, "Should contain division markers")
        }

        print("Generated \(vocabulary.count) vocabulary entries")
        print("Sample entries: \(vocabulary.prefix(10).joined(separator: ", "))")

        print("\n✅ Vocabulary generation test completed\n")
    }

    // MARK: - Test 7: Parallel vs Sequential Accuracy

    func testParallelVsSequentialAccuracy() {
        print("\n=== TEST 7: Parallel vs Sequential Accuracy ===\n")

        guard let testImage = loadTestImage() else {
            XCTFail("Failed to load test image")
            return
        }

        guard let pose = getPoseForImage(testImage) else {
            XCTFail("Failed to get pose")
            return
        }

        // Sequential
        print("Testing: Sequential Detection")
        let torsoManager = TorsoRegionManager()
        let regions = torsoManager.getAllBibRegions(from: pose)
        let detector = LanguageHintOCRDetector()

        var sequentialResult: BibNumberResult?
        for region in regions {
            if let result = detector.detectBib(in: testImage, torsoRegion: region) {
                if sequentialResult == nil || result.confidence > sequentialResult!.confidence {
                    sequentialResult = result
                }
            }
        }

        // Parallel
        print("Testing: Parallel Detection")
        let parallel = ParallelZoneProcessor()
        parallel.detectionMethod = .languageHints
        parallel.verboseLogging = false
        let (parallelResult, _) = parallel.detectInParallel(in: testImage, pose: pose)

        // Compare results
        if let seq = sequentialResult, let par = parallelResult {
            print("\nResults:")
            print("  Sequential: \(seq.number) (conf: \(String(format: "%.2f", seq.confidence)))")
            print("  Parallel: \(par.number) (conf: \(String(format: "%.2f", par.confidence)))")

            XCTAssertEqual(seq.number, par.number, "Both methods should find same bib number")
        } else {
            XCTFail("Both methods should succeed")
        }

        print("\n✅ Parallel vs sequential accuracy test completed\n")
    }

    // MARK: - Test 8: End-to-End Realistic Scenario

    func testEndToEndRealisticScenario() {
        print("\n=== TEST 8: End-to-End Realistic Scenario ===\n")

        guard let testImage = loadTestImage() else {
            XCTFail("Failed to load test image")
            return
        }

        let startTime = Date()

        // Step 1: Person detection
        print("Step 1: Person Detection")
        let personDetector = PersonDetector()
        guard let person = personDetector.detectPersons(in: testImage).first else {
            XCTFail("No person detected")
            return
        }
        print("  ✅ Person detected")

        // Step 2: Pose estimation
        print("Step 2: Pose Estimation")
        let poseDetector = PoseEstimator()
        guard let pose = poseDetector.detectPose(in: testImage) else {
            XCTFail("Pose detection failed")
            return
        }
        print("  ✅ Pose detected (conf: \(String(format: "%.2f", pose.confidence)))")

        // Step 3: Zone confidence analysis
        print("Step 3: Zone Confidence Analysis")
        let analyzer = JointConfidenceAnalyzer()
        let reliableZones = analyzer.getReliableZones(for: pose)
        print("  ✅ \(reliableZones.count) reliable zones")

        // Step 4: Smart detection (parallel if 2+ zones, sequential otherwise)
        print("Step 4: Smart Detection")
        let smartProcessor = SmartConfidenceProcessor()
        let (result, stats) = smartProcessor.detectSmart(in: testImage, pose: pose)

        let totalTime = Date().timeIntervalSince(startTime)

        if let bib = result {
            print("  ✅ Bib detected: \(bib.number)")
            print("\nFinal Result:")
            print("  Bib Number: \(bib.number)")
            print("  Confidence: \(String(format: "%.2f", bib.confidence))")
            print("  Total Time: \(String(format: "%.0f", totalTime * 1000))ms")
            print("  Zones Processed: \(stats.zonesProcessed)")
            print("  Zones Skipped: \(stats.zonesSkipped)")

            XCTAssertGreaterThan(bib.confidence, 0.5, "Should have reasonable confidence")
        } else {
            XCTFail("Failed to detect bib")
        }

        print("\n✅ End-to-end realistic scenario test completed\n")
    }

    // MARK: - Helper Methods

    private func loadTestImage() -> CGImage? {
        // In real tests, load from test bundle
        // For now, return nil (tests would need actual images)
        return nil
    }

    private func getPoseForImage(_ image: CGImage) -> PoseEstimationResult? {
        let poseDetector = PoseEstimator()
        return poseDetector.detectPose(in: image)
    }
}

// MARK: - Test Runner

/// Run all integration tests
func runIntegrationTests() {
    print("\n")
    print("=" * 80)
    print("BIB DETECTION INTEGRATION TESTS")
    print("=" * 80)
    print("\n")

    let suite = BibDetectionIntegrationTests()

    // Note: In real XCTest, these would run automatically
    // Here we provide a manual runner for demonstration

    print("Available Integration Tests:")
    print("  1. Full Pipeline with All Features")
    print("  2. Sequential Feature Testing")
    print("  3. Performance Comparison")
    print("  4. Fallback Chain")
    print("  5. Zone Confidence Analysis")
    print("  6. Vocabulary Generation")
    print("  7. Parallel vs Sequential Accuracy")
    print("  8. End-to-End Realistic Scenario")
    print("\n")

    print("To run tests:")
    print("  swift test")
    print("  OR")
    print("  Load test images and call individual test methods")
    print("\n")
}

// MARK: - Main Entry Point

#if DEBUG
// Uncomment to run:
// runIntegrationTests()
#endif
