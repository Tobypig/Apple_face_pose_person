import Foundation
import Vision
import CoreImage
import CoreGraphics

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Rescue Enhancement Strategy

/// Extreme image enhancement strategies for failed OCR
enum RescueEnhancementStrategy: String, CaseIterable {
    case extremeContrast       // Very high contrast + binarization
    case adaptiveThreshold     // Adaptive thresholding
    case multiScale           // Try multiple scale factors
    case invertColors         // Invert (white text on black background)
    case denoiseHeavy         // Heavy noise reduction
    case combinedRescue       // Combine multiple techniques

    var displayName: String {
        switch self {
        case .extremeContrast: return "Extreme Contrast Enhancement"
        case .adaptiveThreshold: return "Adaptive Threshold Binarization"
        case .multiScale: return "Multi-Scale Enhancement"
        case .invertColors: return "Color Inversion"
        case .denoiseHeavy: return "Heavy Denoising"
        case .combinedRescue: return "Combined Rescue (All Techniques)"
        }
    }
}

// MARK: - Feedback Loop Configuration

struct FeedbackLoopConfiguration {
    var enableFeedbackLoop: Bool = true
    var maxFeedbackIterations: Int = 2        // Maximum rescue attempts
    var rescueStrategies: [RescueEnhancementStrategy] = [
        .extremeContrast,
        .adaptiveThreshold,
        .invertColors,
        .combinedRescue
    ]
    var minimumConfidenceForSuccess: Float = 0.5
    var enableMultiScaleRescue: Bool = true
    var multiScaleFactors: [CGFloat] = [3.0, 5.0, 7.0]  // Extreme upscaling
}

// MARK: - Rescue Image Enhancer

/// Applies extreme enhancement for failed OCR cases
class RescueImageEnhancer {

    private let ciContext = CIContext()

    // MARK: - Rescue Enhancement Methods

    /// Apply extreme contrast enhancement
    func applyExtremeContrast(_ image: CGImage) -> CGImage? {
        var ciImage = CIImage(cgImage: image)

        // 1. Grayscale conversion
        guard let grayscaleFilter = CIFilter(name: "CIColorControls") else {
            return nil
        }
        grayscaleFilter.setValue(ciImage, forKey: kCIInputImageKey)
        grayscaleFilter.setValue(0.0, forKey: kCIInputSaturationKey)
        guard let grayscale = grayscaleFilter.outputImage else {
            return nil
        }

        // 2. Extreme contrast (3.0x)
        guard let contrastFilter = CIFilter(name: "CIColorControls") else {
            return nil
        }
        contrastFilter.setValue(grayscale, forKey: kCIInputImageKey)
        contrastFilter.setValue(3.0, forKey: kCIInputContrastKey)
        contrastFilter.setValue(-0.2, forKey: kCIInputBrightnessKey)
        guard let highContrast = contrastFilter.outputImage else {
            return nil
        }

        // 3. Binarization threshold
        guard let thresholdFilter = CIFilter(name: "CIColorControls") else {
            return nil
        }
        thresholdFilter.setValue(highContrast, forKey: kCIInputImageKey)
        thresholdFilter.setValue(5.0, forKey: kCIInputContrastKey)

        ciImage = thresholdFilter.outputImage ?? ciImage

        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }

    /// Apply adaptive threshold binarization
    func applyAdaptiveThreshold(_ image: CGImage) -> CGImage? {
        let ciImage = CIImage(cgImage: image)

        // Use multiple threshold levels and combine
        let thresholds: [Float] = [0.3, 0.5, 0.7]
        var results: [CIImage] = []

        for threshold in thresholds {
            guard let filter = CIFilter(name: "CIColorControls") else {
                continue
            }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(0.0, forKey: kCIInputSaturationKey)
            filter.setValue(2.5, forKey: kCIInputContrastKey)
            filter.setValue(threshold - 0.5, forKey: kCIInputBrightnessKey)

            if let output = filter.outputImage {
                results.append(output)
            }
        }

        // Use the middle threshold result
        guard results.count >= 2 else {
            return nil
        }

        return ciContext.createCGImage(results[1], from: results[1].extent)
    }

