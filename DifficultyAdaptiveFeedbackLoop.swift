import Foundation
import Vision
import CoreImage
import CoreGraphics

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Difficulty-Specific Configuration

/// Fine-tuned parameters for each difficulty level
struct DifficultyConfiguration {
    let level: ImageDifficultyLevel

    // Pipeline configuration
    var maxFeedbackIterations: Int
    var minimumConfidenceForSuccess: Float

    // Rescue strategies
    var rescueStrategies: [RescueEnhancementStrategy]
    var strategyOrder: [RescueEnhancementStrategy]  // Ordered by effectiveness for this level

    // OCR configuration
    var ocrMinimumConfidence: Float
    var ocrMaxPasses: Int
    var enableEarlyExit: Bool

    // Preprocessing parameters
    var upscaleFactor: CGFloat
    var contrastBoost: Float
    var sharpness: Float
    var denoising: Bool
    var binarization: Bool

    // Smart scaling
    var enableSmartScaling: Bool
    var scaleFactorMultiplier: CGFloat

    // Performance
    var maxProcessingTime: TimeInterval  // Maximum time to spend

    var description: String {
        return """
        Configuration for \(level.displayName):
          Max Iterations: \(maxFeedbackIterations)
          Min Confidence: \(String(format: "%.2f", minimumConfidenceForSuccess))
          Rescue Strategies: \(rescueStrategies.count) (\(rescueStrategies.map { $0.rawValue }.joined(separator: ", ")))
          OCR Passes: \(ocrMaxPasses)
          Upscale: \(String(format: "%.1fx", upscaleFactor))
          Contrast: \(String(format: "%.1fx", contrastBoost))
          Sharpness: \(String(format: "%.1f", sharpness))
          Denoising: \(denoising ? "On" : "Off")
          Smart Scaling: \(enableSmartScaling ? "On" : "Off")
        """
    }

    // MARK: - Predefined Configurations

    static var light: DifficultyConfiguration {
        return DifficultyConfiguration(
            level: .light,
            maxFeedbackIterations: 1,               // Just 1 rescue attempt
            minimumConfidenceForSuccess: 0.6,       // Higher threshold (good quality expected)
            rescueStrategies: [.extremeContrast],   // Minimal rescue
            strategyOrder: [.extremeContrast],
            ocrMinimumConfidence: 0.6,
            ocrMaxPasses: 3,                        // First 3 passes only (fast)
            enableEarlyExit: true,
            upscaleFactor: 1.0,                     // No upscaling
            contrastBoost: 1.2,                     // Light boost
            sharpness: 0.5,                         // Light sharpening
            denoising: false,
            binarization: false,
            enableSmartScaling: false,              // Not needed for close subjects
            scaleFactorMultiplier: 1.0,
            maxProcessingTime: 1.0                  // 1 second
        )
    }

    static var medium: DifficultyConfiguration {
        return DifficultyConfiguration(
            level: .medium,
            maxFeedbackIterations: 2,               // 2 rescue attempts
            minimumConfidenceForSuccess: 0.5,       // Moderate threshold
            rescueStrategies: [
                .extremeContrast,
                .adaptiveThreshold,
                .multiScale
            ],
            strategyOrder: [
                .extremeContrast,                   // Try this first
                .multiScale,                        // Then scaling
                .adaptiveThreshold                  // Then threshold
            ],
            ocrMinimumConfidence: 0.5,
            ocrMaxPasses: 4,                        // More passes
            enableEarlyExit: true,
            upscaleFactor: 1.5,                     // Moderate upscaling
            contrastBoost: 1.4,                     // Moderate boost
            sharpness: 0.9,                         // Moderate sharpening
            denoising: true,                        // Enable denoising
            binarization: false,
            enableSmartScaling: true,               // Use smart scaling
            scaleFactorMultiplier: 1.2,
            maxProcessingTime: 2.5                  // 2.5 seconds
        )
    }

