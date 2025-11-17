//
//  ParallelZoneProcessing.swift
//  Apple Vision Framework - Parallel Zone Processing
//
//  Process all 4 torso zones in parallel for 3-4x faster detection on multi-core
//  Uses DispatchQueue and concurrent processing
//

import Foundation
import CoreGraphics
import Dispatch

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Parallel Zone Result

/// Result from parallel zone processing
struct ParallelZoneResult {
    let bibNumber: BibNumberResult?
    let zone: TorsoZone
    let processingTime: TimeInterval
    let threadInfo: String

    var success: Bool {
        return bibNumber != nil
    }
}

// MARK: - Parallel Processing Statistics

/// Statistics for parallel zone processing
struct ParallelProcessingStats {
    let totalZones: Int
    let successfulZones: Int
    let totalTime: TimeInterval
    let longestZoneTime: TimeInterval
    let averageZoneTime: TimeInterval
    let speedupFactor: Double // vs sequential processing
    let threadsUsed: Int

    var description: String {
        return """
        Parallel Processing Statistics:
          Total Zones: \(totalZones)
          Successful: \(successfulZones)
          Total Time: \(String(format: "%.0f", totalTime * 1000))ms
          Avg Zone Time: \(String(format: "%.0f", averageZoneTime * 1000))ms
          Longest Zone: \(String(format: "%.0f", longestZoneTime * 1000))ms
          Speedup: \(String(format: "%.1f", speedupFactor))x
          Threads: \(threadsUsed)
        """
    }
}

// MARK: - Parallel Zone Processor

/// Process all torso zones in parallel using DispatchQueue
class ParallelZoneProcessor {

    // MARK: - Configuration

    /// Quality of Service for processing (default: userInitiated)
    var qos: DispatchQoS = .userInitiated

    /// Enable verbose logging
    var verboseLogging: Bool = false

    /// Detection method to use
    var detectionMethod: DetectionMethod = .languageHints

    enum DetectionMethod {
        case languageHints
        case textLocalization
        case colorEnhanced
        case multiScale
        case adaptive

        var displayName: String {
            switch self {
            case .languageHints: return "Language Hints OCR"
            case .textLocalization: return "Text Localization"
            case .colorEnhanced: return "Color-Enhanced"
            case .multiScale: return "Multi-Scale OCR"
            case .adaptive: return "Adaptive Expansion"
            }
        }
    }

    // MARK: - Parallel Detection

    /// Detect bib in all zones in parallel
    /// - Parameters:
    ///   - image: Full image
    ///   - pose: Pose estimation result
    /// - Returns: Best result and statistics
    func detectInParallel(in image: CGImage,
                         pose: PoseEstimationResult) -> (result: BibNumberResult?, stats: ParallelProcessingStats) {
        let overallStartTime = Date()

        if verboseLogging {
            print("🚀 Parallel Zone Processing")
            print("   Method: \(detectionMethod.displayName)")
            print("   QoS: \(qos.qosClass)")
            print()
        }

        // Get all torso regions
        let torsoManager = TorsoRegionManager()
        let regions = torsoManager.getAllBibRegions(from: pose)

        if verboseLogging {
            print("   Zones to process: \(regions.count)")
        }

        // Create dispatch group for synchronization
        let dispatchGroup = DispatchGroup()
        let queue = DispatchQueue(label: "com.vision.parallelzones",
                                 qos: qos,
                                 attributes: .concurrent)

        // Thread-safe result storage
        let resultsLock = NSLock()
        var zoneResults: [ParallelZoneResult] = []

        // Process each zone in parallel
        for region in regions {
            dispatchGroup.enter()

            queue.async {
                let zoneStartTime = Date()
                let threadInfo = Thread.current.description

                if self.verboseLogging {
                    print("   [\(region.zone.rawValue)] Starting on thread...")
                }

                // Perform detection
                let bibResult = self.detectInZone(image: image, region: region)

                let zoneTime = Date().timeIntervalSince(zoneStartTime)

                // Store result (thread-safe)
                let result = ParallelZoneResult(
                    bibNumber: bibResult,
                    zone: region.zone,
                    processingTime: zoneTime,
                    threadInfo: threadInfo
                )

                resultsLock.lock()
                zoneResults.append(result)
                resultsLock.unlock()

                if self.verboseLogging {
                    if let bib = bibResult {
                        print("   [\(region.zone.rawValue)] ✅ Found: \(bib.number) (conf: \(String(format: "%.2f", bib.confidence)), time: \(String(format: "%.0f", zoneTime * 1000))ms)")
                    } else {
                        print("   [\(region.zone.rawValue)] ❌ Not found (time: \(String(format: "%.0f", zoneTime * 1000))ms)")
                    }
                }

                dispatchGroup.leave()
            }
        }

        // Wait for all zones to complete
        dispatchGroup.wait()

        let totalTime = Date().timeIntervalSince(overallStartTime)

        // Calculate statistics
        let stats = calculateStatistics(
            zoneResults: zoneResults,
            totalTime: totalTime,
            regionsCount: regions.count
        )

        // Select best result
        let bestResult = selectBestResult(from: zoneResults)

        if verboseLogging {
            print()
            print("PARALLEL PROCESSING COMPLETE:")
            print(stats.description)
            if let best = bestResult {
                print()
                print("Best Result: \(best.number) (confidence: \(String(format: "%.2f", best.confidence)))")
            } else {
                print()
                print("No bib detected in any zone")
            }
            print()
        }

        return (bestResult, stats)
    }