    /// Apply color inversion (white text on black → black text on white)
    func applyColorInversion(_ image: CGImage) -> CGImage? {
        let ciImage = CIImage(cgImage: image)

        guard let invertFilter = CIFilter(name: "CIColorInvert") else {
            return nil
        }
        invertFilter.setValue(ciImage, forKey: kCIInputImageKey)

        guard let inverted = invertFilter.outputImage else {
            return nil
        }

        return ciContext.createCGImage(inverted, from: inverted.extent)
    }

    /// Apply heavy denoising
    func applyHeavyDenoising(_ image: CGImage) -> CGImage? {
        var ciImage = CIImage(cgImage: image)

        // Median filter for noise reduction
        guard let medianFilter = CIFilter(name: "CIMedianFilter") else {
            return nil
        }
        medianFilter.setValue(ciImage, forKey: kCIInputImageKey)
        ciImage = medianFilter.outputImage ?? ciImage

        // Morphological opening (erosion + dilation)
        guard let erodeFilter = CIFilter(name: "CIMorphologyMinimum") else {
            return nil
        }
        erodeFilter.setValue(ciImage, forKey: kCIInputImageKey)
        erodeFilter.setValue(3.0, forKey: kCIInputRadiusKey)

        guard let eroded = erodeFilter.outputImage,
              let dilateFilter = CIFilter(name: "CIMorphologyMaximum") else {
            return nil
        }
        dilateFilter.setValue(eroded, forKey: kCIInputImageKey)
        dilateFilter.setValue(3.5, forKey: kCIInputRadiusKey)

        ciImage = dilateFilter.outputImage ?? ciImage

        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }

    /// Apply multi-scale enhancement (try different scale factors)
    func applyMultiScale(_ image: CGImage, factors: [CGFloat]) -> [CGImage] {
        return factors.compactMap { factor in
            let transform = CGAffineTransform(scaleX: factor, y: factor)
            let ciImage = CIImage(cgImage: image).transformed(by: transform)

            // Apply enhancement to scaled image
            guard let enhanced = applyExtremeContrast(
                ciContext.createCGImage(ciImage, from: ciImage.extent)!
            ) else {
                return nil
            }

            return enhanced
        }
    }

    /// Combined rescue (all techniques)
    func applyCombinedRescue(_ image: CGImage) -> CGImage? {
        var ciImage = CIImage(cgImage: image)

        // 1. Heavy denoising
        if let denoised = applyHeavyDenoising(image) {
            ciImage = CIImage(cgImage: denoised)
        }

        // 2. Extreme contrast
        guard let contrastFilter = CIFilter(name: "CIColorControls") else {
            return nil
        }
        contrastFilter.setValue(ciImage, forKey: kCIInputImageKey)
        contrastFilter.setValue(0.0, forKey: kCIInputSaturationKey)
        contrastFilter.setValue(4.0, forKey: kCIInputContrastKey)
        ciImage = contrastFilter.outputImage ?? ciImage

        // 3. Sharpening
        guard let sharpenFilter = CIFilter(name: "CISharpenLuminance") else {
            return nil
        }
        sharpenFilter.setValue(ciImage, forKey: kCIInputImageKey)
        sharpenFilter.setValue(2.0, forKey: kCIInputSharpnessKey)
        ciImage = sharpenFilter.outputImage ?? ciImage

        // 4. Gamma correction
        guard let gammaFilter = CIFilter(name: "CIGammaAdjust") else {
            return nil
        }
        gammaFilter.setValue(ciImage, forKey: kCIInputImageKey)
        gammaFilter.setValue(1.5, forKey: "inputPower")
        ciImage = gammaFilter.outputImage ?? ciImage

        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }

    // MARK: - Strategy Application

    /// Apply rescue enhancement strategy
    func applyRescueEnhancement(_ image: CGImage,
                                strategy: RescueEnhancementStrategy) -> [CGImage] {
        switch strategy {
        case .extremeContrast:
            if let enhanced = applyExtremeContrast(image) {
                return [enhanced]
            }
            return []

        case .adaptiveThreshold:
            if let enhanced = applyAdaptiveThreshold(image) {
                return [enhanced]
            }
            return []

        case .multiScale:
            return applyMultiScale(image, factors: [3.0, 5.0, 7.0])

        case .invertColors:
            // Try both original and inverted
            var results: [CGImage] = [image]
            if let inverted = applyColorInversion(image) {
                results.append(inverted)
            }
            return results

        case .denoiseHeavy:
            if let enhanced = applyHeavyDenoising(image) {
                return [enhanced]
            }
            return []

        case .combinedRescue:
            if let enhanced = applyCombinedRescue(image) {
                return [enhanced]
            }
            return []
        }
    }
}

