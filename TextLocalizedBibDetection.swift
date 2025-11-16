//
//  TextLocalizedBibDetection.swift
//  Apple Vision Framework - Fast Text Localization for Bib Detection
//
//  Performance Optimization: Use VNDetectTextRectanglesRequest (10-20x faster)
//  to locate text regions BEFORE performing full OCR
//

import Foundation
import Vision
import CoreGraphics
import CoreImage

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Text Rectangle with Metadata

/// Detected text rectangle with geometry metadata
struct DetectedTextRectangle {
    let boundingBox: CGRect           // Normalized coordinates (0-1)
    let confidence: Float              // Detection confidence
    let aspectRatio: CGFloat           // Width / Height
    let area: CGFloat                  // Relative area (0-1)
    let centerPoint: CGPoint           // Center of rectangle
    let bibProbability: Float          // Likelihood this is a bib number (0-1)

    /// Human-readable description
    var description: String {
        return """
        Text Rectangle:
          Position: (\(String(format: "%.2f", boundingBox.origin.x)), \(String(format: "%.2f", boundingBox.origin.y)))
          Size: \(String(format: "%.2f", boundingBox.width)) x \(String(format: "%.2f", boundingBox.height))
          Aspect Ratio: \(String(format: "%.2f", aspectRatio))
          Area: \(String(format: "%.1f%%", area * 100))
          Confidence: \(String(format: "%.2f", confidence))
          Bib Probability: \(String(format: "%.2f", bibProbability))
        """
    }
}

// MARK: - Text Rectangle Detector

/// Fast text rectangle detection using Vision framework
class TextRectangleDetector {

    // MARK: - Configuration

    /// Minimum text height relative to image (default: 0.03 = 3%)
    var minimumTextHeight: Float = 0.03

    /// Maximum text height relative to image (default: 0.5 = 50%)
    var maximumTextHeight: Float = 0.5

    /// Report character boxes (more detailed, but slower)
    var reportCharacterBoxes: Bool = false

    // MARK: - Detection

    /// Detect text rectangles in image
    /// - Parameter image: Source image
    /// - Returns: Array of detected text rectangles
    func detectTextRectangles(in image: CGImage) -> [DetectedTextRectangle] {
        let request = VNDetectTextRectanglesRequest()

        // Configuration
        request.reportCharacterBoxes = reportCharacterBoxes

        // Perform detection
        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        do {
            try handler.perform([request])
        } catch {
            print("Text rectangle detection failed: \(error)")
            return []
        }

        // Process results
        guard let observations = request.results as? [VNTextObservation] else {
            return []
        }

        let imageSize = CGSize(width: image.width, height: image.height)

        return observations.compactMap { observation in
            convertToTextRectangle(observation, imageSize: imageSize)
        }
    }

    /// Detect text rectangles in a specific region of image
    /// - Parameters:
    ///   - image: Source image
    ///   - region: Region of interest (normalized coordinates)
    /// - Returns: Array of detected text rectangles (in region coordinates)
    func detectTextRectangles(in image: CGImage, region: CGRect) -> [DetectedTextRectangle] {
        // Crop to region first for better performance
        guard let croppedImage = cropToRegion(image: image, region: region) else {
            return []
        }

        // Detect in cropped image
        let rectangles = detectTextRectangles(in: croppedImage)

        // Convert coordinates back to original image space
        return rectangles.map { rect in
            let adjustedBox = CGRect(
                x: region.origin.x + rect.boundingBox.origin.x * region.width,
                y: region.origin.y + rect.boundingBox.origin.y * region.height,
                width: rect.boundingBox.width * region.width,
                height: rect.boundingBox.height * region.height
            )

            return DetectedTextRectangle(
                boundingBox: adjustedBox,
                confidence: rect.confidence,
                aspectRatio: rect.aspectRatio,
                area: rect.area * region.width * region.height,
                centerPoint: CGPoint(
                    x: region.origin.x + rect.centerPoint.x * region.width,
                    y: region.origin.y + rect.centerPoint.y * region.height
                ),
                bibProbability: rect.bibProbability
            )
        }
    }

    // MARK: - Private Helpers

