import Foundation
import CoreImage
import CoreGraphics

#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

// MARK: - Difficulty-Adaptive Examples

class DifficultyAdaptiveExamples {

    // MARK: - Example 1: AUTO Mode (Recommended!)

    static func example1_AutoMode() {
        print("=== Example 1: AUTO Mode (Recommended!) ===\n")

        guard let image = loadExampleImage(),
              let cgImage = image.cgImage else {
            return
        }

        let pipeline = DifficultyAdaptiveFeedbackLoop()

        // Enable AUTO mode (default)
        pipeline.autoDetectDifficulty = true

        print("Running AUTO mode - pipeline will detect difficulty automatically...\n")

        if let result = pipeline.detectBibNumber(in: cgImage) {
            print("\n=== SUCCESS ===")
            print("Bib Number: \(result.bibNumber)")
            print("Confidence: \(String(format: "%.2f", result.confidence))")
            print("Iteration: \(result.iteration)")
            print("Used Rescue: \(result.usedRescue)")
            if let strategy = result.rescueStrategy {
                print("Rescue Strategy: \(strategy.displayName)")
            }
            print("Processing Time: \(String(format: "%.3f", result.totalProcessingTime))s")
        } else {
            print("\n=== FAILED ===")
        }
    }

    // MARK: - Example 2: Manual Difficulty Levels

    static func example2_ManualDifficultyLevels() {
        print("\n=== Example 2: Manual Difficulty Levels ===\n")

        guard let image = loadExampleImage(),
              let cgImage = image.cgImage else {
            return
        }

        let pipeline = DifficultyAdaptiveFeedbackLoop()
        pipeline.autoDetectDifficulty = false  // Disable auto

        let levels: [ImageDifficultyLevel] = [.light, .medium, .hard, .extreme]

        for level in levels {
            print("\n--- Testing \(level.emoji) \(level.displayName) ---\n")

            pipeline.manualDifficultyLevel = level

            if let result = pipeline.detectBibNumber(in: cgImage) {
                print("✓ Success with \(level.displayName)")
                print("  Bib: \(result.bibNumber)")
                print("  Iterations: \(result.iteration)")
                print("  Time: \(String(format: "%.3f", result.totalProcessingTime))s")
            } else {
                print("✗ Failed with \(level.displayName)")
            }
        }
    }

    // MARK: - Example 3: Difficulty Analysis

    static func example3_DifficultyAnalysis() {
        print("\n=== Example 3: Difficulty Analysis ===\n")

        guard let image = loadExampleImage(),
              let cgImage = image.cgImage else {
            return
        }

        let analyzer = ImageDifficultyAnalyzer()

        // Detailed analysis
        analyzer.printDetailedAnalysis(cgImage)

        // Or get structured data
        let (level, metrics) = analyzer.analyzeDifficulty(cgImage)

        print("\nSummary:")
        print("  Difficulty: \(level.emoji) \(level.displayName)")
        print("  Quality Score: \(String(format: "%.2f", metrics.overallQuality))")
        print("  Person Detected: \(metrics.hasDetectedPeople ? "Yes" : "No")")
        if let size = metrics.largestPersonSize {
            print("  Person Size: \(String(format: "%.1f%%", size * 100))")
        }
        print("  Challenges:")
        if metrics.hasMotionBlur { print("    • Motion Blur") }
        if metrics.hasBacklighting { print("    • Backlighting") }
        if metrics.hasOcclusion { print("    • Occlusion") }
        if !metrics.hasGoodLighting { print("    • Poor Lighting") }
        if metrics.sharpness < 0.3 { print("    • Low Sharpness") }
    }

    // MARK: - Example 4: Configuration Comparison

    static func example4_ConfigurationComparison() {
        print("\n=== Example 4: Configuration Comparison ===\n")

        let levels: [ImageDifficultyLevel] = [.light, .medium, .hard, .extreme]

        for level in levels {
            let config = DifficultyConfiguration.forLevel(level)

            print("\n╔═══════════════════════════════════════════════════════╗")
            print("║ \(level.emoji) \(level.displayName.padding(toLength: 50, withPad: " ", startingAt: 0)) ║")
            print("╚═══════════════════════════════════════════════════════╝")
            print("")
            print(config.description)
            print("")
        }
    }

    // MARK: - Example 5: Batch Processing with Mixed Difficulties

