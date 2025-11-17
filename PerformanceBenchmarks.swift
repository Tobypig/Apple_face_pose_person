//
//  PerformanceBenchmarks.swift
//  Apple Vision Framework - Performance Benchmarks
//
//  Comprehensive performance benchmarking for all detection methods
//  Measures speed, accuracy, and resource usage
//

import Foundation
import CoreGraphics
import Dispatch

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Benchmark Result

/// Result from a single benchmark run
struct BenchmarkResult {
    let methodName: String
    let executionTime: TimeInterval
    let success: Bool
    let confidence: Float?
    let memoryUsed: UInt64
    let cpuUsage: Double

    var description: String {
        let status = success ? "✅" : "❌"
        let confStr = confidence.map { String(format: "%.2f", $0) } ?? "N/A"
        return """
        \(methodName): \(status)
          Time: \(String(format: "%.0f", executionTime * 1000))ms
          Confidence: \(confStr)
          Memory: \(String(format: "%.1f", Double(memoryUsed) / 1024 / 1024))MB
          CPU: \(String(format: "%.1f%%", cpuUsage))
        """
    }
}

// MARK: - Benchmark Statistics

/// Aggregate statistics for multiple benchmark runs
struct BenchmarkStatistics {
    let methodName: String
    let runs: [BenchmarkResult]

    var successRate: Float {
        let successCount = runs.filter { $0.success }.count
        return Float(successCount) / Float(runs.count)
    }

    var averageTime: TimeInterval {
        let times = runs.map { $0.executionTime }
        return times.reduce(0, +) / Double(times.count)
    }

    var medianTime: TimeInterval {
        let sortedTimes = runs.map { $0.executionTime }.sorted()
        let mid = sortedTimes.count / 2
        return sortedTimes.count % 2 == 0 ?
            (sortedTimes[mid - 1] + sortedTimes[mid]) / 2 :
            sortedTimes[mid]
    }

    var minTime: TimeInterval {
        runs.map { $0.executionTime }.min() ?? 0
    }

    var maxTime: TimeInterval {
        runs.map { $0.executionTime }.max() ?? 0
    }

    var averageConfidence: Float {
        let confidences = runs.compactMap { $0.confidence }
        guard !confidences.isEmpty else { return 0 }
        return confidences.reduce(0, +) / Float(confidences.count)
    }

    var summary: String {
        return """
        \(methodName) - Benchmark Statistics (\(runs.count) runs):
          Success Rate: \(String(format: "%.1f%%", successRate * 100))
          Avg Time: \(String(format: "%.0f", averageTime * 1000))ms
          Median Time: \(String(format: "%.0f", medianTime * 1000))ms
          Min Time: \(String(format: "%.0f", minTime * 1000))ms
          Max Time: \(String(format: "%.0f", maxTime * 1000))ms
          Avg Confidence: \(String(format: "%.2f", averageConfidence))
        """
    }
}

// MARK: - Performance Benchmarker

/// Comprehensive performance benchmarking system
class PerformanceBenchmarker {

    // MARK: - Configuration

    /// Number of runs per benchmark (default: 10)
    var numberOfRuns: Int = 10

    /// Enable warmup runs (default: true)
    var enableWarmup: Bool = true

    /// Number of warmup runs (default: 3)
    var warmupRuns: Int = 3

    /// Enable verbose logging
    var verboseLogging: Bool = true

    // MARK: - Benchmark Methods

