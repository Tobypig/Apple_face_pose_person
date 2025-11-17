//
//  LanguageHintsExamples.swift
//  Apple Vision Framework - Language Hints OCR Examples
//
//  Example usage of custom vocabulary for improved bib detection
//

import Foundation
import Vision
import CoreGraphics

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Example 1: Basic Vocabulary Generation

func example1_BasicVocabularyGeneration() {
    print("=" * 60)
    print("EXAMPLE 1: Basic Vocabulary Generation")
    print("=" * 60)
    print()

    let generator = BibVocabularyGenerator()
    generator.maxBibNumber = 100 // Small for demo
    generator.includeDivisionMarkers = false
    generator.includeVariations = true

    let vocabulary = generator.generateVocabulary()

    print("Sample vocabulary (first 20):")
    for word in vocabulary.prefix(20) {
        print("  - \(word)")
    }
    print()
    print("Total entries: \(vocabulary.count)")
    print()
}

// MARK: - Example 2: Division Markers

func example2_DivisionMarkers() {
    print("=" * 60)
    print("EXAMPLE 2: Division Markers (A1, B2, etc.)")
    print("=" * 60)
    print()

    let generator = BibVocabularyGenerator()
    generator.maxBibNumber = 50 // Small for demo
    generator.includeDivisionMarkers = true
    generator.includeVariations = false

    let vocabulary = generator.generateVocabulary()

    // Show division examples
    let divisionExamples = vocabulary.filter { $0.first?.isLetter == true }

    print("Division marker examples (first 30):")
    for word in divisionExamples.prefix(30) {
        print("  - \(word)")
    }
    print()
    print("Total division entries: \(divisionExamples.count)")
    print()
}

// MARK: - Example 3: Vocabulary Presets Comparison

func example3_VocabularyPresets() {
    print("=" * 60)
    print("EXAMPLE 3: Vocabulary Presets Comparison")
    print("=" * 60)
    print()

    let presets: [LanguageHintOCRDetector.VocabularyPreset] = [
        .minimal, .fast, .balanced, .complete
    ]

    for preset in presets {
        let startTime = Date()

        let vocabulary: [String]
        switch preset {
        case .minimal:
            vocabulary = preset.generator.generateMinimalVocabulary()
        case .fast:
            vocabulary = preset.generator.generateFastVocabulary()
        case .balanced, .complete:
            vocabulary = preset.generator.generateVocabulary()
        }

        let duration = Date().timeIntervalSince(startTime)

        print("\(preset.displayName):")
        print("  Entries: \(vocabulary.count)")
        print("  Generation Time: \(String(format: "%.0f", duration * 1000))ms")
        print("  Memory (approx): \(String(format: "%.1f", Float(vocabulary.count * 10) / 1024))KB")
        print()
    }
}

// MARK: - Example 4: Basic Language Hint OCR

func example4_BasicLanguageHintOCR(bibRegionImage: CGImage) {
    print("=" * 60)
    print("EXAMPLE 4: Basic Language Hint OCR")
    print("=" * 60)
    print()

    let detector = LanguageHintOCRDetector()
    detector.vocabularyPreset = .balanced
    detector.useCustomVocabulary = true

    let startTime = Date()
    let result = detector.recognizeText(in: bibRegionImage)
    let duration = Date().timeIntervalSince(startTime)

    if let result = result {
        print("✅ Detection successful:")
        print("   Bib Number: \(result.number)")
        print("   Confidence: \(String(format: "%.2f", result.confidence))")
        print("   Time: \(String(format: "%.0f", duration * 1000))ms")
    } else {
        print("❌ Detection failed")
        print("   Time: \(String(format: "%.0f", duration * 1000))ms")
    }
    print()
}

// MARK: - Example 5: Compare With vs Without Vocabulary