    static func example5_BatchProcessing() {
        print("\n=== Example 5: Batch Processing with Mixed Difficulties ===\n")

        // Simulate mixed-difficulty images
        let imageSimulations = [
            ("Race Photo 1 - Close & Clear", ImageDifficultyLevel.light),
            ("Race Photo 2 - Medium Distance", ImageDifficultyLevel.medium),
            ("Race Photo 3 - Far & Blurry", ImageDifficultyLevel.hard),
            ("Race Photo 4 - Very Dark", ImageDifficultyLevel.extreme),
            ("Race Photo 5 - Backlit", ImageDifficultyLevel.hard)
        ]

        let pipeline = DifficultyAdaptiveFeedbackLoop()
        pipeline.autoDetectDifficulty = true

        var successCount = 0
        var totalTime: TimeInterval = 0
        var rescueCount = 0

        for (name, expectedDifficulty) in imageSimulations {
            print("\nProcessing: \(name)")
            print("  Expected Difficulty: \(expectedDifficulty.displayName)")

            // In real usage, load actual image here
            // For simulation, use example image
            guard let image = loadExampleImage(),
                  let cgImage = image.cgImage else {
                continue
            }

            if let result = pipeline.detectBibNumber(in: cgImage) {
                successCount += 1
                totalTime += result.totalProcessingTime
                if result.usedRescue {
                    rescueCount += 1
                }

                print("  ✓ Success!")
                print("    Bib: \(result.bibNumber)")
                print("    Iterations: \(result.iteration)")
                print("    Time: \(String(format: "%.3f", result.totalProcessingTime))s")
            } else {
                print("  ✗ Failed")
            }
        }

        print("\n╔═══════════════════════════════════════════════════════╗")
        print("║ BATCH SUMMARY                                          ║")
        print("╚═══════════════════════════════════════════════════════╝")
        print("")
        print("Total Images: \(imageSimulations.count)")
        print("Successful: \(successCount) (\(String(format: "%.0f%%", Float(successCount) / Float(imageSimulations.count) * 100)))")
        print("Rescued: \(rescueCount) (\(String(format: "%.0f%%", Float(rescueCount) / Float(successCount) * 100)) of successes)")
        print("Average Time: \(String(format: "%.3f", totalTime / TimeInterval(successCount)))s")
        print("")
    }

    // MARK: - Example 6: Real-World Scenarios

    static func example6_RealWorldScenarios() {
        print("\n=== Example 6: Real-World Race Photography Scenarios ===\n")

        let scenarios = [
            ("Finish Line (Close, Bright)", ImageDifficultyLevel.light, """
            Scenario: Professional finish line photo
            - People: 1-3m from camera
            - Lighting: Good (outdoor daylight or flash)
            - Expected: Bib clearly visible, large in frame
            → Light config: Fast processing, minimal rescue
            """),

            ("Mid-Race (Medium Distance)", ImageDifficultyLevel.medium, """
            Scenario: Mid-race candid shot
            - People: 5-10m from camera
            - Lighting: Varies (outdoor, some shadows)
            - Expected: Bibs visible but smaller
            → Medium config: Moderate upscaling, 2 rescue attempts
            """),

            ("Start Line Crowd (Distant, Cluttered)", ImageDifficultyLevel.hard, """
            Scenario: Start line with many runners
            - People: 10-20m from camera
            - Lighting: Challenging (early morning, backlighting)
            - Expected: Small bibs, occlusion, clutter
            → Hard config: Aggressive enhancement, 3 rescue attempts
            """),

            ("Trail Race (Poor Conditions)", ImageDifficultyLevel.extreme, """
            Scenario: Trail race in forest
            - People: Variable distance, motion
            - Lighting: Dappled shade, high contrast
            - Expected: Motion blur, dirt, small/occluded bibs
            → Extreme config: Maximum enhancement, all strategies
            """)
        ]

        for (name, level, description) in scenarios {
            print("\n╔═══════════════════════════════════════════════════════╗")
            print("║ \(name.padding(toLength: 54, withPad: " ", startingAt: 0)) ║")
            print("╚═══════════════════════════════════════════════════════╝")
            print("")
            print(description)

            let config = DifficultyConfiguration.forLevel(level)
            print("\nAdaptive Configuration:")
            print("  Max Iterations: \(config.maxFeedbackIterations)")
            print("  Upscaling: \(String(format: "%.1fx", config.upscaleFactor))")
            print("  Rescue Strategies: \(config.rescueStrategies.count)")
            print("  Time Budget: \(String(format: "%.1f", config.maxProcessingTime))s")
            print("")
        }
    }

