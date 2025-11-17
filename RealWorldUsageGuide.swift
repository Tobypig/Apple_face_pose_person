//
//  RealWorldUsageGuide.swift
//  Apple Vision Framework - Real-World Usage Guide
//
//  Practical examples showing how to use the bib detection system
//  in real-world scenarios with all features integrated
//

import Foundation
import CoreGraphics

#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

// MARK: - Real-World Usage Guide

/**
 # Real-World Bib Detection Usage Guide

 This guide shows practical examples of using the bib detection system
 in various real-world scenarios, from simple to advanced.

 ## Scenarios Covered:
 1. Simple Single-Image Detection (Beginner)
 2. Batch Processing Race Photos (Intermediate)
 3. Real-Time Video Processing (Advanced)
 4. High-Performance Production System (Expert)
 5. Difficult Image Handling (Rescue Scenarios)
 */

// MARK: - Scenario 1: Simple Single-Image Detection

/**
 ## Scenario 1: Simple Single-Image Detection

 **Use Case:** Detect a bib number from a single race photo
 **Difficulty:** Beginner
 **Expected Time:** 100-300ms
 **Best For:** Quick one-off detections, testing, simple applications
 */

class SimpleBibDetection {

    func detectBibNumber(from imagePath: String) -> String? {
        print("=" * 60)
        print("Simple Bib Detection")
        print("=" * 60)
        print()

        // Step 1: Load image
        print("Step 1: Loading image...")
        guard let image = loadImage(from: imagePath) else {
            print("❌ Failed to load image")
            return nil
        }
        print("✅ Image loaded")

        // Step 2: Detect pose
        print("\nStep 2: Detecting pose...")
        let poseDetector = PoseEstimator()
        guard let pose = poseDetector.detectPose(in: image) else {
            print("❌ No pose detected")
            return nil
        }
        print("✅ Pose detected (confidence: \(String(format: "%.2f", pose.confidence)))")

        // Step 3: Detect bib with parallel processing (fastest + accurate)
        print("\nStep 3: Detecting bib number...")
        let result = ParallelZoneProcessor.detect(in: image, pose: pose)

        if let bib = result {
            print("✅ Bib number detected: \(bib.number)")
            print("   Confidence: \(String(format: "%.2f", bib.confidence))")
            return bib.number
        } else {
            print("❌ No bib detected")
            return nil
        }
    }

    private func loadImage(from path: String) -> CGImage? {
        #if os(macOS)
        guard let nsImage = NSImage(contentsOfFile: path) else { return nil }
        var imageRect = CGRect(x: 0, y: 0, width: nsImage.size.width, height: nsImage.size.height)
        return nsImage.cgImage(forProposedRect: &imageRect, context: nil, hints: nil)
        #else
        guard let uiImage = UIImage(contentsOfFile: path) else { return nil }
        return uiImage.cgImage
        #endif
    }
}

// MARK: - Scenario 2: Batch Processing Race Photos

/**
 ## Scenario 2: Batch Processing Race Photos

 **Use Case:** Process hundreds/thousands of race photos from a marathon
 **Difficulty:** Intermediate
 **Expected Time:** 50-100ms per image (with parallel processing)
 **Best For:** Post-race photo tagging, race timing systems, photo services
 */

class BatchRacePhotoProcessor {

    struct ProcessingResult {
        let imagePath: String
        let bibNumber: String?
        let confidence: Float?
        let processingTime: TimeInterval
        let success: Bool
    }