    static var hard: DifficultyConfiguration {
        return DifficultyConfiguration(
            level: .hard,
            maxFeedbackIterations: 3,               // 3 rescue attempts
            minimumConfidenceForSuccess: 0.4,       // Lower threshold (accept lower quality)
            rescueStrategies: [
                .extremeContrast,
                .adaptiveThreshold,
                .multiScale,
                .invertColors,
                .denoiseHeavy
            ],
            strategyOrder: [
                .multiScale,                        // Try upscaling first for distant subjects
                .extremeContrast,
                .denoiseHeavy,                      // Then denoise
                .adaptiveThreshold,
                .invertColors                       // Inversion as fallback
            ],
            ocrMinimumConfidence: 0.4,
            ocrMaxPasses: 5,                        // All passes
            enableEarlyExit: false,                 // Try all for best result
            upscaleFactor: 3.0,                     // Aggressive upscaling
            contrastBoost: 1.8,                     // High boost
            sharpness: 1.3,                         // High sharpening
            denoising: true,
            binarization: true,                     // Enable binarization
            enableSmartScaling: true,
            scaleFactorMultiplier: 1.5,
            maxProcessingTime: 5.0                  // 5 seconds
        )
    }

    static var extreme: DifficultyConfiguration {
        return DifficultyConfiguration(
            level: .extreme,
            maxFeedbackIterations: 4,               // Maximum attempts
            minimumConfidenceForSuccess: 0.35,      // Accept even low confidence
            rescueStrategies: RescueEnhancementStrategy.allCases.filter { $0 != .combinedRescue } + [.combinedRescue],  // All strategies, combined last
            strategyOrder: [
                .combinedRescue,                    // Try combined first for extreme cases
                .multiScale,
                .denoiseHeavy,
                .extremeContrast,
                .adaptiveThreshold,
                .invertColors
            ],
            ocrMinimumConfidence: 0.35,
            ocrMaxPasses: 5,
            enableEarlyExit: false,
            upscaleFactor: 6.0,                     // Maximum upscaling
            contrastBoost: 2.5,                     // Maximum boost
            sharpness: 1.8,                         // Maximum sharpening
            denoising: true,
            binarization: true,
            enableSmartScaling: true,
            scaleFactorMultiplier: 2.0,             // Double smart scaling
            maxProcessingTime: 10.0                 // 10 seconds (take our time)
        )
    }

    static func forLevel(_ level: ImageDifficultyLevel) -> DifficultyConfiguration {
        switch level {
        case .light: return .light
        case .medium: return .medium
        case .hard: return .hard
        case .extreme: return .extreme
        case .auto: return .medium  // Default to medium for auto
        }
    }
}

// MARK: - Difficulty-Adaptive Feedback Loop

/// Complete pipeline with difficulty-adaptive rescue strategies
class DifficultyAdaptiveFeedbackLoop {

    // MARK: - Configuration

    var autoDetectDifficulty: Bool = true  // Auto mode enabled by default
    var manualDifficultyLevel: ImageDifficultyLevel?  // Override auto-detection

    // Components
    private let difficultyAnalyzer = ImageDifficultyAnalyzer()
    private let personDetector = PersonDetection()
    private let poseEstimator = PoseEstimation()
    private let torsoDetector = TorsoRegionDetector()
    private let rescueEnhancer = RescueImageEnhancer()

    // MARK: - Main Detection with Adaptive Strategy