// MARK: - Feedback Loop OCR System

/// Multi-pass OCR with feedback loop for failed cases
class FeedbackLoopBibOCR: MultiPassBibOCR {

    var feedbackConfig = FeedbackLoopConfiguration()
    private let rescueEnhancer = RescueImageEnhancer()

    // MARK: - Feedback Loop OCR

    /// Perform OCR with feedback loop on failure
    override func recognizeBibNumber(in image: CGImage,
                                    region: CGRect? = nil) -> BibNumberResult? {
        let startTime = Date()

        // Stage 1: Try standard multi-pass OCR
        print("\n=== Stage 1: Standard Multi-Pass OCR ===")
        if let result = super.recognizeBibNumber(in: image, region: region) {
            if result.adjustedConfidence >= feedbackConfig.minimumConfidenceForSuccess {
                print("✓ Success in Stage 1 (confidence: \(String(format: "%.2f", result.adjustedConfidence)))")
                return result
            }
            print("⚠ Low confidence result: \(String(format: "%.2f", result.adjustedConfidence))")
        } else {
            print("✗ No result in Stage 1")
        }

        // Stage 2: Feedback loop with rescue enhancement
        guard feedbackConfig.enableFeedbackLoop else {
            print("Feedback loop disabled, returning best result")
            return nil
        }

        print("\n=== Stage 2: Rescue Enhancement Feedback Loop ===")

        var bestResult: BibNumberResult?
        var iteration = 0

        // Crop to region if specified
        let targetImage: CGImage
        if let region = region,
           let cropped = image.cropping(to: region) {
            targetImage = cropped
        } else {
            targetImage = image
        }

        // Try each rescue strategy
        for strategy in feedbackConfig.rescueStrategies {
            guard iteration < feedbackConfig.maxFeedbackIterations else {
                print("Reached maximum feedback iterations")
                break
            }
            iteration += 1

            print("\nIteration \(iteration): Applying \(strategy.displayName)...")

            // Apply rescue enhancement
            let rescuedImages = rescueEnhancer.applyRescueEnhancement(targetImage,
                                                                     strategy: strategy)

            print("  Generated \(rescuedImages.count) rescue variant(s)")

            // Feed back to Stage 1 for each rescued image
            for (index, rescuedImage) in rescuedImages.enumerated() {
                print("  Testing variant \(index + 1)...")

                // FEEDBACK: Run full multi-pass pipeline on enhanced image
                if let result = super.recognizeBibNumber(in: rescuedImage, region: nil) {
                    print("  ✓ Detected: \(result.number) (confidence: \(String(format: "%.2f", result.adjustedConfidence)))")

                    // Check if this is good enough
                    if result.adjustedConfidence >= feedbackConfig.minimumConfidenceForSuccess {
                        let totalTime = Date().timeIntervalSince(startTime)

                        var finalResult = result
                        finalResult = BibNumberResult(
                            number: finalResult.number,
                            confidence: finalResult.confidence,
                            boundingBox: finalResult.boundingBox,
                            passName: "\(finalResult.passName ?? "unknown") + Rescue(\(strategy.rawValue))",
                            adjustedConfidence: finalResult.adjustedConfidence,
                            isValidPattern: finalResult.isValidPattern,
                            detectionTime: totalTime
                        )

                        print("\n✓ SUCCESS via Rescue Enhancement!")
                        print("  Strategy: \(strategy.displayName)")
                        print("  Total time: \(String(format: "%.3f", totalTime))s")
                        return finalResult
                    }

                    // Keep track of best result
                    if bestResult == nil || result.adjustedConfidence > bestResult!.adjustedConfidence {
                        bestResult = result
                    }
                } else {
                    print("  ✗ No detection with variant \(index + 1)")
                }
            }
        }

        // Return best result from all attempts
        if let best = bestResult {
            let totalTime = Date().timeIntervalSince(startTime)
            print("\n⚠ Returning best result from all attempts:")
            print("  Number: \(best.number)")
            print("  Confidence: \(String(format: "%.2f", best.adjustedConfidence))")
            print("  Total time: \(String(format: "%.3f", totalTime))s")

            var finalResult = best
            finalResult = BibNumberResult(
                number: finalResult.number,
                confidence: finalResult.confidence,
                boundingBox: finalResult.boundingBox,
                passName: "\(finalResult.passName ?? "unknown") (Low Confidence)",
                adjustedConfidence: finalResult.adjustedConfidence,
                isValidPattern: finalResult.isValidPattern,
                detectionTime: totalTime
            )
            return finalResult
        }

        print("\n✗ All rescue attempts failed")
        return nil
    }