func example5_CompareWithAndWithoutVocabulary(bibRegionImage: CGImage) {
    print("=" * 60)
    print("EXAMPLE 5: Compare With/Without Custom Vocabulary")
    print("=" * 60)
    print()

    // Without vocabulary
    print("Pass 1: WITHOUT custom vocabulary")
    let detector1 = LanguageHintOCRDetector()
    detector1.useCustomVocabulary = false

    let start1 = Date()
    let result1 = detector1.recognizeText(in: bibRegionImage)
    let duration1 = Date().timeIntervalSince(start1)

    if let result1 = result1 {
        print("  Result: \(result1.number) (confidence: \(String(format: "%.2f", result1.confidence)))")
        print("  Time: \(String(format: "%.0f", duration1 * 1000))ms")
    } else {
        print("  Result: Failed")
    }
    print()

    // With vocabulary
    print("Pass 2: WITH custom vocabulary (Balanced)")
    let detector2 = LanguageHintOCRDetector()
    detector2.useCustomVocabulary = true
    detector2.vocabularyPreset = .balanced

    let start2 = Date()
    let result2 = detector2.recognizeText(in: bibRegionImage)
    let duration2 = Date().timeIntervalSince(start2)

    if let result2 = result2 {
        print("  Result: \(result2.number) (confidence: \(String(format: "%.2f", result2.confidence)))")
        print("  Time: \(String(format: "%.0f", duration2 * 1000))ms")
    } else {
        print("  Result: Failed")
    }
    print()

    // Analysis
    print("ANALYSIS:")
    if let r1 = result1, let r2 = result2 {
        let confidenceImprovement = (r2.confidence - r1.confidence) / r1.confidence * 100
        print("  Confidence Improvement: \(String(format: "%.1f%%", confidenceImprovement))")
        print("  Same Result: \(r1.number == r2.number ? "✅" : "❌")")
    } else if result1 == nil && result2 != nil {
        print("  ✅ Vocabulary enabled detection where standard OCR failed!")
    }
    print()
}

// MARK: - Example 6: Multi-Candidate Detection

func example6_MultiCandidateDetection(bibRegionImage: CGImage) {
    print("=" * 60)
    print("EXAMPLE 6: Multi-Candidate Detection")
    print("=" * 60)
    print()

    let detector = MultiCandidateLanguageHintOCR()
    detector.maxCandidates = 5
    detector.minimumConfidence = 0.3

    let candidates = detector.detectCandidates(in: bibRegionImage)

    print("Found \(candidates.count) candidates:")
    for (index, candidate) in candidates.enumerated() {
        print("  \(index + 1). \(candidate.number) (confidence: \(String(format: "%.2f", candidate.confidence)))")
    }
    print()

    // Show top candidate
    if let best = candidates.first {
        print("Best candidate: \(best.number) with \(String(format: "%.2f", best.confidence)) confidence")
    }
    print()
}

// MARK: - Example 7: Vocabulary Statistics Tracking

func example7_VocabularyStatistics() {
    print("=" * 60)
    print("EXAMPLE 7: Vocabulary Statistics Tracking")
    print("=" * 60)
    print()

    let stats = VocabularyStatistics()
    let detector = LanguageHintOCRDetector()
    detector.vocabularyPreset = .balanced

    let vocabulary = detector.vocabularyPreset.generator.generateVocabulary()

    // Simulate 20 detections
    let simulatedResults = [
        "1234", "5678", "A123", "B456", "9999",
        "111", "222", "C789", nil, "333",
        "D999", nil, "4444", "E555", "666",
        "777", nil, "F888", "999", "G111"
    ]

    print("Simulating \(simulatedResults.count) detections...")
    print()

    for (index, resultNumber) in simulatedResults.enumerated() {
        let result = resultNumber.map { BibNumberResult(number: $0, confidence: 0.9, boundingBox: .zero) }
        stats.recordResult(result, vocabulary: vocabulary)

        if let result = result {
            let inVocab = vocabulary.contains(result.number)
            print("  Detection \(index + 1): \(result.number) - \(inVocab ? "✅ In vocabulary" : "❌ Not in vocabulary")")
        } else {
            print("  Detection \(index + 1): Failed")
        }
    }
    print()

    print(stats.summary)
    print()
}

// MARK: - Example 8: Preset Performance Comparison