    // MARK: - Example 7: Parameter Fine-Tuning Guide

    static func example7_ParameterFineTuning() {
        print("\n=== Example 7: Parameter Fine-Tuning Guide ===\n")

        print("""
        ╔════════════════════════════════════════════════════════════╗
        ║ PARAMETER FINE-TUNING BY DIFFICULTY LEVEL                 ║
        ╚════════════════════════════════════════════════════════════╝

        LIGHT DIFFICULTY (✅ Good Quality)
        ──────────────────────────────────
        Detection Strategy:
          • Person easily visible, good contrast
          • Minimal preprocessing needed
          • Fast OCR sufficient

        Fine-Tuned Parameters:
          ├─ Iterations: 1 (just 1 rescue)
          ├─ Min Confidence: 0.6 (expect high quality)
          ├─ Upscaling: 1.0x (no scaling)
          ├─ Contrast: 1.2x (light boost)
          ├─ Sharpness: 0.5 (light)
          ├─ OCR Passes: 3 (fast mode)
          ├─ Denoising: Off
          ├─ Binarization: Off
          └─ Time Budget: 1.0s

        Rescue Strategies:
          → [extremeContrast]

        ────────────────────────────────────────────────────────────

        MEDIUM DIFFICULTY (⚠️ Moderate Challenges)
        ──────────────────────────────────────────
        Detection Strategy:
          • Some distance or lighting challenges
          • Moderate enhancement needed
          • Standard OCR with fallbacks

        Fine-Tuned Parameters:
          ├─ Iterations: 2 (2 rescues)
          ├─ Min Confidence: 0.5
          ├─ Upscaling: 1.5x
          ├─ Contrast: 1.4x (moderate)
          ├─ Sharpness: 0.9 (moderate)
          ├─ OCR Passes: 4
          ├─ Denoising: On
          ├─ Binarization: Off
          ├─ Smart Scaling: On (1.2x multiplier)
          └─ Time Budget: 2.5s

        Rescue Strategies (ordered):
          1. extremeContrast
          2. multiScale
          3. adaptiveThreshold

        ────────────────────────────────────────────────────────────

        HARD DIFFICULTY (🔴 Difficult Conditions)
        ───────────────────────────────────────
        Detection Strategy:
          • Distant subjects or poor lighting
          • Aggressive enhancement required
          • Full OCR pipeline

        Fine-Tuned Parameters:
          ├─ Iterations: 3 (3 rescues)
          ├─ Min Confidence: 0.4 (accept lower)
          ├─ Upscaling: 3.0x (aggressive)
          ├─ Contrast: 1.8x (high)
          ├─ Sharpness: 1.3 (high)
          ├─ OCR Passes: 5 (all passes)
          ├─ Denoising: On
          ├─ Binarization: On
          ├─ Smart Scaling: On (1.5x multiplier)
          ├─ Early Exit: Off (try all)
          └─ Time Budget: 5.0s

        Rescue Strategies (ordered):
          1. multiScale (upscale first for distant)
          2. extremeContrast
          3. denoiseHeavy
          4. adaptiveThreshold
          5. invertColors

        ────────────────────────────────────────────────────────────

        EXTREME DIFFICULTY (💀 Very Difficult)
        ──────────────────────────────────────
        Detection Strategy:
          • Multiple severe challenges
          • Maximum enhancement
          • Accept even low confidence results

        Fine-Tuned Parameters:
          ├─ Iterations: 4 (maximum)
          ├─ Min Confidence: 0.35 (very low threshold)
          ├─ Upscaling: 6.0x (maximum!)
          ├─ Contrast: 2.5x (extreme)
          ├─ Sharpness: 1.8 (maximum)
          ├─ OCR Passes: 5 (all passes)
          ├─ Denoising: On
          ├─ Binarization: On
          ├─ Smart Scaling: On (2.0x multiplier)
          ├─ Early Exit: Off
          └─ Time Budget: 10.0s (take our time)

        Rescue Strategies (ordered):
          1. combinedRescue (try everything first!)
          2. multiScale
          3. denoiseHeavy
          4. extremeContrast
          5. adaptiveThreshold
          6. invertColors

        ════════════════════════════════════════════════════════════
        """)
    }