    func processBatchOfPhotos(imagePaths: [String], maxConcurrent: Int = 4) -> [ProcessingResult] {
        print("=" * 60)
        print("Batch Race Photo Processing")
        print("=" * 60)
        print()
        print("Total images: \(imagePaths.count)")
        print("Max concurrent: \(maxConcurrent)")
        print()

        var results: [ProcessingResult] = []
        let semaphore = DispatchSemaphore(value: maxConcurrent)
        let queue = DispatchQueue(label: "com.raceprocessing.batch", attributes: .concurrent)
        let dispatchGroup = DispatchGroup()
        let resultsLock = NSLock()

        let startTime = Date()

        // Process each image
        for (index, path) in imagePaths.enumerated() {
            dispatchGroup.enter()
            semaphore.wait()

            queue.async {
                let result = self.processingleImage(path: path, index: index + 1, total: imagePaths.count)

                resultsLock.lock()
                results.append(result)
                resultsLock.unlock()

                semaphore.signal()
                dispatchGroup.leave()
            }
        }

        // Wait for all to complete
        dispatchGroup.wait()

        let totalTime = Date().timeIntervalSince(startTime)

        // Print summary
        printBatchSummary(results: results, totalTime: totalTime)

        return results
    }

    private func processingleImage(path: String, index: Int, total: Int) -> ProcessingResult {
        let startTime = Date()

        print("[\(index)/\(total)] Processing: \(URL(fileURLWithPath: path).lastPathComponent)")

        // Load image
        guard let image = loadImage(from: path) else {
            return ProcessingResult(
                imagePath: path,
                bibNumber: nil,
                confidence: nil,
                processingTime: Date().timeIntervalSince(startTime),
                success: false
            )
        }

        // Detect pose
        let poseDetector = PoseEstimator()
        guard let pose = poseDetector.detectPose(in: image) else {
            return ProcessingResult(
                imagePath: path,
                bibNumber: nil,
                confidence: nil,
                processingTime: Date().timeIntervalSince(startTime),
                success: false
            )
        }

        // Smart detection (parallel if 2+ reliable zones)
        let smartProcessor = SmartConfidenceProcessor()
        let (result, _) = smartProcessor.detectSmart(in: image, pose: pose)

        let processingTime = Date().timeIntervalSince(startTime)

        if let bib = result {
            print("  ✅ \(bib.number) (\(String(format: "%.0f", processingTime * 1000))ms)")
        } else {
            print("  ❌ Not detected (\(String(format: "%.0f", processingTime * 1000))ms)")
        }

        return ProcessingResult(
            imagePath: path,
            bibNumber: result?.number,
            confidence: result?.confidence,
            processingTime: processingTime,
            success: result != nil
        )
    }

    private func printBatchSummary(results: [ProcessingResult], totalTime: TimeInterval) {
        let successCount = results.filter { $0.success }.count
        let avgTime = results.map { $0.processingTime }.reduce(0, +) / Double(results.count)

        print()
        print("=" * 60)
        print("Batch Processing Summary")
        print("=" * 60)
        print()
        print("Total Images: \(results.count)")
        print("Successful: \(successCount)")
        print("Success Rate: \(String(format: "%.1f%%", Float(successCount) / Float(results.count) * 100))")
        print("Total Time: \(String(format: "%.1f", totalTime))s")
        print("Avg Time: \(String(format: "%.0f", avgTime * 1000))ms/image")
        print("Throughput: \(String(format: "%.1f", Double(results.count) / totalTime)) images/sec")
        print()
    }

    private func loadImage(from path: String) -> CGImage? {
        #if os(macOS)
        guard let nsImage = NSImage(contentsOfFile: path) else { return nil }
        var imageRect = CGRect(x: 0, y: 0, width: nsImage.size.width, height: nsImage.size.height)
        return nsImage.cgImage(forProposedRect: &imageRect, context: nil, hints: nil)
        #else
        guard let uiImage = UIImage(contentsOfFile: path) else { return nil }
        return uiImage.cgImage
        #endif
    }
}

// MARK: - Scenario 3: Real-Time Video Processing

/**
 ## Scenario 3: Real-Time Video Processing

 **Use Case:** Real-time bib detection from video feed (finish line camera)
 **Difficulty:** Advanced
 **Expected Time:** 40-80ms per frame (targeting 12-25 FPS)
 **Best For:** Live race timing, finish line detection, streaming systems
 */

class RealTimeVideoProcessor {

    private var frameCount: Int = 0
    private var detectionCount: Int = 0
    private var totalProcessingTime: TimeInterval = 0