    /// Detect bib number with difficulty-adaptive strategy
    func detectBibNumber(in image: CGImage) -> CompletePipelineFeedbackLoop.CompletePipelineResult? {
        let startTime = Date()

        // STEP 1: Analyze difficulty (unless manually set)
        let difficulty: ImageDifficultyLevel
        let metrics: ImageQualityMetrics

        if let manual = manualDifficultyLevel {
            difficulty = manual
            metrics = difficultyAnalyzer.analyzeImageQuality(image)
            print("📋 Manual difficulty: \(difficulty.emoji) \(difficulty.displayName)")
        } else if autoDetectDifficulty {
            let analysis = difficultyAnalyzer.analyzeDifficulty(image)
            difficulty = analysis.level
            metrics = analysis.metrics
            print("🤖 Auto-detected difficulty: \(difficulty.emoji) \(difficulty.displayName)")
        } else {
            difficulty = .medium  // Default
            metrics = difficultyAnalyzer.analyzeImageQuality(image)
            print("⚙️ Default difficulty: \(difficulty.emoji) \(difficulty.displayName)")
        }

        // STEP 2: Get configuration for this difficulty level
        let config = DifficultyConfiguration.forLevel(difficulty)

        print("\n╔════════════════════════════════════════════════════════════╗")
        print("║   DIFFICULTY-ADAPTIVE PIPELINE                             ║")
        print("╚════════════════════════════════════════════════════════════╝")
        print("")
        print(config.description)
        print("")
        print("Quality Metrics:")
        print("  Overall Quality: \(String(format: "%.2f", metrics.overallQuality))")
        print("  Brightness: \(String(format: "%.2f", metrics.averageBrightness))")
        print("  Sharpness: \(String(format: "%.2f", metrics.sharpness))")
        print("  Contrast: \(String(format: "%.2f", metrics.contrast))")
        if let personSize = metrics.largestPersonSize {
            print("  Person Size: \(String(format: "%.1f%%", personSize * 100))")
        }
        print("")

        // STEP 3: Execute adaptive pipeline
        let result = executeAdaptivePipeline(
            on: image,
            config: config,
            metrics: metrics,
            startTime: startTime
        )

        return result
    }

    // MARK: - Adaptive Pipeline Execution

    private func executeAdaptivePipeline(
        on image: CGImage,
        config: DifficultyConfiguration,
        metrics: ImageQualityMetrics,
        startTime: Date
    ) -> CompletePipelineFeedbackLoop.CompletePipelineResult? {

        var iteration = 0
        var currentImage = image

        // ITERATION 1: Standard pipeline with original image (pre-processed based on difficulty)
        iteration += 1
        print("┌─ ITERATION \(iteration): Standard Pipeline ─┐\n")

        // Apply difficulty-specific preprocessing
        if let preprocessedImage = applyDifficultyPreprocessing(image, config: config, metrics: metrics) {
            currentImage = preprocessedImage
            print("  Applied difficulty-specific preprocessing")
        }

        if let result = runPipeline(on: currentImage, config: config, iteration: iteration) {
            if result.confidence >= config.minimumConfidenceForSuccess {
                let totalTime = Date().timeIntervalSince(startTime)
                print("\n✓ SUCCESS in ITERATION \(iteration)!")
                print("└───────────────────────────────────────────────────────────┘\n")

                return CompletePipelineFeedbackLoop.CompletePipelineResult(
                    bibNumber: result.bibNumber,
                    confidence: result.confidence,
                    personBoundingBox: result.personBoundingBox,
                    poseLandmarks: result.poseLandmarks,
                    torsoRegion: result.torsoRegion,
                    ocrResult: result.ocrResult,
                    usedRescue: false,
                    rescueStrategy: nil,
                    totalProcessingTime: totalTime,
                    iteration: iteration
                )
            }
            print("\n⚠ Low confidence: \(String(format: "%.2f", result.confidence))")
        } else {
            print("\n✗ FAILED in ITERATION \(iteration)")
        }
        print("└───────────────────────────────────────────────────────────┘\n")

        // FEEDBACK LOOP: Rescue with difficulty-adaptive strategies
        print("╔════════════════════════════════════════════════════════════╗")
        print("║   RESCUE MODE - Difficulty: \(config.level.emoji) \(config.level.displayName.padding(toLength: 25, withPad: " ", startingAt: 0))║")
        print("╚════════════════════════════════════════════════════════════╝\n")

        // Use ordered strategies for this difficulty level
        for strategy in config.strategyOrder.prefix(config.maxFeedbackIterations) {
            // Check timeout
            if Date().timeIntervalSince(startTime) > config.maxProcessingTime {
                print("⏱ Maximum processing time reached")
                break
            }

            iteration += 1
            print("┌─ ITERATION \(iteration): Rescue Strategy: \(strategy.displayName) ─┐\n")

            // Apply rescue enhancement
            let rescuedImages = rescueEnhancer.applyRescueEnhancement(image, strategy: strategy)

            guard !rescuedImages.isEmpty else {
                print("✗ Enhancement failed\n")
                print("└───────────────────────────────────────────────────────────┘\n")
                continue
            }

            print("  ✓ Generated \(rescuedImages.count) rescue variant(s)\n")

            // Try each variant
            for (variantIndex, rescuedImage) in rescuedImages.enumerated() {
                print("  Testing variant \(variantIndex + 1)...")

                // Apply difficulty preprocessing to rescued image
                var finalImage = rescuedImage
                if let preprocessed = applyDifficultyPreprocessing(rescuedImage, config: config, metrics: metrics) {
                    finalImage = preprocessed
                }

                if let result = runPipeline(on: finalImage, config: config, iteration: iteration) {
                    if result.confidence >= config.minimumConfidenceForSuccess {
                        let totalTime = Date().timeIntervalSince(startTime)

                        print("\n╔════════════════════════════════════════════════════════════╗")
                        print("║   ✓ RESCUED in ITERATION \(iteration)! Strategy: \(strategy.rawValue.padding(toLength: 20, withPad: " ", startingAt: 0))║")
                        print("╚════════════════════════════════════════════════════════════╝\n")

                        return CompletePipelineFeedbackLoop.CompletePipelineResult(
                            bibNumber: result.bibNumber,
                            confidence: result.confidence,
                            personBoundingBox: result.personBoundingBox,
                            poseLandmarks: result.poseLandmarks,
                            torsoRegion: result.torsoRegion,
                            ocrResult: result.ocrResult,
                            usedRescue: true,
                            rescueStrategy: strategy,
                            totalProcessingTime: totalTime,
                            iteration: iteration
                        )
                    }
                    print("  ⚠ Confidence: \(String(format: "%.2f", result.confidence)) (below threshold)\n")
                } else {
                    print("  ✗ No detection\n")
                }
            }

            print("└───────────────────────────────────────────────────────────┘\n")
        }

        print("╔════════════════════════════════════════════════════════════╗")
        print("║   ✗ ALL ATTEMPTS FAILED                                    ║")
        print("╚════════════════════════════════════════════════════════════╝\n")

        return nil
    }

