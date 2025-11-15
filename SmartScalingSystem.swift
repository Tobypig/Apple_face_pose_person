//
//  SmartScalingSystem.swift
//  Apple Vision Framework - Smart Scaling for OCR Optimization
//
//  Dynamic scale up/down for optimal bib number OCR at different distances
//

import CoreGraphics
import CoreImage
import Vision
import Foundation

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Scaling Modes

/// Image scaling mode for bib region preprocessing
enum ScalingMode {
    case aspectFit      // Scale to fit within target size, maintain aspect ratio
    case aspectFill     // Scale to fill target size, may crop, maintain aspect ratio
    case scaleToFill    // Stretch to fill target size, may distort
    case intelligent    // Automatic mode based on region size analysis
}

/// Distance category based on bib region size
enum DistanceCategory {
    case veryClose      // Partial body, may be cropped (region > 80% of image)
    case close          // Full body, good size (region 40-80% of image)
    case medium         // Normal distance (region 20-40% of image)
    case far            // Small in frame (region 5-20% of image)
    case veryFar        // Very small (region < 5% of image)
}

/// Image quality assessment for OCR readability
struct ImageQualityMetrics {
    let resolution: CGSize          // Actual pixel dimensions
    let estimatedDPI: Float         // Estimated DPI (dots per inch)
    let isOCRReady: Bool           // True if suitable for OCR without scaling
    let recommendedScale: CGFloat   // Recommended scale factor
    let distanceCategory: DistanceCategory
    let pixelDensity: Float        // Pixels per character (estimated)
}

// MARK: - Smart Scaling Manager

class SmartScalingManager {

    // MARK: - Configuration

    /// Target resolution for OCR (optimal readability)
    /// Standard bib numbers: 100-200 pixels height for good OCR
    var targetBibHeight: CGFloat = 150.0

    /// Minimum acceptable resolution for OCR
    var minimumBibHeight: CGFloat = 40.0

    /// Maximum resolution (don't upscale beyond this)
    var maximumBibHeight: CGFloat = 400.0

    /// Minimum DPI for text recognition (OCR standard)
    var minimumDPI: Float = 150.0

    /// Target DPI for optimal OCR
    var targetDPI: Float = 300.0

    /// Enable image enhancement (sharpening, contrast)
    var enableEnhancement: Bool = true

    /// Upscaling algorithm quality
    var useHighQualityUpscaling: Bool = true

    // MARK: - Analysis Methods

    /// Analyze bib region and determine optimal scaling
    /// - Parameters:
    ///   - region: Bib detection region (normalized coordinates)
    ///   - imageSize: Original image size
    /// - Returns: Quality metrics and scaling recommendations
    func analyzeRegionQuality(region: BibDetectionRegion, imageSize: CGSize) -> ImageQualityMetrics {
        // Convert to pixel coordinates
        let pixelRegion = TorsoRegionManager.convertToImageCoordinates(
            region: region,
            imageSize: imageSize
        )

        // Calculate region size relative to image
        let regionArea = pixelRegion.width * pixelRegion.height
        let imageArea = imageSize.width * imageSize.height
        let regionPercentage = Float(regionArea / imageArea)

        // Determine distance category
        let distanceCategory = categorizeDistance(regionPercentage: regionPercentage)

        // Estimate DPI (assuming bib is ~20cm tall, region height in pixels)
        // Typical bib: 15-25cm height, use 20cm average
        let bibPhysicalHeightCM: Float = 20.0
        let pixelsPerCM = Float(pixelRegion.height) / bibPhysicalHeightCM
        let estimatedDPI = pixelsPerCM * 2.54 // Convert cm to inches

        // Calculate recommended scale factor
        let currentHeight = pixelRegion.height
        let recommendedScale = calculateOptimalScale(
            currentHeight: currentHeight,
            distanceCategory: distanceCategory
        )

        // Check if OCR-ready
        let isOCRReady = currentHeight >= minimumBibHeight && estimatedDPI >= minimumDPI

        // Estimate pixel density (pixels per character)
        // Typical bib: 3-4 digits, estimate ~30-40 pixels per character at target resolution
        let estimatedCharacters: Float = 4.0
        let pixelDensity = Float(pixelRegion.height) / estimatedCharacters

        return ImageQualityMetrics(
            resolution: CGSize(width: pixelRegion.width, height: pixelRegion.height),
            estimatedDPI: estimatedDPI,
            isOCRReady: isOCRReady,
            recommendedScale: recommendedScale,
            distanceCategory: distanceCategory,
            pixelDensity: pixelDensity
        )
    }