    // Frame skip strategy (process every Nth frame)
    var frameSkip: Int = 2  // Process every 2nd frame

    func processVideoFrame(_ frame: CGImage) -> String? {
        frameCount += 1

        // Skip frames for performance
        guard frameCount % frameSkip == 0 else {
            return nil
        }

        let startTime = Date()

        // Fast pose detection
        let poseDetector = PoseEstimator()
        guard let pose = poseDetector.detectPose(in: frame) else {
            return nil
        }

        // Use confidence-weighted for speed (skips low-confidence zones)
        let detector = ConfidenceWeightedBibDetector()
        detector.minimumZoneConfidence = 0.5  // Higher threshold for speed
        detector.enableFallback = false  // Disable fallback for speed
        detector.verboseLogging = false

        let (result, _) = detector.detectWithConfidenceWeighting(in: frame, pose: pose)

        let processingTime = Date().timeIntervalSince(startTime)
        totalProcessingTime += processingTime

        if let bib = result {
            detectionCount += 1
            let fps = 1.0 / processingTime
            print("Frame \(frameCount): \(bib.number) (\(String(format: "%.1f", fps)) FPS)")
            return bib.number
        }

        return nil
    }

    func getStatistics() -> String {
        let avgTime = totalProcessingTime / Double(frameCount / frameSkip)
        let avgFPS = 1.0 / avgTime
        let detectionRate = Float(detectionCount) / Float(frameCount / frameSkip)

        return """
        Video Processing Statistics:
          Frames Processed: \(frameCount / frameSkip)
          Detections: \(detectionCount)
          Detection Rate: \(String(format: "%.1f%%", detectionRate * 100))
          Avg Processing Time: \(String(format: "%.0f", avgTime * 1000))ms
          Avg FPS: \(String(format: "%.1f", avgFPS))
        """
    }
}

// MARK: - Scenario 4: High-Performance Production System

/**
 ## Scenario 4: High-Performance Production System

 **Use Case:** Professional race timing system with maximum accuracy + speed
 **Difficulty:** Expert
 **Expected Time:** 50-150ms (depending on difficulty)
 **Best For:** Professional timing companies, large events, mission-critical systems
 */

class ProductionBibDetectionSystem {

    // MARK: - Configuration

    enum QualityPreset {
        case speed      // Fastest, good accuracy (50-80ms)
        case balanced   // Balance speed + accuracy (80-120ms)
        case accuracy   // Maximum accuracy (120-200ms)

        var description: String {
            switch self {
            case .speed: return "Speed (50-80ms)"
            case .balanced: return "Balanced (80-120ms)"
            case .accuracy: return "Accuracy (120-200ms)"
            }
        }
    }

    private let qualityPreset: QualityPreset

    init(qualityPreset: QualityPreset = .balanced) {
        self.qualityPreset = qualityPreset
    }

    // MARK: - Detection Pipeline

    func detectBibNumber(from image: CGImage) -> BibNumberResult? {
        let startTime = Date()

        // Step 1: Pose detection
        guard let pose = detectPose(in: image) else {
            return nil
        }

        // Step 2: Select detection strategy based on preset
        let result: BibNumberResult?

        switch qualityPreset {
        case .speed:
            result = speedOptimizedDetection(image: image, pose: pose)

        case .balanced:
            result = balancedDetection(image: image, pose: pose)

        case .accuracy:
            result = accuracyOptimizedDetection(image: image, pose: pose)
        }

        let processingTime = Date().timeIntervalSince(startTime)

        if let bib = result {
            print("✅ Detected: \(bib.number) (conf: \(String(format: "%.2f", bib.confidence)), time: \(String(format: "%.0f", processingTime * 1000))ms)")
        }

        return result
    }

    // MARK: - Detection Strategies