    // MARK: - Zone Detection

    private func detectInZone(image: CGImage, region: BibDetectionRegion) -> BibNumberResult? {
        switch detectionMethod {
        case .languageHints:
            let detector = LanguageHintOCRDetector()
            detector.vocabularyPreset = .balanced
            return detector.detectBib(in: image, torsoRegion: region)

        case .textLocalization:
            let detector = TextLocalizedBibDetection()
            return detector.detectBib(in: image, torsoRegion: region)

        case .colorEnhanced:
            let detector = ColorEnhancedBibDetection()
            return detector.detectBib(in: image, torsoRegion: region)

        case .multiScale:
            let detector = MultiScaleOCRDetector()
            // Crop to region first
            guard let croppedImage = cropToRegion(image, region: region.boundingBox) else {
                return nil
            }
            if let votedResult = detector.detectWithMultiScale(in: croppedImage) {
                return BibNumberResult(
                    number: votedResult.number,
                    confidence: votedResult.confidence,
                    boundingBox: region.boundingBox
                )
            }
            return nil

        case .adaptive:
            let expander = AdaptiveTorsoExpander()
            // Note: Adaptive expansion works on entire pose, not single region
            // For single region, just use language hints
            let detector = LanguageHintOCRDetector()
            return detector.detectBib(in: image, torsoRegion: region)
        }
    }

    private func cropToRegion(_ image: CGImage, region: CGRect) -> CGImage? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)

        let x = region.origin.x * width
        let y = (1 - region.origin.y - region.size.height) * height
        let w = region.size.width * width
        let h = region.size.height * height

        let cropRect = CGRect(x: x, y: y, width: w, height: h)
        return image.cropping(to: cropRect)
    }

    // MARK: - Result Selection

    private func selectBestResult(from zoneResults: [ParallelZoneResult]) -> BibNumberResult? {
        // Filter successful results
        let successfulResults = zoneResults.filter { $0.success }

        guard !successfulResults.isEmpty else {
            return nil
        }

        // Sort by confidence (highest first)
        let sorted = successfulResults.sorted { $0.bibNumber!.confidence > $1.bibNumber!.confidence }

        // Return best
        return sorted.first?.bibNumber
    }

    // MARK: - Statistics

    private func calculateStatistics(zoneResults: [ParallelZoneResult],
                                     totalTime: TimeInterval,
                                     regionsCount: Int) -> ParallelProcessingStats {
        let successCount = zoneResults.filter { $0.success }.count

        let zoneTimes = zoneResults.map { $0.processingTime }
        let longestTime = zoneTimes.max() ?? 0
        let averageTime = zoneTimes.reduce(0, +) / Double(zoneTimes.count)

        // Calculate speedup vs sequential
        let sequentialTime = zoneTimes.reduce(0, +)
        let speedup = sequentialTime / totalTime

        // Estimate threads used (unique thread descriptions)
        let uniqueThreads = Set(zoneResults.map { $0.threadInfo })
        let threadsUsed = uniqueThreads.count

        return ParallelProcessingStats(
            totalZones: regionsCount,
            successfulZones: successCount,
            totalTime: totalTime,
            longestZoneTime: longestTime,
            averageZoneTime: averageTime,
            speedupFactor: speedup,
            threadsUsed: threadsUsed
        )
    }
}

