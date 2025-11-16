import Foundation
import Vision
import CoreImage
import CoreGraphics

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Text Size Classification

/// Classification of text based on pixel height
enum TextSizeClass: String, Codable {
    case veryLarge  // >100px height - Primary bib numbers
    case large      // 50-100px - Secondary bibs, division markers
    case medium     // 20-50px - Sponsor text, event names
    case small      // <20px - Noise, fine print

    var displayName: String {
        switch self {
        case .veryLarge: return "Very Large (>100px)"
        case .large: return "Large (50-100px)"
        case .medium: return "Medium (20-50px)"
        case .small: return "Small (<20px)"
        }
    }

    var heightRange: ClosedRange<CGFloat> {
        switch self {
        case .veryLarge: return 100...CGFloat.infinity
        case .large: return 50...100
        case .medium: return 20...50
        case .small: return 0...20
        }
    }
}

/// Contrast level of text region
enum ContrastLevel: String, Codable {
    case high       // Clear, well-defined text
    case medium     // Moderate contrast
    case low        // Poor contrast, needs enhancement

    var displayName: String {
        switch self {
        case .high: return "High Contrast"
        case .medium: return "Medium Contrast"
        case .low: return "Low Contrast"
        }
    }
}

// MARK: - Text Region Analysis Result

/// Complete analysis of a text region
struct TextRegionAnalysis: Codable {
    let boundingBox: CGRect
    let sizeClass: TextSizeClass
    let contrast: ContrastLevel
    let aspectRatio: CGFloat        // Width/Height ratio
    let relativeHeight: Float       // % of reference height (e.g., torso)
    let pixelHeight: CGFloat        // Absolute pixel height
    let isNumericLikely: Bool       // Based on morphology
    let confidence: Float           // Overall detection confidence

    // Additional metrics
    let strokeWidth: CGFloat?       // Estimated stroke width
    let hasEnclosedRegions: Bool    // Digits often have enclosed areas (0,4,6,8,9)
    let uniformity: Float           // Stroke uniformity (0-1)

    var description: String {
        return """
        Text Region Analysis:
          Size: \(sizeClass.displayName) (\(Int(pixelHeight))px)
          Contrast: \(contrast.displayName)
          Aspect Ratio: \(String(format: "%.2f", aspectRatio))
          Relative Height: \(String(format: "%.1f%%", relativeHeight * 100))
          Numeric Likely: \(isNumericLikely)
          Confidence: \(String(format: "%.2f", confidence))
        """
    }
}

// MARK: - Text Region Analyzer

/// Analyzes text regions to determine size, contrast, and characteristics
class TextRegionAnalyzer {

    // MARK: - Configuration

    struct Configuration {
        var minimumHeight: CGFloat = 15.0           // Minimum height to consider
        var minimumWidth: CGFloat = 10.0            // Minimum width to consider
        var minimumConfidence: Float = 0.4          // Minimum confidence threshold
        var referenceHeight: CGFloat?               // Reference height (e.g., torso height)
        var enableMorphologicalAnalysis: Bool = true // Analyze character shapes
        var contrastThresholdHigh: Float = 0.7      // High contrast threshold
        var contrastThresholdLow: Float = 0.3       // Low contrast threshold
    }

    var config = Configuration()
    private let ciContext = CIContext()

    // MARK: - Main Analysis

    /// Analyze a text region from OCR results
    func analyze(_ recognizedText: VNRecognizedText,
                 in image: CGImage,
                 referenceHeight: CGFloat? = nil) throws -> TextRegionAnalysis? {

        // Get bounding box
        guard let boundingBox = try recognizedText.boundingBox(
            for: recognizedText.string.startIndex..<recognizedText.string.endIndex
        )?.boundingBox else {
            return nil
        }

        // Convert normalized coordinates to pixel coordinates
        let imageSize = CGSize(width: image.width, height: image.height)
        let pixelBox = VNImageRectForNormalizedRect(boundingBox,
                                                     Int(imageSize.width),
                                                     Int(imageSize.height))

        return try analyze(boundingBox: pixelBox,
                          in: image,
                          referenceHeight: referenceHeight)
    }