    /// Benchmark all detection methods
    /// - Parameters:
    ///   - image: Test image
    ///   - pose: Pose estimation result
    /// - Returns: Dictionary of method name to statistics
    func benchmarkAllMethods(image: CGImage, pose: PoseEstimationResult) -> [String: BenchmarkStatistics] {
        var allResults: [String: [BenchmarkResult]] = [:]

        print("\n" + "=" * 80)
        print("PERFORMANCE BENCHMARKS")
        print("=" * 80)
        print()
        print("Configuration:")
        print("  Runs per method: \(numberOfRuns)")
        print("  Warmup runs: \(enableWarmup ? "\(warmupRuns)" : "Disabled")")
        print()

        // Benchmark 1: Text Localization
        print("Benchmarking: Text Localization")
        allResults["Text Localization"] = benchmarkTextLocalization(image: image, pose: pose)

        // Benchmark 2: Color-Based Detection
        print("Benchmarking: Color-Based Detection")
        allResults["Color-Based"] = benchmarkColorBased(image: image, pose: pose)

        // Benchmark 3: Language Hints
        print("Benchmarking: Language Hints")
        allResults["Language Hints"] = benchmarkLanguageHints(image: image, pose: pose)

        // Benchmark 4: Parallel Processing
        print("Benchmarking: Parallel Processing")
        allResults["Parallel"] = benchmarkParallel(image: image, pose: pose)

        // Benchmark 5: Confidence-Weighted
        print("Benchmarking: Confidence-Weighted")
        allResults["Confidence-Weighted"] = benchmarkConfidenceWeighted(image: image, pose: pose)

        // Benchmark 6: Adaptive Expansion
        print("Benchmarking: Adaptive Expansion")
        allResults["Adaptive Expansion"] = benchmarkAdaptiveExpansion(image: image, pose: pose)

        // Benchmark 7: Multi-Scale
        print("Benchmarking: Multi-Scale OCR")
        allResults["Multi-Scale"] = benchmarkMultiScale(image: image, pose: pose)

        // Generate statistics
        var statistics: [String: BenchmarkStatistics] = [:]
        for (method, results) in allResults {
            statistics[method] = BenchmarkStatistics(methodName: method, runs: results)
        }

        // Print summary
        printBenchmarkSummary(statistics)

        return statistics
    }

    // MARK: - Individual Method Benchmarks

    private func benchmarkTextLocalization(image: CGImage, pose: PoseEstimationResult) -> [BenchmarkResult] {
        var results: [BenchmarkResult] = []

        let torsoManager = TorsoRegionManager()
        guard let upperChest = torsoManager.getUpperChestRegion(from: pose) else {
            return results
        }

        // Warmup
        if enableWarmup {
            let detector = TextLocalizedBibDetection()
            for _ in 0..<warmupRuns {
                _ = detector.detectBib(in: image, torsoRegion: upperChest)
            }
        }

        // Actual runs
        for i in 0..<numberOfRuns {
            let detector = TextLocalizedBibDetection()

            let startMemory = getMemoryUsage()
            let startCPU = getCPUUsage()
            let startTime = Date()

            let result = detector.detectBib(in: image, torsoRegion: upperChest)

            let executionTime = Date().timeIntervalSince(startTime)
            let endMemory = getMemoryUsage()
            let endCPU = getCPUUsage()

            let benchmarkResult = BenchmarkResult(
                methodName: "Text Localization",
                executionTime: executionTime,
                success: result != nil,
                confidence: result?.confidence,
                memoryUsed: endMemory - startMemory,
                cpuUsage: endCPU - startCPU
            )

            results.append(benchmarkResult)

            if verboseLogging {
                print("  Run \(i + 1): \(String(format: "%.0f", executionTime * 1000))ms")
            }
        }

        return results
    }