    // MARK: - Difficulty-Specific Preprocessing

    private func applyDifficultyPreprocessing(_ image: CGImage, config: DifficultyConfiguration, metrics: ImageQualityMetrics) -> CGImage? {
        var ciImage = CIImage(cgImage: image)
        let ciContext = CIContext()

        // Upscaling (if needed)
        if config.upscaleFactor > 1.0 {
            let transform = CGAffineTransform(scaleX: config.upscaleFactor, y: config.upscaleFactor)
            ciImage = ciImage.transformed(by: transform)
        }

        // Denoising
        if config.denoising, let medianFilter = CIFilter(name: "CIMedianFilter") {
            medianFilter.setValue(ciImage, forKey: kCIInputImageKey)
            ciImage = medianFilter.outputImage ?? ciImage
        }

        // Contrast boost
        if config.contrastBoost != 1.0, let contrastFilter = CIFilter(name: "CIColorControls") {
            contrastFilter.setValue(ciImage, forKey: kCIInputImageKey)
            contrastFilter.setValue(config.contrastBoost, forKey: kCIInputContrastKey)
            ciImage = contrastFilter.outputImage ?? ciImage
        }

        // Sharpening
        if config.sharpness > 0.0, let sharpenFilter = CIFilter(name: "CISharpenLuminance") {
            sharpenFilter.setValue(ciImage, forKey: kCIInputImageKey)
            sharpenFilter.setValue(config.sharpness, forKey: kCIInputSharpnessKey)
            ciImage = sharpenFilter.outputImage ?? ciImage
        }

        // Binarization
        if config.binarization, let binarizeFilter = CIFilter(name: "CIColorControls") {
            binarizeFilter.setValue(ciImage, forKey: kCIInputImageKey)
            binarizeFilter.setValue(0.0, forKey: kCIInputSaturationKey)
            binarizeFilter.setValue(3.0, forKey: kCIInputContrastKey)
            ciImage = binarizeFilter.outputImage ?? ciImage
        }

        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }

    // MARK: - Pipeline Execution

