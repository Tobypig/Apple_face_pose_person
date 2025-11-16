import Foundation
import Vision
import CoreImage
import CoreGraphics

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Complete Pipeline Feedback Loop

/// Full pipeline feedback loop: Person → Pose → Torso → OCR → Rescue → REPEAT ALL
class CompletePipelineFeedbackLoop {

    // MARK: - Configuration

    struct Configuration {
        var enableFeedbackLoop: Bool = true
        var maxFeedbackIterations: Int = 2
        var rescueStrategies: [RescueEnhancementStrategy] = [
            .extremeContrast,
            .adaptiveThreshold,
            .combinedRescue
        ]
        var minimumConfidenceForSuccess: Float = 0.5
    }

    var config = Configuration()

    // MARK: - Components

    private let personDetector = PersonDetection()
    private let poseEstimator = PoseEstimation()
    private let torsoDetector = TorsoRegionDetector()
    private let ocrSystem = MultiPassBibOCR()
    private let rescueEnhancer = RescueImageEnhancer()

    // MARK: - Complete Pipeline Result

    struct CompletePipelineResult {
        let bibNumber: String
        let confidence: Float
        let personBoundingBox: CGRect
        let poseLandmarks: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]
        let torsoRegion: TorsoRegion
        let ocrResult: BibNumberResult
        let usedRescue: Bool
        let rescueStrategy: RescueEnhancementStrategy?
        let totalProcessingTime: TimeInterval
        let iteration: Int  // Which iteration succeeded (1 = first try, 2 = first rescue, etc.)