    // MARK: - Example 8: Custom Difficulty Thresholds

    static func example8_CustomThresholds() {
        print("\n=== Example 8: Custom Difficulty Thresholds ===\n")

        let analyzer = ImageDifficultyAnalyzer()

        // Customize thresholds for your specific use case
        analyzer.thresholds.lightMinBrightness = 0.4      // Higher threshold for "light"
        analyzer.thresholds.lightMinPersonSize = 0.20     // Require larger person for "light"
        analyzer.thresholds.mediumMinSharpness = 0.4      // Higher sharpness needed

        print("Custom Thresholds Set:")
        print("  Light Min Brightness: \(analyzer.thresholds.lightMinBrightness)")
        print("  Light Min Person Size: \(String(format: "%.0f%%", analyzer.thresholds.lightMinPersonSize * 100))")
        print("  Medium Min Sharpness: \(analyzer.thresholds.mediumMinSharpness)")
        print("")

        // Test with image
        guard let image = loadExampleImage(),
              let cgImage = image.cgImage else {
            return
        }

        let (level, metrics) = analyzer.analyzeDifficulty(cgImage)

        print("Analysis Result:")
        print("  Detected Level: \(level.emoji) \(level.displayName)")
        print("  Brightness: \(String(format: "%.2f", metrics.averageBrightness))")
        print("  Sharpness: \(String(format: "%.2f", metrics.sharpness))")
        if let size = metrics.largestPersonSize {
            print("  Person Size: \(String(format: "%.1f%%", size * 100))")
        }
    }

    // MARK: - Utility

    static func loadExampleImage() -> PlatformImage? {
        #if os(macOS)
        return NSImage(size: NSSize(width: 1920, height: 1080))
        #else
        return UIImage(systemName: "person.fill")
        #endif
    }

    // MARK: - Run All Examples

    static func runAll() {
        example1_AutoMode()
        example2_ManualDifficultyLevels()
        example3_DifficultyAnalysis()
        example4_ConfigurationComparison()
        example5_BatchProcessing()
        example6_RealWorldScenarios()
        example7_ParameterFineTuning()
        example8_CustomThresholds()
    }
}

// MARK: - Quick Reference

/*
 QUICK REFERENCE GUIDE
 ═══════════════════════════════════════════════════════════════

 WHEN TO USE EACH MODE:
 ──────────────────────

 AUTO MODE (Recommended for production):
   let pipeline = DifficultyAdaptiveFeedbackLoop()
   pipeline.autoDetectDifficulty = true
   let result = pipeline.detectBibNumber(in: image)

 MANUAL LIGHT (Known easy images):
   pipeline.autoDetectDifficulty = false
   pipeline.manualDifficultyLevel = .light

 MANUAL MEDIUM (Moderate quality):
   pipeline.manualDifficultyLevel = .medium

 MANUAL HARD (Known difficult):
   pipeline.manualDifficultyLevel = .hard

 MANUAL EXTREME (Very challenging):
   pipeline.manualDifficultyLevel = .extreme

 ═══════════════════════════════════════════════════════════════

 PARAMETER SUMMARY BY DIFFICULTY:
 ─────────────────────────────────

 | Parameter       | Light | Medium | Hard  | Extreme |
 |-----------------|-------|--------|-------|---------|
 | Iterations      | 1     | 2      | 3     | 4       |
 | Min Confidence  | 0.60  | 0.50   | 0.40  | 0.35    |
 | Upscaling       | 1.0x  | 1.5x   | 3.0x  | 6.0x    |
 | Contrast Boost  | 1.2x  | 1.4x   | 1.8x  | 2.5x    |
 | Sharpness       | 0.5   | 0.9    | 1.3   | 1.8     |
 | OCR Passes      | 3     | 4      | 5     | 5       |
 | Denoising       | Off   | On     | On    | On      |
 | Binarization    | Off   | Off    | On    | On      |
 | Time Budget     | 1.0s  | 2.5s   | 5.0s  | 10.0s   |
 | Strategies      | 1     | 3      | 5     | 6 (all) |

 ═══════════════════════════════════════════════════════════════

 Usage:

 // Run all examples
 DifficultyAdaptiveExamples.runAll()

 // Or run specific examples
 DifficultyAdaptiveExamples.example1_AutoMode()
 DifficultyAdaptiveExamples.example7_ParameterFineTuning()
 */