func example8_PresetPerformanceComparison(bibRegionImage: CGImage) {
    print("=" * 60)
    print("EXAMPLE 8: Preset Performance Comparison")
    print("=" * 60)
    print()

    let presets: [LanguageHintOCRDetector.VocabularyPreset] = [
        .minimal, .fast, .balanced
    ]

    for preset in presets {
        let detector = LanguageHintOCRDetector()
        detector.vocabularyPreset = preset
        detector.useCustomVocabulary = true

        print("\(preset.displayName):")

        let startTime = Date()
        let result = detector.recognizeText(in: bibRegionImage)
        let duration = Date().timeIntervalSince(startTime)

        if let result = result {
            print("  Result: \(result.number)")
            print("  Confidence: \(String(format: "%.2f", result.confidence))")
            print("  Time: \(String(format: "%.0f", duration * 1000))ms")
        } else {
            print("  Result: Failed")
            print("  Time: \(String(format: "%.0f", duration * 1000))ms")
        }
        print()
    }
}

// MARK: - Example 9: Hybrid Detection Strategy

func example9_HybridDetection(fullImage: CGImage, pose: PoseEstimationResult) {
    print("=" * 60)
    print("EXAMPLE 9: Hybrid Detection Strategy")
    print("=" * 60)
    print()

    let hybrid = HybridLanguageHintDetection()

    // Get torso region from pose
    let torsoManager = TorsoRegionManager()
    guard let upperChestRegion = torsoManager.getUpperChestRegion(from: pose) else {
        print("❌ Failed to get torso region")
        return
    }

    print("Trying hybrid detection with 3-method fallback:")
    print()

    let startTime = Date()
    let result = hybrid.detectBib(in: fullImage, torsoRegion: upperChestRegion)
    let duration = Date().timeIntervalSince(startTime)

    if let result = result {
        print()
        print("✅ FINAL RESULT:")
        print("   Bib Number: \(result.number)")
        print("   Confidence: \(String(format: "%.2f", result.confidence))")
        print("   Total Time: \(String(format: "%.0f", duration * 1000))ms")
    } else {
        print()
        print("❌ All methods failed")
    }
    print()
}

// MARK: - Example 10: Full Pipeline with Language Hints

func example10_FullPipelineWithLanguageHints(image: CGImage) {
    print("=" * 60)
    print("EXAMPLE 10: Full Detection Pipeline with Language Hints")
    print("=" * 60)
    print()

    // Step 1: Pose detection
    print("STEP 1: Pose Detection")
    let poseDetector = PoseEstimator()
    guard let poseResult = poseDetector.detectPose(in: image) else {
        print("  ❌ Pose detection failed")
        return
    }
    print("  ✅ Pose detected (confidence: \(String(format: "%.2f", poseResult.confidence)))")
    print()

    // Step 2: Generate torso regions
    print("STEP 2: Generate Torso Regions")
    let torsoManager = TorsoRegionManager()
    let regions = torsoManager.getAllBibRegions(from: poseResult)
    print("  ✅ Generated \(regions.count) torso regions")
    print()

    // Step 3: Try language hint OCR on each region
    print("STEP 3: Language Hint OCR on Each Region")
    let detector = LanguageHintOCRDetector()
    detector.vocabularyPreset = .balanced
    detector.useCustomVocabulary = true

    var bestResult: BibNumberResult?
    var bestRegionIndex = -1

    for (index, region) in regions.enumerated() {
        print("  Region \(index + 1) (\(region.zone.rawValue)):")

        if let result = detector.detectBib(in: image, torsoRegion: region) {
            print("    ✅ Detected: \(result.number) (confidence: \(String(format: "%.2f", result.confidence)))")

            if bestResult == nil || result.confidence > bestResult!.confidence {
                bestResult = result
                bestRegionIndex = index
            }
        } else {
            print("    ❌ No detection")
        }
    }
    print()

    // Step 4: Final result
    print("STEP 4: Final Result")
    if let best = bestResult {
        print("  ✅ Best Detection:")
        print("     Bib Number: \(best.number)")
        print("     Confidence: \(String(format: "%.2f", best.confidence))")
        print("     Region: \(regions[bestRegionIndex].zone.rawValue)")
    } else {
        print("  ❌ No bib number detected in any region")
    }
    print()
}