    private func benchmarkColorBased(image: CGImage, pose: PoseEstimationResult) -> [BenchmarkResult] {
        var results: [BenchmarkResult] = []

        let torsoManager = TorsoRegionManager()
        guard let upperChest = torsoManager.getUpperChestRegion(from: pose) else {
            return results
        }

        // Warmup
        if enableWarmup {
            let detector = ColorEnhancedBibDetection()
            for _ in 0..<warmupRuns {
                _ = detector.detectBib(in: image, torsoRegion: upperChest)
            }
        }

        // Actual runs
        for i in 0..<numberOfRuns {
            let detector = ColorEnhancedBibDetection()

            let startMemory = getMemoryUsage()
            let startCPU = getCPUUsage()
            let startTime = Date()

            let result = detector.detectBib(in: image, torsoRegion: upperChest)

            let executionTime = Date().timeIntervalSince(startTime)
            let endMemory = getMemoryUsage()
            let endCPU = getCPUUsage()

            let benchmarkResult = BenchmarkResult(
                methodName: "Color-Based",
                executionTime: executionTime,
                success: result != nil,
                confidence: result?.confidence,
                memoryUsed: endMemory - startMemory,
                cpuUsage: endCPU - startCPU
            )

            results.append(benchmarkResult)

            if verboseLogging {
                print("  Run \(i + 1): \(String(format: "%.0f", executionTime * 1000))ms")
            }
        }

        return results
    }

    private func benchmarkLanguageHints(image: CGImage, pose: PoseEstimationResult) -> [BenchmarkResult] {
        var results: [BenchmarkResult] = []

        let torsoManager = TorsoRegionManager()
        guard let upperChest = torsoManager.getUpperChestRegion(from: pose) else {
            return results
        }

        // Warmup (includes vocabulary generation)
        if enableWarmup {
            let detector = LanguageHintOCRDetector()
            detector.vocabularyPreset = .balanced
            for _ in 0..<warmupRuns {
                _ = detector.detectBib(in: image, torsoRegion: upperChest)
            }
        }

        // Actual runs
        for i in 0..<numberOfRuns {
            let detector = LanguageHintOCRDetector()
            detector.vocabularyPreset = .balanced

            let startMemory = getMemoryUsage()
            let startCPU = getCPUUsage()
            let startTime = Date()

            let result = detector.detectBib(in: image, torsoRegion: upperChest)

            let executionTime = Date().timeIntervalSince(startTime)
            let endMemory = getMemoryUsage()
            let endCPU = getCPUUsage()

            let benchmarkResult = BenchmarkResult(
                methodName: "Language Hints",
                executionTime: executionTime,
                success: result != nil,
                confidence: result?.confidence,
                memoryUsed: endMemory - startMemory,
                cpuUsage: endCPU - startCPU
            )

            results.append(benchmarkResult)

            if verboseLogging {
                print("  Run \(i + 1): \(String(format: "%.0f", executionTime * 1000))ms")
            }
        }

        return results
    }

    private func benchmarkParallel(image: CGImage, pose: PoseEstimationResult) -> [BenchmarkResult] {
        var results: [BenchmarkResult] = []

        // Warmup
        if enableWarmup {
            let processor = ParallelZoneProcessor()
            processor.verboseLogging = false
            for _ in 0..<warmupRuns {
                _ = processor.detectInParallel(in: image, pose: pose)
            }
        }

        // Actual runs
        for i in 0..<numberOfRuns {
            let processor = ParallelZoneProcessor()
            processor.verboseLogging = false

            let startMemory = getMemoryUsage()
            let startCPU = getCPUUsage()
            let startTime = Date()

            let (result, _) = processor.detectInParallel(in: image, pose: pose)

            let executionTime = Date().timeIntervalSince(startTime)
            let endMemory = getMemoryUsage()
            let endCPU = getCPUUsage()

            let benchmarkResult = BenchmarkResult(
                methodName: "Parallel",
                executionTime: executionTime,
                success: result != nil,
                confidence: result?.confidence,
                memoryUsed: endMemory - startMemory,
                cpuUsage: endCPU - startCPU
            )

            results.append(benchmarkResult)

            if verboseLogging {
                print("  Run \(i + 1): \(String(format: "%.0f", executionTime * 1000))ms")
            }
        }

        return results
    }