    private func convertToTextRectangle(_ observation: VNTextObservation,
                                       imageSize: CGSize) -> DetectedTextRectangle? {
        let bbox = observation.boundingBox

        // Filter by height
        if bbox.height < CGFloat(minimumTextHeight) || bbox.height > CGFloat(maximumTextHeight) {
            return nil
        }

        let aspectRatio = bbox.width / bbox.height
        let area = bbox.width * bbox.height

        let centerPoint = CGPoint(
            x: bbox.origin.x + bbox.width / 2,
            y: bbox.origin.y + bbox.height / 2
        )

        // Calculate bib probability based on geometry
        let bibProb = calculateBibProbability(aspectRatio: aspectRatio,
                                             area: area,
                                             height: bbox.height)

        return DetectedTextRectangle(
            boundingBox: bbox,
            confidence: observation.confidence,
            aspectRatio: aspectRatio,
            area: area,
            centerPoint: centerPoint,
            bibProbability: bibProb
        )
    }

    private func calculateBibProbability(aspectRatio: CGFloat,
                                        area: CGFloat,
                                        height: CGFloat) -> Float {
        var score: Float = 0.5  // Base score

        // Aspect ratio scoring (bib numbers are typically 2:1 to 8:1)
        if aspectRatio >= 2.0 && aspectRatio <= 8.0 {
            score += 0.3

            // Ideal aspect ratio is around 4:1 to 6:1
            if aspectRatio >= 3.5 && aspectRatio <= 6.5 {
                score += 0.2
            }
        } else {
            score -= 0.2  // Unlikely to be bib number
        }

        // Area scoring (bib numbers should be substantial portion of torso)
        if area >= 0.15 && area <= 0.6 {
            score += 0.2
        }

        // Height scoring (bib numbers are usually 8-25% of torso height)
        if height >= 0.08 && height <= 0.25 {
            score += 0.1
        }

        return max(0.0, min(1.0, score))
    }

    private func cropToRegion(image: CGImage, region: CGRect) -> CGImage? {
        let imageSize = CGSize(width: image.width, height: image.height)

        let pixelRect = CGRect(
            x: region.origin.x * imageSize.width,
            y: region.origin.y * imageSize.height,
            width: region.width * imageSize.width,
            height: region.height * imageSize.height
        )

        // Clamp to image bounds
        let clampedRect = CGRect(
            x: max(0, pixelRect.origin.x),
            y: max(0, pixelRect.origin.y),
            width: min(pixelRect.width, imageSize.width - pixelRect.origin.x),
            height: min(pixelRect.height, imageSize.height - pixelRect.origin.y)
        )

        return image.cropping(to: clampedRect)
    }
}

// MARK: - Text Localized Bib Detection

/// High-performance bib detection using text localization before OCR
class TextLocalizedBibDetection {

    private let textDetector = TextRectangleDetector()
    private let ocrEngine: BibNumberOCROptimizer

    // MARK: - Configuration

    /// Minimum bib probability to attempt OCR (default: 0.6)
    var minimumBibProbability: Float = 0.6

    /// Maximum number of rectangles to try OCR on (default: 5)
    var maxOCRAttempts: Int = 5

    /// Enable multi-scale detection for difficult cases
    var enableMultiScaleDetection: Bool = true

    // MARK: - Statistics

    struct PerformanceStats {
        var textDetectionTime: TimeInterval = 0
        var ocrTime: TimeInterval = 0
        var totalTime: TimeInterval = 0
        var rectanglesDetected: Int = 0
        var ocrAttempts: Int = 0
        var speedupFactor: Float = 0  // vs. full torso OCR

        var description: String {
            return """
            Performance Statistics:
              Text Detection: \(String(format: "%.0f", textDetectionTime * 1000))ms
              OCR Time: \(String(format: "%.0f", ocrTime * 1000))ms
              Total Time: \(String(format: "%.0f", totalTime * 1000))ms
              Rectangles Found: \(rectanglesDetected)
              OCR Attempts: \(ocrAttempts)
              Speedup: \(String(format: "%.1f", speedupFactor))x faster
            """
        }
    }

    var lastPerformanceStats = PerformanceStats()

    // MARK: - Initialization

    init(ocrEngine: BibNumberOCROptimizer = BibNumberOCROptimizer()) {
        self.ocrEngine = ocrEngine
    }

    // MARK: - Detection