    /// Categorize distance based on region size
    private func categorizeDistance(regionPercentage: Float) -> DistanceCategory {
        switch regionPercentage {
        case 0.80...:           return .veryClose   // > 80%
        case 0.40..<0.80:       return .close       // 40-80%
        case 0.20..<0.40:       return .medium      // 20-40%
        case 0.05..<0.20:       return .far         // 5-20%
        default:                return .veryFar     // < 5%
        }
    }

    /// Calculate optimal scale factor based on current size and distance
    private func calculateOptimalScale(currentHeight: CGFloat, distanceCategory: DistanceCategory) -> CGFloat {
        switch distanceCategory {
        case .veryClose:
            // Partial body - may need to scale down if cropped
            // Keep original or slightly reduce
            return min(1.0, targetBibHeight / currentHeight)

        case .close:
            // Good size - minimal scaling needed
            if currentHeight >= targetBibHeight {
                return 1.0 // No scaling
            }
            return targetBibHeight / currentHeight

        case .medium:
            // Normal distance - scale to target
            return targetBibHeight / currentHeight

        case .far:
            // Small - aggressive upscaling needed
            let scale = targetBibHeight / currentHeight
            return min(scale, 4.0) // Limit to 4x upscale

        case .veryFar:
            // Very small - maximum upscaling
            let scale = targetBibHeight / currentHeight
            return min(scale, 6.0) // Limit to 6x upscale (quality degrades beyond)
        }
    }

    // MARK: - Scaling Methods

    /// Scale bib region intelligently for optimal OCR
    /// - Parameters:
    ///   - image: Source image
    ///   - region: Bib detection region
    ///   - mode: Scaling mode (default: intelligent)
    /// - Returns: Scaled and optimized image for OCR
    func scaleForOCR(
        image: CGImage,
        region: BibDetectionRegion,
        mode: ScalingMode = .intelligent
    ) -> CGImage? {
        let imageSize = CGSize(width: image.width, height: image.height)

        // Analyze quality
        let metrics = analyzeRegionQuality(region: region, imageSize: imageSize)

        // Crop to region
        guard let croppedImage = TorsoRegionManager.cropToBibRegion(image: image, region: region) else {
            return nil
        }

        // Determine if scaling is needed
        if metrics.isOCRReady && metrics.recommendedScale >= 0.9 && metrics.recommendedScale <= 1.1 {
            // Already optimal, just enhance
            return enableEnhancement ? enhanceForOCR(croppedImage) : croppedImage
        }

        // Calculate target size
        let currentSize = CGSize(width: croppedImage.width, height: croppedImage.height)
        let targetSize = calculateTargetSize(
            currentSize: currentSize,
            scaleFactor: metrics.recommendedScale,
            mode: mode
        )

        // Scale image
        guard var scaledImage = scaleImage(
            croppedImage,
            toSize: targetSize,
            quality: useHighQualityUpscaling
        ) else {
            return croppedImage
        }

        // Enhance for OCR
        if enableEnhancement {
            if let enhanced = enhanceForOCR(scaledImage) {
                scaledImage = enhanced
            }
        }

        return scaledImage
    }

    /// Scale bib region with specific scaling mode
    /// - Parameters:
    ///   - image: Source image
    ///   - region: Bib detection region
    ///   - targetSize: Desired output size
    ///   - mode: Scaling mode
    /// - Returns: Scaled image
    func scaleRegion(
        image: CGImage,
        region: BibDetectionRegion,
        targetSize: CGSize,
        mode: ScalingMode
    ) -> CGImage? {
        // Crop to region
        guard let croppedImage = TorsoRegionManager.cropToBibRegion(image: image, region: region) else {
            return nil
        }

        // Apply scaling mode
        let finalSize = applyScalingMode(
            currentSize: CGSize(width: croppedImage.width, height: croppedImage.height),
            targetSize: targetSize,
            mode: mode
        )

        return scaleImage(croppedImage, toSize: finalSize, quality: useHighQualityUpscaling)
    }