        var description: String {
            return """
            === Complete Pipeline Result ===
            Bib Number: \(bibNumber)
            Confidence: \(String(format: "%.2f", confidence))
            Used Rescue: \(usedRescue)
            \(rescueStrategy != nil ? "Rescue Strategy: \(rescueStrategy!.displayName)" : "")
            Iteration: \(iteration) \(iteration == 1 ? "(first try)" : "(after \(iteration-1) rescue attempt(s))")
            Processing Time: \(String(format: "%.3f", totalProcessingTime))s
            Person Box: \(personBoundingBox)
            Torso Region: \(torsoRegion.fullTorso)
            """
        }
    }

    // MARK: - Main Pipeline with Feedback Loop

    /// Execute complete pipeline with feedback loop on failure
    func detectBibNumber(in image: CGImage) -> CompletePipelineResult? {
        let startTime = Date()
        var iteration = 0
        var currentImage = image

        print("\n╔════════════════════════════════════════════════════════════╗")
        print("║   COMPLETE PIPELINE WITH FEEDBACK LOOP                     ║")
        print("╚════════════════════════════════════════════════════════════╝\n")

        // ITERATION 1: Standard pipeline with original image
        iteration += 1
        print("┌─ ITERATION \(iteration): Standard Pipeline (Original Image) ─┐\n")

        if let result = runCompletePipeline(on: currentImage, iteration: iteration) {
            if result.confidence >= config.minimumConfidenceForSuccess {
                let totalTime = Date().timeIntervalSince(startTime)
                print("\n✓ SUCCESS in ITERATION \(iteration)!")
                print("└───────────────────────────────────────────────────────────┘\n")

                return CompletePipelineResult(
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

        // FEEDBACK LOOP: Rescue enhancement and re-run complete pipeline
        guard config.enableFeedbackLoop else {
            print("Feedback loop disabled")
            return nil
        }

        print("╔════════════════════════════════════════════════════════════╗")
        print("║   ENTERING FEEDBACK LOOP - RESCUE MODE                     ║")
        print("╚════════════════════════════════════════════════════════════╝\n")

        for strategy in config.rescueStrategies {
            guard iteration < config.maxFeedbackIterations + 1 else {
                print("Maximum iterations reached")
                break
            }

            iteration += 1

            print("┌─ ITERATION \(iteration): Rescue Enhancement & Full Pipeline ─┐")
            print("│ Strategy: \(strategy.displayName)")
            print("└───────────────────────────────────────────────────────────┘\n")

            // STEP 1: Apply rescue enhancement to ORIGINAL image
            print("STEP 1: Rescue Enhancement")
            print("───────────────────────────")

            let rescuedImages = rescueEnhancer.applyRescueEnhancement(image, strategy: strategy)

            guard !rescuedImages.isEmpty else {
                print("✗ Enhancement failed\n")
                continue
            }

            print("✓ Generated \(rescuedImages.count) rescue variant(s)\n")

            // STEP 2: Re-run COMPLETE pipeline on each rescued image
            for (variantIndex, rescuedImage) in rescuedImages.enumerated() {
                print("STEP 2.\(variantIndex + 1): Complete Pipeline on Rescue Variant \(variantIndex + 1)")
                print("──────────────────────────────────────────────────")

                currentImage = rescuedImage

                // ▶ RUN COMPLETE PIPELINE AGAIN ◀
                if let result = runCompletePipeline(on: currentImage, iteration: iteration) {
                    if result.confidence >= config.minimumConfidenceForSuccess {
                        let totalTime = Date().timeIntervalSince(startTime)

                        print("\n╔════════════════════════════════════════════════════════════╗")
                        print("║   ✓ SUCCESS via RESCUE in ITERATION \(iteration)!                  ║")
                        print("╚════════════════════════════════════════════════════════════╝\n")

                        return CompletePipelineResult(
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
                    print("⚠ Low confidence: \(String(format: "%.2f", result.confidence))\n")
                } else {
                    print("✗ FAILED\n")
                }
            }
        }

        print("\n╔════════════════════════════════════════════════════════════╗")
        print("║   ✗ ALL ITERATIONS FAILED                                  ║")
        print("╚════════════════════════════════════════════════════════════╝\n")

        return nil
    }

    // MARK: - Complete Pipeline Execution

    private func runCompletePipeline(on image: CGImage, iteration: Int) -> CompletePipelineResult? {

        // STAGE 1: Person Detection
        print("  Stage 1/4: Person Detection")

        guard let people = personDetector.detectPeople(in: image),
              let firstPerson = people.first else {
            print("    ✗ No person detected")
            return nil
        }

        print("    ✓ Person detected (confidence: \(String(format: "%.2f", firstPerson.confidence)))")
        let personBox = firstPerson.boundingBox

        // STAGE 2: Pose Estimation
        print("  Stage 2/4: Pose Estimation")

        guard let poses = try? poseEstimator.estimatePose(in: image),
              let firstPose = poses.first else {
            print("    ✗ No pose detected")
            return nil
        }

        print("    ✓ Pose detected (\(firstPose.availableJointNames.count) joints)")

        // STAGE 3: Torso Region Detection
        print("  Stage 3/4: Torso Region Detection")

        let torsoRegions = torsoDetector.detectTorsoRegions(from: firstPose)

        guard let firstTorsoRegion = torsoRegions.first else {
            print("    ✗ No torso region detected")
            return nil
        }

        print("    ✓ Torso region detected")
        print("      Upper chest: \(firstTorsoRegion.upperChest)")
        print("      Mid torso: \(firstTorsoRegion.midTorso)")
        print("      Lower torso: \(firstTorsoRegion.lowerTorso)")

        // STAGE 4: OCR in Torso Regions
        print("  Stage 4/4: Bib Number OCR")

        let searchZones = [
            ("upper chest", firstTorsoRegion.upperChest),
            ("mid torso", firstTorsoRegion.midTorso),
            ("lower torso", firstTorsoRegion.lowerTorso)
        ]

        var bestOCRResult: BibNumberResult?

        for (zoneName, zoneRect) in searchZones {
            print("    Searching \(zoneName)...")

            if let ocrResult = ocrSystem.recognizeBibNumber(in: image, region: zoneRect) {
                print("      ✓ Found: '\(ocrResult.number)' (conf: \(String(format: "%.2f", ocrResult.adjustedConfidence)))")

                if bestOCRResult == nil || ocrResult.adjustedConfidence > bestOCRResult!.adjustedConfidence {
                    bestOCRResult = ocrResult
                }
            } else {
                print("      ✗ No detection")
            }
        }

        guard let ocrResult = bestOCRResult else {
            print("    ✗ No bib number detected in any zone")
            return nil
        }

        print("    ✓ Best result: '\(ocrResult.number)' (conf: \(String(format: "%.2f", ocrResult.adjustedConfidence)))")

        // Extract pose landmarks for result
        var landmarks: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint] = [:]
        for jointName in firstPose.availableJointNames {
            if let point = try? firstPose.recognizedPoint(jointName) {
                landmarks[jointName] = point
            }
        }

        return CompletePipelineResult(
            bibNumber: ocrResult.number,
            confidence: ocrResult.adjustedConfidence,
            personBoundingBox: personBox,
            poseLandmarks: landmarks,
            torsoRegion: firstTorsoRegion,
            ocrResult: ocrResult,
            usedRescue: false,  // Will be set by caller
            rescueStrategy: nil,
            totalProcessingTime: 0,  // Will be set by caller
            iteration: iteration
        )
    }

    // MARK: - Batch Processing

    /// Process multiple images with feedback loop
    func detectBibNumbers(in images: [CGImage]) -> [CompletePipelineResult] {
        return images.compactMap { image in
            detectBibNumber(in: image)
        }
    }

    // MARK: - Statistics

    struct Statistics {
        var totalImages: Int = 0
        var firstTrySuccesses: Int = 0
        var rescueSuccesses: Int = 0
        var failures: Int = 0
        var rescueStrategiesUsed: [RescueEnhancementStrategy: Int] = [:]
        var averageProcessingTime: TimeInterval = 0

        var firstTrySuccessRate: Float {
            guard totalImages > 0 else { return 0 }
            return Float(firstTrySuccesses) / Float(totalImages)
        }

        var rescueSuccessRate: Float {
            guard totalImages > 0 else { return 0 }
            return Float(rescueSuccesses) / Float(totalImages)
        }

        var overallSuccessRate: Float {
            guard totalImages > 0 else { return 0 }
            return Float(firstTrySuccesses + rescueSuccesses) / Float(totalImages)
        }

        func printSummary() {
            print("\n╔════════════════════════════════════════════════════════════╗")
            print("║   COMPLETE PIPELINE STATISTICS                             ║")
            print("╚════════════════════════════════════════════════════════════╝")
            print("")
            print("Total Images: \(totalImages)")
            print("First Try Successes: \(firstTrySuccesses) (\(String(format: "%.1f%%", firstTrySuccessRate * 100)))")
            print("Rescue Successes: \(rescueSuccesses) (\(String(format: "%.1f%%", rescueSuccessRate * 100)))")
            print("Failures: \(failures)")
            print("Overall Success Rate: \(String(format: "%.1f%%", overallSuccessRate * 100))")
            print("Average Processing Time: \(String(format: "%.3f", averageProcessingTime))s")

            if !rescueStrategiesUsed.isEmpty {
                print("\nRescue Strategy Effectiveness:")
                for (strategy, count) in rescueStrategiesUsed.sorted(by: { $0.value > $1.value }) {
                    print("  • \(strategy.displayName): \(count) successes")
                }
            }
            print("")
        }
    }

    var stats = Statistics()

    /// Process with statistics tracking
    func detectBibNumberWithStats(in image: CGImage) -> CompletePipelineResult? {
        stats.totalImages += 1

        let result = detectBibNumber(in: image)

        if let result = result {
            if result.usedRescue {
                stats.rescueSuccesses += 1
                if let strategy = result.rescueStrategy {
                    stats.rescueStrategiesUsed[strategy, default: 0] += 1
                }
            } else {
                stats.firstTrySuccesses += 1
            }

            stats.averageProcessingTime = (stats.averageProcessingTime * TimeInterval(stats.totalImages - 1) + result.totalProcessingTime) / TimeInterval(stats.totalImages)
        } else {
            stats.failures += 1
        }

        return result
    }
}

// MARK: - Example Usage

/*
 Example usage:

 // Create complete pipeline with feedback loop
 let pipeline = CompletePipelineFeedbackLoop()

 // Configure
 pipeline.config.enableFeedbackLoop = true
 pipeline.config.maxFeedbackIterations = 2
 pipeline.config.rescueStrategies = [
     .extremeContrast,
     .adaptiveThreshold,
     .combinedRescue
 ]

 // Process single image
 if let result = pipeline.detectBibNumber(in: image) {
     print(result.description)
     print("Bib: \(result.bibNumber)")
     print("Used rescue: \(result.usedRescue)")
     print("Iteration: \(result.iteration)")
 }

 // Process with statistics
 for image in images {
     let result = pipeline.detectBibNumberWithStats(in: image)
 }
 pipeline.stats.printSummary()

 ═══════════════════════════════════════════════════════════════
 COMPLETE FLOW:

 ITERATION 1 (First Try):
   Person Detection → Pose Estimation → Torso Detection → OCR
   ↓
   If SUCCESS → DONE ✓
   If FAILED → Continue to ITERATION 2

 ITERATION 2 (Rescue #1):
   Apply Rescue Enhancement (extreme contrast) on ORIGINAL IMAGE
   ↓
   Person Detection AGAIN → Pose AGAIN → Torso AGAIN → OCR AGAIN
   ↓
   If SUCCESS → DONE ✓
   If FAILED → Continue to ITERATION 3

 ITERATION 3 (Rescue #2):
   Apply Different Rescue Enhancement (adaptive threshold) on ORIGINAL IMAGE
   ↓
   Person Detection AGAIN → Pose AGAIN → Torso AGAIN → OCR AGAIN
   ↓
   If SUCCESS → DONE ✓
   If FAILED → Give up ✗

 ═══════════════════════════════════════════════════════════════

 WHY FULL PIPELINE RESTART IS BETTER:
 1. Enhanced image may improve person detection accuracy
 2. Better person box → better pose estimation
 3. Better pose → better torso region calculation
 4. Better torso → better OCR region
 5. Enhanced image → better OCR results
 = MAXIMUM CHANCE OF SUCCESS!
 */
