//
//  SmartScalingExamples.swift
//  Apple Vision Framework - Smart Scaling Usage Examples
//
//  Examples showing how to use smart scaling for different scenarios
//

import CoreGraphics
import Foundation

#if os(macOS)
import AppKit
#else
import UIKit
#endif

class SmartScalingExamples {

    // MARK: - Example 1: Basic Smart Scaling

    /// Example: Detect bib with automatic smart scaling
    func basicSmartScaling(image: CGImage) {
        print("=== Basic Smart Scaling Example ===\n")

        // Step 1: Detect person and pose
        let poseManager = PoseEstimationManager()
        guard let poses = try? poseManager.detectBodyPose(in: image),
              let pose = poses.first else {
            print("No pose detected")
            return
        }

        // Step 2: Extract torso region
        let torsoManager = TorsoRegionManager()
        guard let bibRegion = torsoManager.getPrimaryBibRegion(from: pose) else {
            print("No torso region found")
            return
        }

        // Step 3: Analyze and scale intelligently
        let scalingManager = SmartScalingManager()
        let imageSize = CGSize(width: image.width, height: image.height)

        // Print analysis
        scalingManager.printScalingAnalysis(region: bibRegion, imageSize: imageSize)

        // Scale for OCR
        guard let scaledImage = scalingManager.scaleForOCR(
            image: image,
            region: bibRegion,
            mode: .intelligent
        ) else {
            print("Scaling failed")
            return
        }

        print("✓ Scaled to: \(scaledImage.width)x\(scaledImage.height) pixels")
        print("  Ready for OCR processing")

        print("\n===================================\n")
    }

    // MARK: - Example 2: Handling Different Distances

    /// Example: Process images at different distances
    func handleDifferentDistances(images: [(name: String, image: CGImage)]) {
        print("=== Different Distance Scenarios ===\n")

        let scalingManager = SmartScalingManager()
        let poseManager = PoseEstimationManager()
        let torsoManager = TorsoRegionManager()

        for (name, image) in images {
            print("Processing: \(name)")

            guard let poses = try? poseManager.detectBodyPose(in: image),
                  let pose = poses.first,
                  let bibRegion = torsoManager.getPrimaryBibRegion(from: pose) else {
                print("  ✗ No detection")
                continue
            }

            let imageSize = CGSize(width: image.width, height: image.height)
            let metrics = scalingManager.analyzeRegionQuality(
                region: bibRegion,
                imageSize: imageSize
            )

            print("  Distance: \(metrics.distanceCategory)")
            print("  Current: \(Int(metrics.resolution.width))x\(Int(metrics.resolution.height))")
            print("  Scale: \(String(format: "%.2fx", metrics.recommendedScale))")
            print("  DPI: \(String(format: "%.1f", metrics.estimatedDPI))")

            // Apply smart scaling
            if let scaled = scalingManager.scaleForOCR(image: image, region: bibRegion) {
                print("  ✓ Scaled: \(scaled.width)x\(scaled.height)")
            }

            print()
        }

        print("====================================\n")
    }

    // MARK: - Example 3: Batch Processing with Scaling

    /// Example: Batch process race photos with smart scaling
    func batchProcessWithScaling(images: [CGImage]) {
        print("=== Batch Processing with Smart Scaling ===\n")

        let scalingManager = SmartScalingManager()
        let poseManager = PoseEstimationManager()
        let torsoManager = TorsoRegionManager()

        var stats: [DistanceCategory: Int] = [:]
        var totalScaled = 0

        for (index, image) in images.enumerated() {
            print("Image \(index + 1)/\(images.count)...")

            guard let poses = try? poseManager.detectBodyPose(in: image) else {
                continue
            }

            for pose in poses {
                guard let bibRegion = torsoManager.getPrimaryBibRegion(from: pose) else {
                    continue
                }

                let imageSize = CGSize(width: image.width, height: image.height)
                let metrics = scalingManager.analyzeRegionQuality(
                    region: bibRegion,
                    imageSize: imageSize
                )

                // Track statistics
                stats[metrics.distanceCategory, default: 0] += 1

                if let _ = scalingManager.scaleForOCR(image: image, region: bibRegion) {
                    totalScaled += 1
                }
            }
        }

        print("\n=== Statistics ===")
        print("Total images processed: \(images.count)")
        print("Total regions scaled: \(totalScaled)")
        print("\nDistance distribution:")
        for (category, count) in stats.sorted(by: { $0.value > $1.value }) {
            print("  \(category): \(count)")
        }

        print("\n============================================\n")
    }