    // MARK: - Private Scaling Utilities

    /// Calculate target size based on mode
    private func calculateTargetSize(
        currentSize: CGSize,
        scaleFactor: CGFloat,
        mode: ScalingMode
    ) -> CGSize {
        switch mode {
        case .intelligent:
            // Scale maintaining aspect ratio
            return CGSize(
                width: currentSize.width * scaleFactor,
                height: currentSize.height * scaleFactor
            )

        case .aspectFit, .aspectFill:
            // Scale to target height, maintain aspect ratio
            let targetHeight = targetBibHeight
            let aspectRatio = currentSize.width / currentSize.height
            return CGSize(
                width: targetHeight * aspectRatio,
                height: targetHeight
            )

        case .scaleToFill:
            // Stretch to fixed size (may distort)
            return CGSize(width: targetBibHeight * 2, height: targetBibHeight)
        }
    }

    /// Apply scaling mode to determine final size
    private func applyScalingMode(
        currentSize: CGSize,
        targetSize: CGSize,
        mode: ScalingMode
    ) -> CGSize {
        switch mode {
        case .aspectFit:
            // Scale to fit within target, maintain aspect ratio
            let widthRatio = targetSize.width / currentSize.width
            let heightRatio = targetSize.height / currentSize.height
            let scale = min(widthRatio, heightRatio)

            return CGSize(
                width: currentSize.width * scale,
                height: currentSize.height * scale
            )

        case .aspectFill:
            // Scale to fill target, maintain aspect ratio (may crop)
            let widthRatio = targetSize.width / currentSize.width
            let heightRatio = targetSize.height / currentSize.height
            let scale = max(widthRatio, heightRatio)

            return CGSize(
                width: currentSize.width * scale,
                height: currentSize.height * scale
            )

        case .scaleToFill:
            // Stretch to exactly fill target (may distort)
            return targetSize

        case .intelligent:
            // Use aspect fit for safety
            return applyScalingMode(currentSize: currentSize, targetSize: targetSize, mode: .aspectFit)
        }
    }

    /// Scale image to target size
    private func scaleImage(_ image: CGImage, toSize size: CGSize, quality: Bool) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        // Set interpolation quality
        if quality {
            context.interpolationQuality = .high
        } else {
            context.interpolationQuality = .medium
        }

        // Draw scaled image
        context.draw(image, in: CGRect(origin: .zero, size: size))