    private func speedOptimizedDetection(image: CGImage, pose: PoseEstimationResult) -> BibNumberResult? {
        // Strategy: Confidence-weighted (skip low-confidence zones) + fast text localization
        let detector = ConfidenceWeightedBibDetector()
        detector.detectionMethod = .textLocalization  // Fastest method
        detector.minimumZoneConfidence = 0.5
        detector.enableFallback = false  // No fallback for speed
        detector.verboseLogging = false

        let (result, _) = detector.detectWithConfidenceWeighting(in: image, pose: pose)
        return result
    }

    private func balancedDetection(image: CGImage, pose: PoseEstimationResult) -> BibNumberResult? {
        // Strategy: Smart parallel with language hints
        let smartProcessor = SmartConfidenceProcessor()
        smartProcessor.minimumZoneConfidence = 0.4
        smartProcessor.useParallelForHighConfidence = true

        let (result, _) = smartProcessor.detectSmart(in: image, pose: pose)
        return result
    }

    private func accuracyOptimizedDetection(image: CGImage, pose: PoseEstimationResult) -> BibNumberResult? {
        // Strategy: Adaptive expansion with language hints + fallback chain

        // Try 1: Parallel with language hints
        let parallel = ParallelZoneProcessor()
        parallel.detectionMethod = .languageHints
        parallel.verboseLogging = false

        let (result1, _) = parallel.detectInParallel(in: image, pose: pose)
        if let result = result1, result.confidence >= 0.8 {
            return result  // High confidence, accept
        }

        // Try 2: Adaptive expansion if needed
        let adaptive = AdaptiveTorsoExpander()
        adaptive.enableColorPreDetection = true
        let result2 = adaptive.detectWithAdaptiveExpansion(in: image, pose: pose)

        if result2.success {
            return result2.bibNumber
        }

        // Return best result
        return result1
    }

    private func detectPose(in image: CGImage) -> PoseEstimationResult? {
        let poseDetector = PoseEstimator()
        return poseDetector.detectPose(in: image)
    }
}

// MARK: - Scenario 5: Difficult Image Handling

/**
 ## Scenario 5: Difficult Image Handling (Rescue Mode)

 **Use Case:** Handle very difficult images (blurry, occluded, poor lighting)
 **Difficulty:** Expert
 **Expected Time:** 200-500ms (thorough processing)
 **Best For:** Rescue processing, quality assurance, missed detections
 */

class DifficultImageProcessor {

    func processDifficultImage(image: CGImage) -> BibNumberResult? {
        print("=" * 60)
        print("Difficult Image Processing (Rescue Mode)")
        print("=" * 60)
        print()

        guard let pose = detectPose(in: image) else {
            print("❌ Pose detection failed - image too difficult")
            return nil
        }

        // Strategy 1: Try all methods and vote
        print("Strategy 1: Multi-Method Voting")
        var candidates: [(result: BibNumberResult, method: String)] = []

        // Method 1: Text localization
        if let result = tryTextLocalization(image: image, pose: pose) {
            candidates.append((result, "Text Localization"))
        }

        // Method 2: Color-based
        if let result = tryColorBased(image: image, pose: pose) {
            candidates.append((result, "Color-Based"))
        }

        // Method 3: Language hints
        if let result = tryLanguageHints(image: image, pose: pose) {
            candidates.append((result, "Language Hints"))
        }

        // Method 4: Adaptive expansion
        if let result = tryAdaptiveExpansion(image: image, pose: pose) {
            candidates.append((result, "Adaptive Expansion"))
        }

        // Method 5: Multi-scale
        if let result = tryMultiScale(image: image, pose: pose) {
            candidates.append((result, "Multi-Scale"))
        }

        // Vote on results
        print("\nVoting on \(candidates.count) candidates:")
        for (result, method) in candidates {
            print("  \(method): \(result.number) (conf: \(String(format: "%.2f", result.confidence)))")
        }

        // Find consensus
        let voteCounts = Dictionary(grouping: candidates, by: { $0.result.number })
            .mapValues { $0.count }

        if let (bibNumber, voteCount) = voteCounts.max(by: { $0.value < $1.value }), voteCount >= 2 {
            // Found consensus (2+ methods agree)
            let consensusResults = candidates.filter { $0.result.number == bibNumber }
            let avgConfidence = consensusResults.map { $0.result.confidence }.reduce(0, +) / Float(consensusResults.count)

            print("\n✅ Consensus: \(bibNumber) (\(voteCount) votes, avg conf: \(String(format: "%.2f", avgConfidence)))")

            return BibNumberResult(
                number: bibNumber,
                confidence: avgConfidence,
                boundingBox: consensusResults.first!.result.boundingBox
            )
        } else if let best = candidates.max(by: { $0.result.confidence < $1.result.confidence }) {
            // No consensus, use highest confidence
            print("\n⚠️  No consensus, using highest confidence: \(best.result.number)")
            return best.result
        }

        print("\n❌ All methods failed")
        return nil
    }