    // MARK: - Example 4: Scale Mode Comparison

    /// Example: Compare different scaling modes
    func compareScalingModes(image: CGImage, bibRegion: BibDetectionRegion) {
        print("=== Scaling Mode Comparison ===\n")

        let scalingManager = SmartScalingManager()
        let modes: [ScalingMode] = [.aspectFit, .aspectFill, .scaleToFill, .intelligent]

        for mode in modes {
            guard let scaled = scalingManager.scaleForOCR(
                image: image,
                region: bibRegion,
                mode: mode
            ) else {
                print("Mode \(mode): Failed")
                continue
            }

            print("Mode: \(mode)")
            print("  Result: \(scaled.width)x\(scaled.height)")
            print("  Aspect Ratio: \(String(format: "%.2f", Float(scaled.width) / Float(scaled.height)))")
            print()
        }

        print("================================\n")
    }

    // MARK: - Example 5: Integration with OCR

    /// Example: Complete pipeline with smart scaling and OCR
    func completeOCRPipeline(image: CGImage) {
        print("=== Complete OCR Pipeline with Smart Scaling ===\n")

        // Step 1: Detect pose
        print("Step 1: Detecting pose...")
        let poseManager = PoseEstimationManager()
        guard let poses = try? poseManager.detectBodyPose(in: image),
              let pose = poses.first else {
            print("  ✗ No pose detected")
            return
        }
        print("  ✓ Pose detected")

        // Step 2: Extract torso region
        print("\nStep 2: Extracting torso region...")
        let torsoManager = TorsoRegionManager()
        guard let bibRegion = torsoManager.getPrimaryBibRegion(from: pose) else {
            print("  ✗ No torso region")
            return
        }
        print("  ✓ Region: \(bibRegion.zone.rawValue)")

        // Step 3: Analyze image quality
        print("\nStep 3: Analyzing image quality...")
        let scalingManager = SmartScalingManager()
        let imageSize = CGSize(width: image.width, height: image.height)
        let metrics = scalingManager.analyzeRegionQuality(
            region: bibRegion,
            imageSize: imageSize
        )

        print("  Distance: \(metrics.distanceCategory)")
        print("  Current resolution: \(Int(metrics.resolution.width))x\(Int(metrics.resolution.height))")
        print("  DPI: \(String(format: "%.1f", metrics.estimatedDPI))")
        print("  OCR Ready: \(metrics.isOCRReady ? "Yes" : "No")")

        // Step 4: Smart scaling
        print("\nStep 4: Smart scaling...")
        guard let scaledImage = scalingManager.scaleForOCR(
            image: image,
            region: bibRegion,
            mode: .intelligent
        ) else {
            print("  ✗ Scaling failed")
            return
        }
        print("  ✓ Scaled: \(scaledImage.width)x\(scaledImage.height)")
        print("  Scale factor: \(String(format: "%.2fx", metrics.recommendedScale))")

        // Step 5: OCR (using Vision framework)
        print("\nStep 5: Performing OCR...")
        // OCR would be performed here using the scaled image
        print("  → Using scaled and enhanced image for OCR")
        print("  → Image optimized for text recognition")

        print("\n================================================\n")
    }

    // MARK: - Example 6: Handling Edge Cases