        return context.makeImage()
    }

    // MARK: - Image Enhancement for OCR

    /// Enhance image for better OCR results
    /// - Parameter image: Source image
    /// - Returns: Enhanced image
    private func enhanceForOCR(_ image: CGImage) -> CGImage? {
        let ciImage = CIImage(cgImage: image)

        // Apply enhancement filters
        var enhanced = ciImage

        // 1. Increase sharpness
        if let sharpenFilter = CIFilter(name: "CISharpenLuminance") {
            sharpenFilter.setValue(enhanced, forKey: kCIInputImageKey)
            sharpenFilter.setValue(0.7, forKey: kCIInputSharpnessKey) // 0-1 range
            if let output = sharpenFilter.outputImage {
                enhanced = output
            }
        }

        // 2. Increase contrast for better text separation
        if let contrastFilter = CIFilter(name: "CIColorControls") {
            contrastFilter.setValue(enhanced, forKey: kCIInputImageKey)
            contrastFilter.setValue(1.2, forKey: kCIInputContrastKey)     // Increase contrast
            contrastFilter.setValue(1.0, forKey: kCIInputBrightnessKey)   // Keep brightness
            contrastFilter.setValue(1.0, forKey: kCIInputSaturationKey)   // Keep saturation
            if let output = contrastFilter.outputImage {
                enhanced = output
            }
        }

        // 3. Optional: Convert to grayscale for better text detection (commented out for now)
        // Uncomment if color is causing OCR issues
        /*
        if let grayscaleFilter = CIFilter(name: "CIPhotoEffectNoir") {
            grayscaleFilter.setValue(enhanced, forKey: kCIInputImageKey)
            if let output = grayscaleFilter.outputImage {
                enhanced = output
            }
        }
        */

        // Render to CGImage
        let context = CIContext()
        let extent = enhanced.extent
        return context.createCGImage(enhanced, from: extent)
    }

    // MARK: - Batch Processing

    /// Process multiple regions with smart scaling
    /// - Parameters:
    ///   - image: Source image
    ///   - regions: Array of bib detection regions
    /// - Returns: Array of scaled and enhanced images ready for OCR
    func batchScaleForOCR(
        image: CGImage,
        regions: [BibDetectionRegion]
    ) -> [(region: BibDetectionRegion, scaledImage: CGImage, metrics: ImageQualityMetrics)] {
        var results: [(BibDetectionRegion, CGImage, ImageQualityMetrics)] = []

        for region in regions {
            let imageSize = CGSize(width: image.width, height: image.height)
            let metrics = analyzeRegionQuality(region: region, imageSize: imageSize)

            if let scaledImage = scaleForOCR(image: image, region: region) {
                results.append((region, scaledImage, metrics))
            }
        }

        return results
    }

    // MARK: - Diagnostic Methods

    /// Print scaling analysis for debugging
    /// - Parameters:
    ///   - region: Bib detection region
    ///   - imageSize: Original image size
    func printScalingAnalysis(region: BibDetectionRegion, imageSize: CGSize) {
        let metrics = analyzeRegionQuality(region: region, imageSize: imageSize)

        print("┌─────────────────────────────────────────────┐")
        print("│  Smart Scaling Analysis                    │")
        print("├─────────────────────────────────────────────┤")
        print("│  Distance: \(metrics.distanceCategory)".padding(toLength: 45, withPad: " ", startingAt: 0) + "│")
        print("│  Current Size: \(Int(metrics.resolution.width))x\(Int(metrics.resolution.height))".padding(toLength: 45, withPad: " ", startingAt: 0) + "│")
        print("│  Estimated DPI: \(String(format: "%.1f", metrics.estimatedDPI))".padding(toLength: 45, withPad: " ", startingAt: 0) + "│")
        print("│  OCR Ready: \(metrics.isOCRReady ? "Yes" : "No")".padding(toLength: 45, withPad: " ", startingAt: 0) + "│")
        print("│  Recommended Scale: \(String(format: "%.2fx", metrics.recommendedScale))".padding(toLength: 45, withPad: " ", startingAt: 0) + "│")
        print("│  Pixel Density: \(String(format: "%.1f px/char", metrics.pixelDensity))".padding(toLength: 45, withPad: " ", startingAt: 0) + "│")
        print("└─────────────────────────────────────────────┘")

        // Recommendations
        print("\nRecommendations:")
        switch metrics.distanceCategory {
        case .veryClose:
            print("  • Subject very close - minimal/no scaling needed")
            print("  • May have partial body - check if bib is fully visible")
        case .close:
            print("  • Good distance - optimal for OCR")
            print("  • Minor scaling may improve results")
        case .medium:
            print("  • Normal distance - scale to target resolution")
            print("  • \(String(format: "%.1fx", metrics.recommendedScale)) upscaling recommended")
        case .far:
            print("  • Subject far - aggressive upscaling needed")
            print("  • \(String(format: "%.1fx", metrics.recommendedScale)) upscaling recommended")
            print("  • Consider image enhancement for better results")
        case .veryFar:
            print("  • Subject very far - maximum upscaling required")
            print("  • \(String(format: "%.1fx", metrics.recommendedScale)) upscaling recommended")
            print("  • OCR may be challenging - enhance and retry if fails")
        }
        print()
    }
}

// MARK: - Convenience Extensions

extension SmartScalingManager {

    /// Get scaling recommendation as string
    static func scalingRecommendation(for category: DistanceCategory) -> String {
        switch category {
        case .veryClose: return "Minimal/No scaling (very close)"
        case .close:     return "Light scaling (close)"
        case .medium:    return "Moderate scaling (medium distance)"
        case .far:       return "Aggressive scaling (far)"
        case .veryFar:   return "Maximum scaling (very far)"
        }
    }

    /// Check if upscaling is needed
    static func needsUpscaling(metrics: ImageQualityMetrics) -> Bool {
        return metrics.recommendedScale > 1.1
    }

    /// Check if downscaling is needed
    static func needsDownscaling(metrics: ImageQualityMetrics) -> Bool {
        return metrics.recommendedScale < 0.9
    }
}