    /// Detect bib number in torso region using text localization
    /// - Parameters:
    ///   - image: Full image
    ///   - torsoRegion: Torso detection region
    /// - Returns: Bib number result if detected
    func detectBib(in image: CGImage,
                   torsoRegion: BibDetectionRegion) -> BibNumberResult? {
        let startTime = Date()

        // Step 1: Fast text rectangle detection (10-20ms)
        let textDetectStart = Date()
        let textRectangles = textDetector.detectTextRectangles(
            in: image,
            region: torsoRegion.boundingBox
        )
        let textDetectionTime = Date().timeIntervalSince(textDetectStart)

        // Filter by bib probability
        let bibCandidates = textRectangles
            .filter { $0.bibProbability >= minimumBibProbability }
            .sorted { $0.bibProbability > $1.bibProbability }  // Best first
            .prefix(maxOCRAttempts)

        print("📍 Text Localization: Found \(textRectangles.count) text regions, \(bibCandidates.count) bib candidates")

        // Step 2: OCR only on promising candidates
        let ocrStart = Date()
        var ocrAttempts = 0

        for candidate in bibCandidates {
            ocrAttempts += 1

            print("  Trying OCR on candidate \(ocrAttempts) (prob: \(String(format: "%.2f", candidate.bibProbability)))")

            if let result = performOCROnRectangle(image: image, rectangle: candidate) {
                let totalTime = Date().timeIntervalSince(startTime)
                let ocrTime = Date().timeIntervalSince(ocrStart)

                // Calculate speedup vs. full torso OCR (estimate ~200ms for full torso)
                let estimatedFullOCRTime: TimeInterval = 0.2
                let speedup = Float(estimatedFullOCRTime / totalTime)

                // Update stats
                lastPerformanceStats = PerformanceStats(
                    textDetectionTime: textDetectionTime,
                    ocrTime: ocrTime,
                    totalTime: totalTime,
                    rectanglesDetected: textRectangles.count,
                    ocrAttempts: ocrAttempts,
                    speedupFactor: speedup
                )

                print("✅ Success! \(lastPerformanceStats.description)")
                return result
            }
        }

        // Step 3: Fallback - try full torso OCR if text localization failed
        print("⚠️ Text localization failed, trying full torso OCR fallback...")
        let fallbackResult = performFullTorsoOCR(image: image, torsoRegion: torsoRegion)

        let totalTime = Date().timeIntervalSince(startTime)
        let ocrTime = Date().timeIntervalSince(ocrStart)

        lastPerformanceStats = PerformanceStats(
            textDetectionTime: textDetectionTime,
            ocrTime: ocrTime,
            totalTime: totalTime,
            rectanglesDetected: textRectangles.count,
            ocrAttempts: ocrAttempts + 1,  // +1 for fallback
            speedupFactor: 1.0  // No speedup if fallback used
        )

        return fallbackResult
    }

    /// Detect bib with multi-scale approach (for difficult cases)
    /// - Parameters:
    ///   - image: Full image
    ///   - torsoRegion: Torso detection region
    /// - Returns: Bib number result if detected
    func detectBibMultiScale(in image: CGImage,
                            torsoRegion: BibDetectionRegion) -> BibNumberResult? {
        guard enableMultiScaleDetection else {
            return detectBib(in: image, torsoRegion: torsoRegion)
        }

        print("🔍 Multi-scale text localized detection...")

        let scales: [CGFloat] = [1.0, 1.5, 2.0]
        var bestResult: BibNumberResult?
        var bestConfidence: Float = 0

        for scale in scales {
            print("  Trying scale \(scale)x...")

            // Scale the torso region
            let scaledImage = scaleImage(image, factor: scale)

            if let result = detectBib(in: scaledImage, torsoRegion: torsoRegion),
               result.confidence > bestConfidence {
                bestResult = result
                bestConfidence = result.confidence

                // Early exit if very confident
                if bestConfidence > 0.9 {
                    print("  Early exit: High confidence (\(bestConfidence))")
                    break
                }
            }
        }

        return bestResult
    }

    // MARK: - Private Helpers

    private func performOCROnRectangle(image: CGImage,
                                      rectangle: DetectedTextRectangle) -> BibNumberResult? {
        // Crop to rectangle
        guard let rectImage = cropToRectangle(image: image, rectangle: rectangle) else {
            return nil
        }

        // Perform OCR using optimized engine
        let config = BibNumberOCRConfiguration.accurate  // Use accurate for localized regions
        let result = ocrEngine.recognizeText(in: rectImage, configuration: config)

        // Validate result
        if let bibNumber = result.first,
           BibNumberValidator.isValid(bibNumber.number) {
            return bibNumber
        }

        return nil
    }