    /// Example: Handle edge cases (very close, very far, partial body)
    func handleEdgeCases(image: CGImage) {
        print("=== Handling Edge Cases ===\n")

        let poseManager = PoseEstimationManager()
        let torsoManager = TorsoRegionManager()
        let scalingManager = SmartScalingManager()

        guard let poses = try? poseManager.detectBodyPose(in: image) else {
            print("No poses detected")
            return
        }

        for (index, pose) in poses.enumerated() {
            print("Person \(index):")

            // Try all zones (in case of partial body)
            let allRegions = torsoManager.getAllBibRegions(from: pose)

            if allRegions.isEmpty {
                print("  ⚠️  No torso regions detected (possible partial body)")
                print("  → Try adjusting joint confidence threshold")
                continue
            }

            for region in allRegions {
                let imageSize = CGSize(width: image.width, height: image.height)
                let metrics = scalingManager.analyzeRegionQuality(
                    region: region,
                    imageSize: imageSize
                )

                print("  Region: \(region.zone.rawValue)")

                // Handle edge cases
                switch metrics.distanceCategory {
                case .veryClose:
                    print("    ⚠️  Very close - may have partial body")
                    print("    → Check if bib is fully visible")
                    print("    → Consider using wider field of view")

                case .veryFar:
                    print("    ⚠️  Very far - aggressive upscaling needed")
                    print("    → \(String(format: "%.1fx", metrics.recommendedScale)) upscaling")
                    print("    → May benefit from super-resolution")
                    print("    → OCR confidence may be lower")

                default:
                    print("    ✓ Normal distance")
                }

                // Apply scaling
                if let scaled = scalingManager.scaleForOCR(image: image, region: region) {
                    print("    Scaled: \(scaled.width)x\(scaled.height)")
                } else {
                    print("    ✗ Scaling failed")
                }
            }

            print()
        }

        print("===========================\n")
    }

    // MARK: - Example 7: Custom Scaling Configuration

    /// Example: Configure scaling manager for specific scenarios
    func customScalingConfiguration() {
        print("=== Custom Scaling Configuration ===\n")

        // Scenario 1: High-quality finish line photos
        let highQualityManager = SmartScalingManager()
        highQualityManager.targetBibHeight = 200.0      // Higher target
        highQualityManager.minimumDPI = 200.0           // Stricter quality
        highQualityManager.enableEnhancement = true
        highQualityManager.useHighQualityUpscaling = true

        print("High-Quality Configuration:")
        print("  Target height: \(highQualityManager.targetBibHeight)px")
        print("  Minimum DPI: \(highQualityManager.minimumDPI)")
        print("  Enhancement: \(highQualityManager.enableEnhancement)")
        print()

        // Scenario 2: Fast real-time processing
        let realtimeManager = SmartScalingManager()
        realtimeManager.targetBibHeight = 100.0         // Lower target for speed
        realtimeManager.minimumDPI = 100.0              // More lenient
        realtimeManager.enableEnhancement = false       // Skip for speed
        realtimeManager.useHighQualityUpscaling = false // Faster interpolation

        print("Real-Time Configuration:")
        print("  Target height: \(realtimeManager.targetBibHeight)px")
        print("  Minimum DPI: \(realtimeManager.minimumDPI)")
        print("  Enhancement: \(realtimeManager.enableEnhancement)")
        print()

        // Scenario 3: Action shots / low quality
        let actionManager = SmartScalingManager()
        actionManager.targetBibHeight = 180.0
        actionManager.minimumBibHeight = 30.0           // More lenient minimum
        actionManager.maximumBibHeight = 500.0          // Allow more upscaling
        actionManager.enableEnhancement = true          // Critical for quality

        print("Action Shot Configuration:")
        print("  Target height: \(actionManager.targetBibHeight)px")
        print("  Min height: \(actionManager.minimumBibHeight)px")
        print("  Max height: \(actionManager.maximumBibHeight)px")
        print("  Enhancement: \(actionManager.enableEnhancement)")

        print("\n====================================\n")
    }

    // MARK: - Example 8: Performance Comparison