// MARK: - Example 11: Batch Processing with Statistics

func example11_BatchProcessingWithStats(images: [CGImage]) {
    print("=" * 60)
    print("EXAMPLE 11: Batch Processing with Statistics")
    print("=" * 60)
    print()

    let detector = LanguageHintOCRDetector()
    detector.vocabularyPreset = .balanced
    detector.useCustomVocabulary = true

    let stats = VocabularyStatistics()
    let vocabulary = detector.vocabularyPreset.generator.generateVocabulary()

    var totalTime: TimeInterval = 0
    var successCount = 0

    print("Processing \(images.count) images...")
    print()

    for (index, image) in images.enumerated() {
        print("Image \(index + 1)/\(images.count):")

        let startTime = Date()
        let result = detector.recognizeText(in: image)
        let duration = Date().timeIntervalSince(startTime)

        totalTime += duration
        stats.recordResult(result, vocabulary: vocabulary)

        if let result = result {
            successCount += 1
            print("  ✅ \(result.number) (confidence: \(String(format: "%.2f", result.confidence)), time: \(String(format: "%.0f", duration * 1000))ms)")
        } else {
            print("  ❌ Failed (time: \(String(format: "%.0f", duration * 1000))ms)")
        }
    }
    print()

    // Summary
    print("BATCH SUMMARY:")
    print("  Total Images: \(images.count)")
    print("  Successful: \(successCount)")
    print("  Success Rate: \(String(format: "%.1f%%", Float(successCount) / Float(images.count) * 100))")
    print("  Total Time: \(String(format: "%.1f", totalTime))s")
    print("  Average Time: \(String(format: "%.0f", totalTime / Double(images.count) * 1000))ms/image")
    print()

    print(stats.summary)
    print()
}

// MARK: - Example 12: Optimized Minimal Vocabulary for Speed

func example12_OptimizedMinimalVocabulary(bibRegionImage: CGImage) {
    print("=" * 60)
    print("EXAMPLE 12: Optimized Minimal Vocabulary (Speed Focus)")
    print("=" * 60)
    print()

    // Minimal vocabulary for maximum speed
    let detector = LanguageHintOCRDetector()
    detector.vocabularyPreset = .minimal
    detector.useCustomVocabulary = true
    detector.recognitionLevel = .fast

    print("Configuration:")
    print("  Preset: Minimal (numbers only)")
    print("  Recognition Level: Fast")
    print()

    let startTime = Date()
    let result = detector.recognizeText(in: bibRegionImage)
    let duration = Date().timeIntervalSince(startTime)

    if let result = result {
        print("✅ Detection successful:")
        print("   Bib Number: \(result.number)")
        print("   Confidence: \(String(format: "%.2f", result.confidence))")
        print("   Time: \(String(format: "%.0f", duration * 1000))ms ⚡")
    } else {
        print("❌ Detection failed")
    }
    print()

    print("PERFORMANCE NOTE:")
    print("  Minimal vocabulary provides ~2x faster OCR")
    print("  Best for races without division markers")
    print()
}

// MARK: - Helper: Run All Examples

func runAllLanguageHintExamples() {
    print("\n")
    print("=" * 60)
    print("LANGUAGE HINTS OCR - ALL EXAMPLES")
    print("=" * 60)
    print("\n")

    // Run examples that don't require images
    example1_BasicVocabularyGeneration()
    example2_DivisionMarkers()
    example3_VocabularyPresets()
    example7_VocabularyStatistics()

    print("\n")
    print("✅ All non-image examples completed!")
    print("\n")
    print("NOTE: Examples 4-6, 8-12 require image data")
    print("      Load your bib images and call these examples directly")
    print("\n")
}

// MARK: - Main Entry Point

#if DEBUG
// Uncomment to run examples:
// runAllLanguageHintExamples()
#endif