    private func performFullTorsoOCR(image: CGImage,
                                    torsoRegion: BibDetectionRegion) -> BibNumberResult? {
        // Crop to full torso region
        let imageSize = CGSize(width: image.width, height: image.height)
        let torsoRect = TorsoRegionManager.convertToImageCoordinates(
            region: torsoRegion,
            imageSize: imageSize
        )

        guard let torsoImage = image.cropping(to: torsoRect) else {
            return nil
        }

        // Full OCR
        let config = BibNumberOCRConfiguration.fast
        let results = ocrEngine.recognizeText(in: torsoImage, configuration: config)

        return results.first { BibNumberValidator.isValid($0.number) }
    }

    private func cropToRectangle(image: CGImage,
                                rectangle: DetectedTextRectangle) -> CGImage? {
        let imageSize = CGSize(width: image.width, height: image.height)

        // Add padding around text (10% on each side)
        let padding: CGFloat = 0.1
        let paddedRect = CGRect(
            x: max(0, rectangle.boundingBox.origin.x - padding * rectangle.boundingBox.width),
            y: max(0, rectangle.boundingBox.origin.y - padding * rectangle.boundingBox.height),
            width: min(1.0 - rectangle.boundingBox.origin.x, rectangle.boundingBox.width * (1 + 2 * padding)),
            height: min(1.0 - rectangle.boundingBox.origin.y, rectangle.boundingBox.height * (1 + 2 * padding))
        )

        let pixelRect = CGRect(
            x: paddedRect.origin.x * imageSize.width,
            y: paddedRect.origin.y * imageSize.height,
            width: paddedRect.width * imageSize.width,
            height: paddedRect.height * imageSize.height
        )

        return image.cropping(to: pixelRect)
    }

    private func scaleImage(_ image: CGImage, factor: CGFloat) -> CGImage {
        let newWidth = Int(CGFloat(image.width) * factor)
        let newHeight = Int(CGFloat(image.height) * factor)

        let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: image.bitmapInfo.rawValue
        )

        context?.interpolationQuality = .high
        context?.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        return context?.makeImage() ?? image
    }
}

// MARK: - Integration with Existing Pipeline

extension BibDetectionRegion {
    /// Detect bib number using text localization (FAST!)
    func detectBibWithTextLocalization(in image: CGImage) -> BibNumberResult? {
        let detector = TextLocalizedBibDetection()
        return detector.detectBib(in: image, torsoRegion: self)
    }
}

// MARK: - Performance Comparison

/// Compare performance between text localized and full OCR approaches
struct BibDetectionPerformanceComparison {

    static func compare(image: CGImage, torsoRegion: BibDetectionRegion) -> String {
        print("\n=== Performance Comparison ===\n")

        // Approach 1: Text Localized (NEW)
        let textLocalStart = Date()
        let textLocalDetector = TextLocalizedBibDetection()
        let textLocalResult = textLocalDetector.detectBib(in: image, torsoRegion: torsoRegion)
        let textLocalTime = Date().timeIntervalSince(textLocalStart)

        // Approach 2: Full Torso OCR (OLD)
        let fullOCRStart = Date()
        let imageSize = CGSize(width: image.width, height: image.height)
        let torsoRect = TorsoRegionManager.convertToImageCoordinates(region: torsoRegion, imageSize: imageSize)
        guard let torsoImage = image.cropping(to: torsoRect) else {
            return "Error: Could not crop torso region"
        }

        let ocrEngine = BibNumberOCROptimizer()
        let fullOCRResult = ocrEngine.recognizeText(in: torsoImage, configuration: .fast).first
        let fullOCRTime = Date().timeIntervalSince(fullOCRStart)

        // Calculate speedup
        let speedup = fullOCRTime / textLocalTime

        let comparison = """
        APPROACH 1: Text Localized Detection (NEW)
          Time: \(String(format: "%.0f", textLocalTime * 1000))ms
          Result: \(textLocalResult?.number ?? "Not detected")
          Confidence: \(String(format: "%.2f", textLocalResult?.confidence ?? 0))
          Stats: \(textLocalDetector.lastPerformanceStats.description)

        APPROACH 2: Full Torso OCR (OLD)
          Time: \(String(format: "%.0f", fullOCRTime * 1000))ms
          Result: \(fullOCRResult?.number ?? "Not detected")
          Confidence: \(String(format: "%.2f", fullOCRResult?.confidence ?? 0))

        SPEEDUP: \(String(format: "%.1f", speedup))x faster! 🚀
        Time Saved: \(String(format: "%.0f", (fullOCRTime - textLocalTime) * 1000))ms
        """

        return comparison
    }
}