    private func benchmarkConfidenceWeighted(image: CGImage, pose: PoseEstimationResult) -> [BenchmarkResult] {
        var results: [BenchmarkResult] = []

        // Warmup
        if enableWarmup {
            let detector = ConfidenceWeightedBibDetector()
            detector.verboseLogging = false
            for _ in 0..<warmupRuns {
                _ = detector.detectWithConfidenceWeighting(in: image, pose: pose)
            }
        }

        // Actual runs
        for i in 0..<numberOfRuns {
            let detector = ConfidenceWeightedBibDetector()
            detector.verboseLogging = false

            let startMemory = getMemoryUsage()
            let startCPU = getCPUUsage()
            let startTime = Date()

            let (result, _) = detector.detectWithConfidenceWeighting(in: image, pose: pose)

            let executionTime = Date().timeIntervalSince(startTime)
            let endMemory = getMemoryUsage()
            let endCPU = getCPUUsage()

            let benchmarkResult = BenchmarkResult(
                methodName: "Confidence-Weighted",
                executionTime: executionTime,
                success: result != nil,
                confidence: result?.confidence,
                memoryUsed: endMemory - startMemory,
                cpuUsage: endCPU - startCPU
            )

            results.append(benchmarkResult)

            if verboseLogging {
                print("  Run \(i + 1): \(String(format: "%.0f", executionTime * 1000))ms")
            }
        }

        return results
    }

    private func benchmarkAdaptiveExpansion(image: CGImage, pose: PoseEstimationResult) -> [BenchmarkResult] {
        var results: [BenchmarkResult] = []

        // Warmup
        if enableWarmup {
            let expander = AdaptiveTorsoExpander()
            for _ in 0..<warmupRuns {
                _ = expander.detectWithAdaptiveExpansion(in: image, pose: pose)
            }
        }

        // Actual runs
        for i in 0..<numberOfRuns {
            let expander = AdaptiveTorsoExpander()

            let startMemory = getMemoryUsage()
            let startCPU = getCPUUsage()
            let startTime = Date()

            let result = expander.detectWithAdaptiveExpansion(in: image, pose: pose)

            let executionTime = Date().timeIntervalSince(startTime)
            let endMemory = getMemoryUsage()
            let endCPU = getCPUUsage()

            let benchmarkResult = BenchmarkResult(
                methodName: "Adaptive Expansion",
                executionTime: executionTime,
                success: result.success,
                confidence: result.bibNumber?.confidence,
                memoryUsed: endMemory - startMemory,
                cpuUsage: endCPU - startCPU
            )

            results.append(benchmarkResult)

            if verboseLogging {
                print("  Run \(i + 1): \(String(format: "%.0f", executionTime * 1000))ms")
            }
        }

        return results
    }

    private func benchmarkMultiScale(image: CGImage, pose: PoseEstimationResult) -> [BenchmarkResult] {
        var results: [BenchmarkResult] = []

        let torsoManager = TorsoRegionManager()
        guard let upperChest = torsoManager.getUpperChestRegion(from: pose),
              let croppedImage = cropToRegion(image, region: upperChest.boundingBox) else {
            return results
        }

        // Warmup
        if enableWarmup {
            let detector = MultiScaleOCRDetector()
            for _ in 0..<warmupRuns {
                _ = detector.detectWithMultiScale(in: croppedImage)
            }
        }

        // Actual runs
        for i in 0..<numberOfRuns {
            let detector = MultiScaleOCRDetector()

            let startMemory = getMemoryUsage()
            let startCPU = getCPUUsage()
            let startTime = Date()

            let result = detector.detectWithMultiScale(in: croppedImage)

            let executionTime = Date().timeIntervalSince(startTime)
            let endMemory = getMemoryUsage()
            let endCPU = getCPUUsage()

            let benchmarkResult = BenchmarkResult(
                methodName: "Multi-Scale",
                executionTime: executionTime,
                success: result != nil,
                confidence: result?.confidence,
                memoryUsed: endMemory - startMemory,
                cpuUsage: endCPU - startCPU
            )

            results.append(benchmarkResult)

            if verboseLogging {
                print("  Run \(i + 1): \(String(format: "%.0f", executionTime * 1000))ms")
            }
        }

        return results
    }