// MARK: - Smart Parallel Processor with Early Exit

/// Parallel processor with early exit optimization
class SmartParallelProcessor {

    private let processor = ParallelZoneProcessor()

    // MARK: - Configuration

    /// Early exit confidence threshold (default: 0.85)
    var earlyExitConfidence: Float = 0.85

    /// Enable early exit optimization
    var enableEarlyExit: Bool = true

    /// Zone priority order (highest priority first)
    var zonePriority: [TorsoZone] = [
        .upperChest,     // Most likely (70%+ success)
        .midTorso,       // Second most likely
        .lowerTorso,     // Less common
        .extendedLowerTorso  // Rare
    ]

    // MARK: - Smart Detection

    /// Detect with early exit optimization
    /// - Parameters:
    ///   - image: Full image
    ///   - pose: Pose estimation result
    /// - Returns: Result and statistics
    func detectWithEarlyExit(in image: CGImage,
                            pose: PoseEstimationResult) -> (result: BibNumberResult?, stats: ParallelProcessingStats) {
        let overallStartTime = Date()

        print("🧠 Smart Parallel Processing (Early Exit)")
        print("   Early Exit Threshold: \(earlyExitConfidence)")
        print()

        // Get all torso regions
        let torsoManager = TorsoRegionManager()
        let allRegions = torsoManager.getAllBibRegions(from: pose)

        // Sort regions by priority
        let sortedRegions = allRegions.sorted { region1, region2 in
            let priority1 = zonePriority.firstIndex(of: region1.zone) ?? 999
            let priority2 = zonePriority.firstIndex(of: region2.zone) ?? 999
            return priority1 < priority2
        }

        // Create dispatch group
        let dispatchGroup = DispatchGroup()
        let queue = DispatchQueue(label: "com.vision.smartparallel",
                                 qos: .userInitiated,
                                 attributes: .concurrent)

        // Thread-safe result storage
        let resultsLock = NSLock()
        var zoneResults: [ParallelZoneResult] = []
        var earlyExitTriggered = false

        // Process zones in parallel with early exit check
        for region in sortedRegions {
            // Check if early exit already triggered
            resultsLock.lock()
            let shouldExit = earlyExitTriggered
            resultsLock.unlock()

            if shouldExit && enableEarlyExit {
                print("   [\(region.zone.rawValue)] ⏭️ Skipped (early exit triggered)")
                continue
            }

            dispatchGroup.enter()

            queue.async {
                let zoneStartTime = Date()

                print("   [\(region.zone.rawValue)] Processing...")

                // Perform detection
                let bibResult = self.processor.detectInZone(image: image, region: region)

                let zoneTime = Date().timeIntervalSince(zoneStartTime)

                // Store result
                let result = ParallelZoneResult(
                    bibNumber: bibResult,
                    zone: region.zone,
                    processingTime: zoneTime,
                    threadInfo: Thread.current.description
                )

                resultsLock.lock()
                zoneResults.append(result)

                // Check for early exit
                if let bib = bibResult, bib.confidence >= self.earlyExitConfidence {
                    earlyExitTriggered = true
                    print("   [\(region.zone.rawValue)] ⚡ Early exit! High confidence: \(String(format: "%.2f", bib.confidence))")
                }
                resultsLock.unlock()

                if let bib = bibResult {
                    print("   [\(region.zone.rawValue)] ✅ Found: \(bib.number) (conf: \(String(format: "%.2f", bib.confidence)))")
                } else {
                    print("   [\(region.zone.rawValue)] ❌ Not found")
                }

                dispatchGroup.leave()
            }

            // Small delay to allow early exit to trigger
            if enableEarlyExit {
                usleep(10000) // 10ms
            }
        }

        // Wait for completion
        dispatchGroup.wait()

        let totalTime = Date().timeIntervalSince(overallStartTime)

        // Calculate statistics
        let stats = self.processor.calculateStatistics(
            zoneResults: zoneResults,
            totalTime: totalTime,
            regionsCount: allRegions.count
        )

        // Select best result
        let bestResult = self.processor.selectBestResult(from: zoneResults)

        print()
        print("SMART PARALLEL COMPLETE:")
        print(stats.description)
        print("Early Exit Triggered: \(earlyExitTriggered ? "✅" : "❌")")
        print()

        return (bestResult, stats)
    }
}