    /// Example: Compare performance with and without smart scaling
    func performanceComparison(image: CGImage) {
        print("=== Performance Comparison ===\n")

        let poseManager = PoseEstimationManager()
        let torsoManager = TorsoRegionManager()
        let scalingManager = SmartScalingManager()

        guard let poses = try? poseManager.detectBodyPose(in: image),
              let pose = poses.first,
              let bibRegion = torsoManager.getPrimaryBibRegion(from: pose) else {
            print("Detection failed")
            return
        }

        // Without scaling
        let startNoScale = Date()
        let _ = TorsoRegionManager.cropToBibRegion(image: image, region: bibRegion)
        let timeNoScale = Date().timeIntervalSince(startNoScale)

        // With smart scaling
        let startWithScale = Date()
        let _ = scalingManager.scaleForOCR(image: image, region: bibRegion)
        let timeWithScale = Date().timeIntervalSince(startWithScale)

        print("Without Smart Scaling: \(String(format: "%.2f", timeNoScale * 1000))ms")
        print("With Smart Scaling: \(String(format: "%.2f", timeWithScale * 1000))ms")
        print("Overhead: \(String(format: "%.2f", (timeWithScale - timeNoScale) * 1000))ms")

        let imageSize = CGSize(width: image.width, height: image.height)
        let metrics = scalingManager.analyzeRegionQuality(region: bibRegion, imageSize: imageSize)

        print("\nBenefit:")
        if metrics.isOCRReady {
            print("  Already optimal - scaling overhead minimal")
        } else {
            print("  OCR accuracy improvement: Significant")
            print("  Recommended for: \(metrics.distanceCategory)")
        }

        print("\n==============================\n")
    }
}

// MARK: - Usage Guide

/*
 SMART SCALING USAGE GUIDE
 =========================

 1. BASIC USAGE:
 ---------------
 let scalingManager = SmartScalingManager()
 let scaledImage = scalingManager.scaleForOCR(
     image: sourceImage,
     region: bibRegion,
     mode: .intelligent
 )

 2. SCALING MODES:
 ----------------
 • .aspectFit      - Fit within target, maintain aspect ratio (no distortion)
 • .aspectFill     - Fill target, maintain aspect ratio (may crop edges)
 • .scaleToFill    - Stretch to fill exactly (may distort)
 • .intelligent    - Automatic mode based on analysis (RECOMMENDED)

 3. DISTANCE CATEGORIES:
 ----------------------
 • veryClose (>80%)  - Partial body, minimal scaling
 • close (40-80%)    - Full body, good size
 • medium (20-40%)   - Normal distance, moderate scaling
 • far (5-20%)       - Small in frame, aggressive scaling
 • veryFar (<5%)     - Very small, maximum scaling

 4. CONFIGURATION:
 ----------------
 scalingManager.targetBibHeight = 150.0     // Target height in pixels
 scalingManager.minimumDPI = 150.0          // Minimum quality threshold
 scalingManager.enableEnhancement = true    // Enable sharpening/contrast
 scalingManager.useHighQualityUpscaling = true  // High-quality interpolation

 5. BEST PRACTICES:
 -----------------
 • Use .intelligent mode for unknown scenarios
 • Enable enhancement for far distances
 • Disable enhancement for real-time (speed)
 • Target height: 100-200px for bibs
 • Minimum DPI: 150 for acceptable OCR
 • Target DPI: 300 for optimal OCR

 6. IMAGE ENHANCEMENT:
 --------------------
 Automatic enhancements applied:
 • Sharpness increase (0.7 factor)
 • Contrast boost (1.2x)
 • Maintains brightness and saturation
 • Optional grayscale conversion (commented out)

 7. PERFORMANCE:
 --------------
 • No scaling needed: ~5ms overhead
 • 2x upscaling: ~15-30ms
 • 4x upscaling: ~30-50ms
 • With enhancement: +10-20ms

 8. OCR OPTIMIZATION:
 -------------------
 Optimal for OCR:
 • Bib height: 100-200 pixels
 • DPI: 200-300
 • Character size: 30-50 pixels
 • Sharp, high contrast

 9. TROUBLESHOOTING:
 ------------------
 • OCR fails on far subjects → Increase maxScaleFactor
 • Blurry upscaling → Enable enhancement
 • Too slow → Reduce target size, disable enhancement
 • Distorted images → Use .aspectFit instead of .scaleToFill
*/