    private func runPipeline(on image: CGImage, config: DifficultyConfiguration, iteration: Int) -> (bibNumber: String, confidence: Float, personBoundingBox: CGRect, poseLandmarks: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint], torsoRegion: TorsoRegion, ocrResult: BibNumberResult)? {

        // Person Detection
        guard let people = personDetector.detectPeople(in: image),
              let firstPerson = people.first else {
            return nil
        }

        // Pose Estimation
        guard let poses = try? poseEstimator.estimatePose(in: image),
              let firstPose = poses.first else {
            return nil
        }

        // Torso Detection
        let torsoRegions = torsoDetector.detectTorsoRegions(from: firstPose)
        guard let firstTorsoRegion = torsoRegions.first else {
            return nil
        }

        // OCR with difficulty-adaptive configuration
        let ocrSystem = MultiPassBibOCR()
        ocrSystem.config.maxPasses = config.ocrMaxPasses
        ocrSystem.config.minimumGlobalConfidence = config.ocrMinimumConfidence
        ocrSystem.config.enableEarlyExit = config.enableEarlyExit

        let searchZones = [
            firstTorsoRegion.upperChest,
            firstTorsoRegion.midTorso,
            firstTorsoRegion.lowerTorso
        ]

        var bestOCRResult: BibNumberResult?
        for zoneRect in searchZones {
            if let ocrResult = ocrSystem.recognizeBibNumber(in: image, region: zoneRect) {
                if bestOCRResult == nil || ocrResult.adjustedConfidence > bestOCRResult!.adjustedConfidence {
                    bestOCRResult = ocrResult
                }
            }
        }

        guard let ocrResult = bestOCRResult else {
            return nil
        }

        var landmarks: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint] = [:]
        for jointName in firstPose.availableJointNames {
            if let point = try? firstPose.recognizedPoint(jointName) {
                landmarks[jointName] = point
            }
        }

        return (
            bibNumber: ocrResult.number,
            confidence: ocrResult.adjustedConfidence,
            personBoundingBox: firstPerson.boundingBox,
            poseLandmarks: landmarks,
            torsoRegion: firstTorsoRegion,
            ocrResult: ocrResult
        )
    }

    // MARK: - Batch Processing

    func detectBibNumbers(in images: [CGImage]) -> [CompletePipelineFeedbackLoop.CompletePipelineResult] {
        return images.compactMap { detectBibNumber(in: $0) }
    }
}

// MARK: - Example Usage

/*
 Example usage:

 let pipeline = DifficultyAdaptiveFeedbackLoop()

 // AUTO MODE (Recommended!)
 pipeline.autoDetectDifficulty = true
 let result = pipeline.detectBibNumber(in: image)
 // Pipeline automatically detects difficulty and adjusts all parameters

 // MANUAL MODE
 pipeline.autoDetectDifficulty = false
 pipeline.manualDifficultyLevel = .hard
 let result2 = pipeline.detectBibNumber(in: difficultImage)

 // Per difficulty level behavior:
 //
 // LIGHT (Easy images):
 //   - 1 rescue attempt
 //   - Minimal preprocessing (1.0x scale, 1.2x contrast)
 //   - Fast OCR (3 passes, early exit)
 //   - Strategies: [extremeContrast]
 //   - Time budget: 1 second
 //
 // MEDIUM (Moderate):
 //   - 2 rescue attempts
 //   - Moderate preprocessing (1.5x scale, 1.4x contrast, denoising)
 //   - Standard OCR (4 passes)
 //   - Strategies: [extremeContrast, adaptiveThreshold, multiScale]
 //   - Time budget: 2.5 seconds
 //
 // HARD (Difficult):
 //   - 3 rescue attempts
 //   - Aggressive preprocessing (3.0x scale, 1.8x contrast, binarization)
 //   - Full OCR (5 passes, no early exit)
 //   - Strategies: [multiScale, extremeContrast, denoiseHeavy, adaptiveThreshold, invertColors]
 //   - Time budget: 5 seconds
 //
 // EXTREME (Very difficult):
 //   - 4 rescue attempts
 //   - Maximum preprocessing (6.0x scale, 2.5x contrast, all enhancements)
 //   - Full OCR (5 passes, accept low confidence)
 //   - Strategies: ALL (combined rescue first)
 //   - Time budget: 10 seconds
 */