    private func detectPose(in image: CGImage) -> PoseEstimationResult? {
        let poseDetector = PoseEstimator()
        return poseDetector.detectPose(in: image)
    }

    private func tryTextLocalization(image: CGImage, pose: PoseEstimationResult) -> BibNumberResult? {
        let parallel = ParallelZoneProcessor()
        parallel.detectionMethod = .textLocalization
        parallel.verboseLogging = false
        let (result, _) = parallel.detectInParallel(in: image, pose: pose)
        return result
    }

    private func tryColorBased(image: CGImage, pose: PoseEstimationResult) -> BibNumberResult? {
        let parallel = ParallelZoneProcessor()
        parallel.detectionMethod = .colorEnhanced
        parallel.verboseLogging = false
        let (result, _) = parallel.detectInParallel(in: image, pose: pose)
        return result
    }

    private func tryLanguageHints(image: CGImage, pose: PoseEstimationResult) -> BibNumberResult? {
        let parallel = ParallelZoneProcessor()
        parallel.detectionMethod = .languageHints
        parallel.verboseLogging = false
        let (result, _) = parallel.detectInParallel(in: image, pose: pose)
        return result
    }

    private func tryAdaptiveExpansion(image: CGImage, pose: PoseEstimationResult) -> BibNumberResult? {
        let adaptive = AdaptiveTorsoExpander()
        adaptive.enableColorPreDetection = true
        let result = adaptive.detectWithAdaptiveExpansion(in: image, pose: pose)
        return result.bibNumber
    }

    private func tryMultiScale(image: CGImage, pose: PoseEstimationResult) -> BibNumberResult? {
        let parallel = ParallelZoneProcessor()
        parallel.detectionMethod = .multiScale
        parallel.verboseLogging = false
        let (result, _) = parallel.detectInParallel(in: image, pose: pose)
        return result
    }
}

// MARK: - Usage Examples

func printRealWorldUsageExamples() {
    print("\n")
    print("=" * 80)
    print("REAL-WORLD USAGE GUIDE")
    print("=" * 80)
    print("\n")

    print("This guide demonstrates 5 real-world scenarios:\n")

    print("1. Simple Single-Image Detection (Beginner)")
    print("   Usage: let detector = SimpleBibDetection()")
    print("          let bib = detector.detectBibNumber(from: \"path/to/image.jpg\")")
    print()

    print("2. Batch Processing Race Photos (Intermediate)")
    print("   Usage: let processor = BatchRacePhotoProcessor()")
    print("          let results = processor.processBatchOfPhotos(imagePaths: paths)")
    print()

    print("3. Real-Time Video Processing (Advanced)")
    print("   Usage: let videoProcessor = RealTimeVideoProcessor()")
    print("          let bib = videoProcessor.processVideoFrame(frame)")
    print()

    print("4. High-Performance Production System (Expert)")
    print("   Usage: let system = ProductionBibDetectionSystem(qualityPreset: .balanced)")
    print("          let result = system.detectBibNumber(from: image)")
    print()

    print("5. Difficult Image Handling (Expert)")
    print("   Usage: let difficultProcessor = DifficultImageProcessor()")
    print("          let result = difficultProcessor.processDifficultImage(image: image)")
    print()
}

#if DEBUG
// Uncomment to run:
// printRealWorldUsageExamples()
#endif