    // MARK: - Statistics

    struct FeedbackLoopStats {
        var totalAttempts: Int = 0
        var stage1Successes: Int = 0
        var stage2Successes: Int = 0
        var failures: Int = 0
        var rescueStrategiesUsed: [RescueEnhancementStrategy: Int] = [:]

        var stage1SuccessRate: Float {
            guard totalAttempts > 0 else { return 0 }
            return Float(stage1Successes) / Float(totalAttempts)
        }

        var stage2SuccessRate: Float {
            guard totalAttempts > 0 else { return 0 }
            return Float(stage2Successes) / Float(totalAttempts)
        }

        var overallSuccessRate: Float {
            guard totalAttempts > 0 else { return 0 }
            return Float(stage1Successes + stage2Successes) / Float(totalAttempts)
        }

        mutating func recordStage1Success() {
            totalAttempts += 1
            stage1Successes += 1
        }

        mutating func recordStage2Success(strategy: RescueEnhancementStrategy) {
            totalAttempts += 1
            stage2Successes += 1
            rescueStrategiesUsed[strategy, default: 0] += 1
        }

        mutating func recordFailure() {
            totalAttempts += 1
            failures += 1
        }

        func printSummary() {
            print("\n=== Feedback Loop Statistics ===")
            print("Total Attempts: \(totalAttempts)")
            print("Stage 1 Successes: \(stage1Successes) (\(String(format: "%.1f%%", stage1SuccessRate * 100)))")
            print("Stage 2 Successes: \(stage2Successes) (\(String(format: "%.1f%%", stage2SuccessRate * 100)))")
            print("Failures: \(failures)")
            print("Overall Success Rate: \(String(format: "%.1f%%", overallSuccessRate * 100))")

            if !rescueStrategiesUsed.isEmpty {
                print("\nRescue Strategies Effectiveness:")
                for (strategy, count) in rescueStrategiesUsed.sorted(by: { $0.value > $1.value }) {
                    print("  \(strategy.displayName): \(count) successes")
                }
            }
        }
    }

    var stats = FeedbackLoopStats()
}

// MARK: - Example Usage

/*
 Example usage:

 // Create feedback loop OCR system
 let ocrSystem = FeedbackLoopBibOCR()

 // Configure feedback loop
 ocrSystem.feedbackConfig.enableFeedbackLoop = true
 ocrSystem.feedbackConfig.maxFeedbackIterations = 2
 ocrSystem.feedbackConfig.rescueStrategies = [
     .extremeContrast,
     .adaptiveThreshold,
     .invertColors,
     .combinedRescue
 ]

 // Perform OCR with feedback loop
 if let result = ocrSystem.recognizeBibNumber(in: image, region: torsoRegion) {
     print("Detected: \(result.number)")
     print("Via: \(result.passName)")  // Shows if rescue was used
     print("Confidence: \(result.adjustedConfidence)")
 }

 // View statistics
 ocrSystem.stats.printSummary()

 // Process Flow:
 // 1. Try standard multi-pass (Pass 1-5)
 // 2. If failed → Apply rescue enhancement
 // 3. Feed enhanced image BACK to Pass 1
 // 4. Try standard multi-pass again on enhanced image
 // 5. Repeat with different rescue strategies
 // 6. Return best result
 */