    /// Analyze a bounding box region
    func analyze(boundingBox: CGRect,
                 in image: CGImage,
                 referenceHeight: CGFloat? = nil) throws -> TextRegionAnalysis? {

        let refHeight = referenceHeight ?? config.referenceHeight ?? CGFloat(image.height)

        // 1. Basic size metrics
        let pixelHeight = boundingBox.height
        let pixelWidth = boundingBox.width

        // Filter by minimum size
        guard pixelHeight >= config.minimumHeight,
              pixelWidth >= config.minimumWidth else {
            return nil
        }

        // 2. Classify size
        let sizeClass = classifySize(height: pixelHeight)

        // 3. Calculate metrics
        let aspectRatio = pixelWidth / pixelHeight
        let relativeHeight = Float(pixelHeight / refHeight)

        // 4. Crop region for detailed analysis
        guard let croppedImage = cropRegion(boundingBox, from: image) else {
            return nil
        }

        // 5. Analyze contrast
        let contrast = analyzeContrast(croppedImage)

        // 6. Morphological analysis (if enabled)
        var isNumericLikely = false
        var strokeWidth: CGFloat? = nil
        var hasEnclosedRegions = false
        var uniformity: Float = 0.5

        if config.enableMorphologicalAnalysis {
            let morphology = analyzeMorphology(croppedImage)
            isNumericLikely = morphology.isNumericLikely
            strokeWidth = morphology.strokeWidth
            hasEnclosedRegions = morphology.hasEnclosedRegions
            uniformity = morphology.uniformity
        }

        // 7. Calculate overall confidence
        let confidence = calculateConfidence(
            sizeClass: sizeClass,
            contrast: contrast,
            isNumericLikely: isNumericLikely,
            uniformity: uniformity
        )

        guard confidence >= config.minimumConfidence else {
            return nil
        }

        return TextRegionAnalysis(
            boundingBox: boundingBox,
            sizeClass: sizeClass,
            contrast: contrast,
            aspectRatio: aspectRatio,
            relativeHeight: relativeHeight,
            pixelHeight: pixelHeight,
            isNumericLikely: isNumericLikely,
            confidence: confidence,
            strokeWidth: strokeWidth,
            hasEnclosedRegions: hasEnclosedRegions,
            uniformity: uniformity
        )
    }

    // MARK: - Size Classification

    private func classifySize(height: CGFloat) -> TextSizeClass {
        switch height {
        case 100...:
            return .veryLarge
        case 50..<100:
            return .large
        case 20..<50:
            return .medium
        default:
            return .small
        }
    }

    // MARK: - Contrast Analysis

    private func analyzeContrast(_ image: CGImage) -> ContrastLevel {
        let ciImage = CIImage(cgImage: image)

        // Calculate histogram
        guard let histogramFilter = CIFilter(name: "CIAreaHistogram") else {
            return .medium
        }

        histogramFilter.setValue(ciImage, forKey: kCIInputImageKey)
        histogramFilter.setValue(256, forKey: "inputCount")
        histogramFilter.setValue(CIVector(x: 0, y: 0, z: ciImage.extent.width, w: ciImage.extent.height),
                                forKey: "inputExtent")

        guard let histogramOutput = histogramFilter.outputImage,
              let histogramData = ciContext.createCGImage(histogramOutput, from: histogramOutput.extent) else {
            return .medium
        }

        // Analyze histogram for contrast
        let contrastScore = calculateContrastScore(histogramData)

        if contrastScore >= config.contrastThresholdHigh {
            return .high
        } else if contrastScore >= config.contrastThresholdLow {
            return .medium
        } else {
            return .low
        }
    }