// MARK: - Batch Parallel Processing

/// Process multiple images in parallel batches
class BatchParallelProcessor {

    private let processor = ParallelZoneProcessor()

    // MARK: - Configuration

    /// Maximum concurrent image processing
    var maxConcurrentImages: Int = 4

    /// Enable batch progress reporting
    var enableProgressReporting: Bool = true

    // MARK: - Batch Processing

    /// Process multiple images with parallel zone detection
    /// - Parameter imagePosePairs: Array of (image, pose) pairs
    /// - Returns: Array of results and overall statistics
    func processBatch(_ imagePosePairs: [(image: CGImage, pose: PoseEstimationResult)]) -> [(result: BibNumberResult?, stats: ParallelProcessingStats)] {
        let startTime = Date()

        print("📦 Batch Parallel Processing")
        print("   Total Images: \(imagePosePairs.count)")
        print("   Max Concurrent: \(maxConcurrentImages)")
        print()

        let semaphore = DispatchSemaphore(value: maxConcurrentImages)
        let queue = DispatchQueue(label: "com.vision.batchparallel",
                                 qos: .userInitiated,
                                 attributes: .concurrent)
        let dispatchGroup = DispatchGroup()

        // Thread-safe result storage
        let resultsLock = NSLock()
        var results: [(result: BibNumberResult?, stats: ParallelProcessingStats)] = Array(repeating: (nil, ParallelProcessingStats(totalZones: 0, successfulZones: 0, totalTime: 0, longestZoneTime: 0, averageZoneTime: 0, speedupFactor: 0, threadsUsed: 0)), count: imagePosePairs.count)

        // Process each image
        for (index, pair) in imagePosePairs.enumerated() {
            dispatchGroup.enter()
            semaphore.wait()

            queue.async {
                if self.enableProgressReporting {
                    print("   Image \(index + 1)/\(imagePosePairs.count): Processing...")
                }

                let (result, stats) = self.processor.detectInParallel(
                    in: pair.image,
                    pose: pair.pose
                )

                resultsLock.lock()
                results[index] = (result, stats)
                resultsLock.unlock()

                if self.enableProgressReporting {
                    if let bib = result {
                        print("   Image \(index + 1): ✅ \(bib.number) (\(String(format: "%.0f", stats.totalTime * 1000))ms)")
                    } else {
                        print("   Image \(index + 1): ❌ Not found (\(String(format: "%.0f", stats.totalTime * 1000))ms)")
                    }
                }

                semaphore.signal()
                dispatchGroup.leave()
            }
        }

        // Wait for all
        dispatchGroup.wait()

        let totalTime = Date().timeIntervalSince(startTime)

        // Summary
        let successCount = results.filter { $0.result != nil }.count
        let avgSpeedup = results.map { $0.stats.speedupFactor }.reduce(0, +) / Double(results.count)

        print()
        print("BATCH PROCESSING COMPLETE:")
        print("  Total Time: \(String(format: "%.1f", totalTime))s")
        print("  Successful: \(successCount)/\(imagePosePairs.count)")
        print("  Success Rate: \(String(format: "%.1f%%", Float(successCount) / Float(imagePosePairs.count) * 100))")
        print("  Average Speedup: \(String(format: "%.1f", avgSpeedup))x")
        print()

        return results
    }
}

// MARK: - Integration Extensions

extension ParallelZoneProcessor {
    /// Convenience method with default settings
    static func detect(in image: CGImage, pose: PoseEstimationResult) -> BibNumberResult? {
        let processor = ParallelZoneProcessor()
        processor.detectionMethod = .languageHints
        processor.verboseLogging = true

        let (result, _) = processor.detectInParallel(in: image, pose: pose)
        return result
    }
}