    // MARK: - Summary

    private func printBenchmarkSummary(_ statistics: [String: BenchmarkStatistics]) {
        print("\n" + "=" * 80)
        print("BENCHMARK SUMMARY")
        print("=" * 80)
        print()

        // Sort by average time (fastest first)
        let sorted = statistics.values.sorted { $0.averageTime < $1.averageTime }

        for stats in sorted {
            print(stats.summary)
            print()
        }

        // Comparative analysis
        print("COMPARATIVE ANALYSIS:")
        print()

        if let baseline = sorted.first {
            print("Baseline: \(baseline.methodName) (\(String(format: "%.0f", baseline.averageTime * 1000))ms)")
            print()

            for stats in sorted.dropFirst() {
                let ratio = stats.averageTime / baseline.averageTime
                print("  \(stats.methodName): \(String(format: "%.1fx", ratio)) slower")
            }
        }

        print()
        print("=" * 80)
        print()
    }

    // MARK: - System Metrics

    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? info.resident_size : 0
    }

    private func getCPUUsage() -> Double {
        // Simplified CPU usage (would need more complex implementation for accurate measurement)
        return 0.0
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
}

// MARK: - Comparison Benchmarks

/// Compare specific methods head-to-head
class ComparisonBenchmarks {

    func compareSequentialVsParallel(image: CGImage, pose: PoseEstimationResult, runs: Int = 10) {
        print("\n" + "=" * 80)
        print("SEQUENTIAL vs PARALLEL COMPARISON")
        print("=" * 80)
        print()

        var sequentialTimes: [TimeInterval] = []
        var parallelTimes: [TimeInterval] = []

        // Sequential
        print("Running sequential benchmarks...")
        for i in 0..<runs {
            let start = Date()

            let torsoManager = TorsoRegionManager()
            let regions = torsoManager.getAllBibRegions(from: pose)
            let detector = LanguageHintOCRDetector()

            for region in regions {
                _ = detector.detectBib(in: image, torsoRegion: region)
            }

            let time = Date().timeIntervalSince(start)
            sequentialTimes.append(time)
            print("  Run \(i + 1): \(String(format: "%.0f", time * 1000))ms")
        }

        // Parallel
        print("\nRunning parallel benchmarks...")
        for i in 0..<runs {
            let start = Date()

            let parallel = ParallelZoneProcessor()
            parallel.verboseLogging = false
            _ = parallel.detectInParallel(in: image, pose: pose)

            let time = Date().timeIntervalSince(start)
            parallelTimes.append(time)
            print("  Run \(i + 1): \(String(format: "%.0f", time * 1000))ms")
        }

        // Analysis
        let seqAvg = sequentialTimes.reduce(0, +) / Double(sequentialTimes.count)
        let parAvg = parallelTimes.reduce(0, +) / Double(parallelTimes.count)
        let speedup = seqAvg / parAvg

        print("\nRESULTS:")
        print("  Sequential Avg: \(String(format: "%.0f", seqAvg * 1000))ms")
        print("  Parallel Avg: \(String(format: "%.0f", parAvg * 1000))ms")
        print("  Speedup: \(String(format: "%.1f", speedup))x")
        print()
    }
}

// MARK: - Main Entry Point

func runPerformanceBenchmarks() {
    print("\nPerformance benchmarks require test images to run.")
    print("Load your test images and poses, then use:")
    print()
    print("  let benchmarker = PerformanceBenchmarker()")
    print("  let stats = benchmarker.benchmarkAllMethods(image: testImage, pose: testPose)")
    print()
    print("Or for specific comparisons:")
    print("  let comparison = ComparisonBenchmarks()")
    print("  comparison.compareSequentialVsParallel(image: testImage, pose: testPose)")
    print()
}

#if DEBUG
// Uncomment to run:
// runPerformanceBenchmarks()
#endif