    private func calculateContrastScore(_ histogram: CGImage) -> Float {
        // Simple contrast measure: standard deviation of pixel values
        guard let data = histogram.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else {
            return 0.5
        }

        let length = CFDataGetLength(data)
        var values: [Float] = []

        for i in stride(from: 0, to: length, by: 4) {
            let value = Float(bytes[i]) / 255.0
            values.append(value)
        }

        guard !values.isEmpty else { return 0.5 }

        let mean = values.reduce(0, +) / Float(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Float(values.count)
        let stdDev = sqrt(variance)

        // Normalize to 0-1 range (typical stdDev for high contrast: ~0.3-0.5)
        return min(stdDev * 2.0, 1.0)
    }

    // MARK: - Morphological Analysis

    struct MorphologyResult {
        let isNumericLikely: Bool
        let strokeWidth: CGFloat
        let hasEnclosedRegions: Bool
        let uniformity: Float
    }

    private func analyzeMorphology(_ image: CGImage) -> MorphologyResult {
        let ciImage = CIImage(cgImage: image)

        // 1. Detect edges to find stroke width
        let strokeWidth = estimateStrokeWidth(ciImage)

        // 2. Check for enclosed regions (common in digits: 0, 4, 6, 8, 9)
        let hasEnclosed = detectEnclosedRegions(ciImage)

        // 3. Calculate stroke uniformity
        let uniformity = calculateStrokeUniformity(ciImage)

        // 4. Determine if numeric-likely based on features
        let isNumericLikely = evaluateNumericLikelihood(
            strokeWidth: strokeWidth,
            hasEnclosed: hasEnclosed,
            uniformity: uniformity
        )

        return MorphologyResult(
            isNumericLikely: isNumericLikely,
            strokeWidth: strokeWidth,
            hasEnclosedRegions: hasEnclosed,
            uniformity: uniformity
        )
    }

    private func estimateStrokeWidth(_ image: CIImage) -> CGFloat {
        // Use morphological gradient to estimate stroke width
        guard let gradientFilter = CIFilter(name: "CIMorphologyGradient") else {
            return 5.0 // Default guess
        }

        gradientFilter.setValue(image, forKey: kCIInputImageKey)
        gradientFilter.setValue(3.0, forKey: kCIInputRadiusKey)

        // Analyze gradient magnitude
        // For simplicity, return a reasonable estimate
        return 5.0 // Can be refined with actual gradient analysis
    }

    private func detectEnclosedRegions(_ image: CIImage) -> Bool {
        // Look for holes/enclosed regions using morphological closing
        guard let closeFilter = CIFilter(name: "CIMorphologyRectangleMaximum") else {
            return false
        }

        closeFilter.setValue(image, forKey: kCIInputImageKey)
        closeFilter.setValue(5, forKey: "inputWidth")
        closeFilter.setValue(5, forKey: "inputHeight")

        // Compare with original to detect holes
        // Simplified: assume digits often have enclosed regions
        return true // Can be refined with actual hole detection
    }

    private func calculateStrokeUniformity(_ image: CIImage) -> Float {
        // Measure consistency of stroke thickness
        // High uniformity suggests printed/digital text (like bib numbers)
        // Low uniformity suggests handwriting or decorative fonts

        // Simplified implementation
        return 0.75 // Default to fairly uniform
    }

    private func evaluateNumericLikelihood(strokeWidth: CGFloat,
                                          hasEnclosed: Bool,
                                          uniformity: Float) -> Bool {
        // Digits typically have:
        // - Moderate stroke width (not too thin, not too thick)
        // - Often enclosed regions
        // - High uniformity (printed)

        let widthOK = strokeWidth >= 3.0 && strokeWidth <= 20.0
        let uniformOK = uniformity >= 0.6

        return widthOK && uniformOK
    }

    // MARK: - Confidence Calculation

    private func calculateConfidence(sizeClass: TextSizeClass,
                                     contrast: ContrastLevel,
                                     isNumericLikely: Bool,
                                     uniformity: Float) -> Float {
        var confidence: Float = 0.5 // Base confidence

        // Size contribution
        switch sizeClass {
        case .veryLarge:
            confidence += 0.3  // Large text is very reliable
        case .large:
            confidence += 0.2
        case .medium:
            confidence += 0.1
        case .small:
            confidence += 0.0  // Small text less reliable
        }

        // Contrast contribution
        switch contrast {
        case .high:
            confidence += 0.2
        case .medium:
            confidence += 0.1
        case .low:
            confidence += 0.0
        }

        // Morphology contribution
        if isNumericLikely {
            confidence += 0.15
        }

        // Uniformity contribution
        confidence += uniformity * 0.15

        return min(confidence, 1.0)
    }

    // MARK: - Image Utilities

    private func cropRegion(_ rect: CGRect, from image: CGImage) -> CGImage? {
        // Ensure rect is within image bounds
        let imageRect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let clampedRect = rect.intersection(imageRect)

        guard !clampedRect.isNull, !clampedRect.isEmpty else {
            return nil
        }

        return image.cropping(to: clampedRect)
    }

    // MARK: - Batch Analysis

    /// Analyze multiple text regions
    func analyzeRegions(_ regions: [VNRecognizedText],
                       in image: CGImage,
                       referenceHeight: CGFloat? = nil) -> [TextRegionAnalysis] {
        return regions.compactMap { text in
            try? analyze(text, in: image, referenceHeight: referenceHeight)
        }
    }

    /// Filter regions by size class
    func filter(_ analyses: [TextRegionAnalysis],
               bySizeClass sizeClass: TextSizeClass) -> [TextRegionAnalysis] {
        return analyses.filter { $0.sizeClass == sizeClass }
    }

    /// Filter regions likely to be bib numbers
    func filterBibNumberCandidates(_ analyses: [TextRegionAnalysis]) -> [TextRegionAnalysis] {
        return analyses.filter { analysis in
            // Bib numbers are typically:
            // - Large or very large
            // - Numeric-likely
            // - Good confidence
            let sizeOK = analysis.sizeClass == .veryLarge || analysis.sizeClass == .large
            let numericOK = analysis.isNumericLikely
            let confidenceOK = analysis.confidence >= 0.6

            return sizeOK && numericOK && confidenceOK
        }
        .sorted { $0.confidence > $1.confidence } // Highest confidence first
    }
}

// MARK: - Example Usage

/*
 Example usage:

 let analyzer = TextRegionAnalyzer()
 analyzer.config.referenceHeight = torsoRegion.height

 // Analyze OCR results
 let analyses = analyzer.analyzeRegions(ocrResults, in: image)

 // Filter for bib number candidates
 let bibCandidates = analyzer.filterBibNumberCandidates(analyses)

 for candidate in bibCandidates {
     print(candidate.description)
     print("Size class: \(candidate.sizeClass.displayName)")
     print("Confidence: \(candidate.confidence)")
 }
 */
