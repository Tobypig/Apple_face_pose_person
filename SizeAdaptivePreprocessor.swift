import Foundation
import CoreImage
import CoreGraphics

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Preprocessing Profile

/// Preprocessing profile for different text sizes
enum PreprocessingProfile {
    case minimal                // For very large, clear text
    case standard              // For large text
    case enhanced              // For medium text
    case aggressive            // For small text
    case veryAggressive        // For very small/distant text
    case largeNumberOptimized  // Optimized for large bib numbers
    case sizeAdaptive          // Automatically adapt based on size

    var displayName: String {
        switch self {
        case .minimal: return "Minimal (Large Clear Text)"
        case .standard: return "Standard (Large Text)"
        case .enhanced: return "Enhanced (Medium Text)"
        case .aggressive: return "Aggressive (Small Text)"
        case .veryAggressive: return "Very Aggressive (Tiny Text)"
        case .largeNumberOptimized: return "Large Number Optimized"
        case .sizeAdaptive: return "Size Adaptive"
        }
    }
}

// MARK: - Preprocessing Configuration

/// Configuration for image preprocessing
struct PreprocessingConfiguration {
    var upscaleFactor: CGFloat = 1.0
    var sharpness: Float = 0.0           // 0-2.0
    var contrast: Float = 1.0            // 0.5-2.0
    var brightness: Float = 0.0          // -0.5 to 0.5
    var edgeIntensity: Float = 0.0       // 0-5.0
    var enableBinarization: Bool = false
    var enableMorphology: Bool = false   // Noise removal
    var enableGamma: Bool = false
    var gammaValue: Float = 1.0          // 0.5-2.0

    static func forProfile(_ profile: PreprocessingProfile) -> PreprocessingConfiguration {
        switch profile {
        case .minimal:
            return PreprocessingConfiguration(
                upscaleFactor: 1.0,
                sharpness: 0.3,
                contrast: 1.1,
                edgeIntensity: 0.0,
                enableBinarization: false
            )

        case .standard:
            return PreprocessingConfiguration(
                upscaleFactor: 1.0,
                sharpness: 0.7,
                contrast: 1.2,
                edgeIntensity: 0.5,
                enableBinarization: false
            )

        case .enhanced:
            return PreprocessingConfiguration(
                upscaleFactor: 1.5,
                sharpness: 1.0,
                contrast: 1.4,
                brightness: 0.05,
                edgeIntensity: 1.0,
                enableBinarization: false,
                enableMorphology: true
            )

        case .aggressive:
            return PreprocessingConfiguration(
                upscaleFactor: 2.5,
                sharpness: 1.3,
                contrast: 1.6,
                brightness: 0.08,
                edgeIntensity: 1.5,
                enableBinarization: true,
                enableMorphology: true,
                enableGamma: true,
                gammaValue: 1.1
            )

        case .veryAggressive:
            return PreprocessingConfiguration(
                upscaleFactor: 5.0,
                sharpness: 1.5,
                contrast: 1.8,
                brightness: 0.1,
                edgeIntensity: 2.0,
                enableBinarization: true,
                enableMorphology: true,
                enableGamma: true,
                gammaValue: 1.2
            )

        case .largeNumberOptimized:
            return PreprocessingConfiguration(
                upscaleFactor: 1.0,
                sharpness: 0.5,
                contrast: 1.3,
                edgeIntensity: 3.0,        // Strong edge detection
                enableBinarization: true,   // Convert to pure B&W
                enableMorphology: true,
                enableGamma: false
            )

        case .sizeAdaptive:
            return PreprocessingConfiguration() // Will be set adaptively
        }
    }
}

// MARK: - Size-Adaptive Preprocessor

/// Preprocesses images adaptively based on text size
class SizeAdaptivePreprocessor {

    private let ciContext = CIContext()

    // MARK: - Main Preprocessing

    /// Preprocess image using specified profile
    func preprocess(_ image: CGImage,
                   profile: PreprocessingProfile) -> CGImage? {
        let config = PreprocessingConfiguration.forProfile(profile)
        return preprocess(image, configuration: config)
    }

    /// Preprocess image with custom configuration
    func preprocess(_ image: CGImage,
                   configuration: PreprocessingConfiguration) -> CGImage? {
        var ciImage = CIImage(cgImage: image)

        // 1. Upscaling (if needed)
        if configuration.upscaleFactor > 1.0 {
            ciImage = upscale(ciImage, factor: configuration.upscaleFactor) ?? ciImage
        }

        // 2. Binarization (convert to B&W)
        if configuration.enableBinarization {
            ciImage = binarize(ciImage) ?? ciImage
        }

        // 3. Morphological operations (noise removal)
        if configuration.enableMorphology {
            ciImage = applyMorphology(ciImage) ?? ciImage
        }

        // 4. Sharpening
        if configuration.sharpness > 0 {
            ciImage = sharpen(ciImage, intensity: configuration.sharpness) ?? ciImage
        }

        // 5. Contrast adjustment
        if configuration.contrast != 1.0 {
            ciImage = adjustContrast(ciImage, contrast: configuration.contrast) ?? ciImage
        }

        // 6. Brightness adjustment
        if configuration.brightness != 0.0 {
            ciImage = adjustBrightness(ciImage, brightness: configuration.brightness) ?? ciImage
        }

        // 7. Edge enhancement
        if configuration.edgeIntensity > 0 {
            ciImage = enhanceEdges(ciImage, intensity: configuration.edgeIntensity) ?? ciImage
        }

        // 8. Gamma correction
        if configuration.enableGamma {
            ciImage = adjustGamma(ciImage, gamma: configuration.gammaValue) ?? ciImage
        }

        // Convert back to CGImage
        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }

    /// Preprocess based on text region analysis
    func preprocess(_ image: CGImage,
                   for analysis: TextRegionAnalysis) -> CGImage? {
        let config = selectConfiguration(for: analysis)
        return preprocess(image, configuration: config)
    }

    // MARK: - Configuration Selection

    private func selectConfiguration(for analysis: TextRegionAnalysis) -> PreprocessingConfiguration {
        switch (analysis.sizeClass, analysis.contrast) {

        case (.veryLarge, .high):
            // Very large, high contrast: minimal processing
            return PreprocessingConfiguration.forProfile(.minimal)

        case (.veryLarge, .medium), (.veryLarge, .low):
            // Very large but low contrast: optimize for large numbers
            return PreprocessingConfiguration.forProfile(.largeNumberOptimized)

        case (.large, .high):
            // Large, high contrast: standard processing
            return PreprocessingConfiguration.forProfile(.standard)

        case (.large, .medium), (.large, .low):
            // Large but low contrast: enhanced
            return PreprocessingConfiguration.forProfile(.enhanced)

        case (.medium, _):
            // Medium: aggressive
            return PreprocessingConfiguration.forProfile(.aggressive)

        case (.small, _):
            // Small: very aggressive
            return PreprocessingConfiguration.forProfile(.veryAggressive)
        }
    }

    // MARK: - Individual Preprocessing Operations

    /// Upscale image using Lanczos algorithm
    private func upscale(_ image: CIImage, factor: CGFloat) -> CIImage? {
        let transform = CGAffineTransform(scaleX: factor, y: factor)
        return image.transformed(by: transform)
            .applyingFilter("CILanczosScaleTransform", parameters: [
                kCIInputScaleKey: factor,
                kCIInputAspectRatioKey: 1.0
            ])
    }

    /// Convert to pure black and white (binarization)
    private func binarize(_ image: CIImage) -> CIImage? {
        // Step 1: Convert to grayscale
        guard let grayscaleFilter = CIFilter(name: "CIColorControls") else {
            return nil
        }
        grayscaleFilter.setValue(image, forKey: kCIInputImageKey)
        grayscaleFilter.setValue(0.0, forKey: kCIInputSaturationKey)
        grayscaleFilter.setValue(2.0, forKey: kCIInputContrastKey)

        guard let grayscale = grayscaleFilter.outputImage else {
            return nil
        }

        // Step 2: Threshold to binary
        guard let thresholdFilter = CIFilter(name: "CIColorControls") else {
            return nil
        }
        thresholdFilter.setValue(grayscale, forKey: kCIInputImageKey)
        thresholdFilter.setValue(3.0, forKey: kCIInputContrastKey)
        thresholdFilter.setValue(-0.1, forKey: kCIInputBrightnessKey)

        return thresholdFilter.outputImage
    }

    /// Apply morphological operations to remove noise
    private func applyMorphology(_ image: CIImage) -> CIImage? {
        // Erosion (remove small noise)
        guard let erodeFilter = CIFilter(name: "CIMorphologyMinimum") else {
            return nil
        }
        erodeFilter.setValue(image, forKey: kCIInputImageKey)
        erodeFilter.setValue(2.0, forKey: kCIInputRadiusKey)

        guard let eroded = erodeFilter.outputImage else {
            return nil
        }

        // Dilation (restore character thickness)
        guard let dilateFilter = CIFilter(name: "CIMorphologyMaximum") else {
            return nil
        }
        dilateFilter.setValue(eroded, forKey: kCIInputImageKey)
        dilateFilter.setValue(2.5, forKey: kCIInputRadiusKey)

        return dilateFilter.outputImage
    }

    /// Sharpen image
    private func sharpen(_ image: CIImage, intensity: Float) -> CIImage? {
        guard let filter = CIFilter(name: "CISharpenLuminance") else {
            return nil
        }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(intensity, forKey: kCIInputSharpnessKey)
        return filter.outputImage
    }

    /// Adjust contrast
    private func adjustContrast(_ image: CIImage, contrast: Float) -> CIImage? {
        guard let filter = CIFilter(name: "CIColorControls") else {
            return nil
        }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(contrast, forKey: kCIInputContrastKey)
        return filter.outputImage
    }

    /// Adjust brightness
    private func adjustBrightness(_ image: CIImage, brightness: Float) -> CIImage? {
        guard let filter = CIFilter(name: "CIColorControls") else {
            return nil
        }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(brightness, forKey: kCIInputBrightnessKey)
        return filter.outputImage
    }

    /// Enhance edges
    private func enhanceEdges(_ image: CIImage, intensity: Float) -> CIImage? {
        guard let edgeFilter = CIFilter(name: "CIEdges") else {
            return nil
        }
        edgeFilter.setValue(image, forKey: kCIInputImageKey)
        edgeFilter.setValue(intensity, forKey: kCIInputIntensityKey)

        guard let edges = edgeFilter.outputImage else {
            return nil
        }

        // Blend edges with original
        guard let blendFilter = CIFilter(name: "CIAdditionCompositing") else {
            return nil
        }
        blendFilter.setValue(edges, forKey: kCIInputImageKey)
        blendFilter.setValue(image, forKey: kCIInputBackgroundImageKey)

        return blendFilter.outputImage
    }

    /// Adjust gamma
    private func adjustGamma(_ image: CIImage, gamma: Float) -> CIImage? {
        guard let filter = CIFilter(name: "CIGammaAdjust") else {
            return nil
        }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(gamma, forKey: "inputPower")
        return filter.outputImage
    }

    // MARK: - Batch Processing

    /// Preprocess multiple regions
    func preprocessRegions(_ regions: [(CGImage, TextRegionAnalysis)]) -> [CGImage] {
        return regions.compactMap { image, analysis in
            preprocess(image, for: analysis)
        }
    }

    // MARK: - Quality Metrics

    /// Measure preprocessing quality improvement
    func measureQualityImprovement(original: CGImage,
                                  processed: CGImage) -> Float {
        // Simple metric: compare sharpness
        let originalSharpness = measureSharpness(original)
        let processedSharpness = measureSharpness(processed)

        let improvement = (processedSharpness - originalSharpness) / originalSharpness
        return Float(improvement)
    }

    private func measureSharpness(_ image: CGImage) -> CGFloat {
        let ciImage = CIImage(cgImage: image)

        guard let edgeFilter = CIFilter(name: "CIEdges") else {
            return 0.0
        }
        edgeFilter.setValue(ciImage, forKey: kCIInputImageKey)
        edgeFilter.setValue(1.0, forKey: kCIInputIntensityKey)

        guard let edges = edgeFilter.outputImage,
              let outputImage = ciContext.createCGImage(edges, from: edges.extent) else {
            return 0.0
        }

        // Calculate average edge intensity
        guard let data = outputImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else {
            return 0.0
        }

        let length = CFDataGetLength(data)
        var sum: Int = 0
        for i in 0..<length {
            sum += Int(bytes[i])
        }

        return CGFloat(sum) / CGFloat(length)
    }
}

// MARK: - Preprocessing Pipeline Builder

/// Builds custom preprocessing pipelines
class PreprocessingPipelineBuilder {

    private var operations: [(CIImage) -> CIImage?] = []
    private let ciContext = CIContext()

    // MARK: - Add Operations

    func addUpscaling(factor: CGFloat) -> Self {
        operations.append { image in
            let transform = CGAffineTransform(scaleX: factor, y: factor)
            return image.transformed(by: transform)
                .applyingFilter("CILanczosScaleTransform", parameters: [
                    kCIInputScaleKey: factor,
                    kCIInputAspectRatioKey: 1.0
                ])
        }
        return self
    }

    func addSharpening(intensity: Float) -> Self {
        operations.append { image in
            guard let filter = CIFilter(name: "CISharpenLuminance") else { return nil }
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(intensity, forKey: kCIInputSharpnessKey)
            return filter.outputImage
        }
        return self
    }

    func addContrast(_ contrast: Float) -> Self {
        operations.append { image in
            guard let filter = CIFilter(name: "CIColorControls") else { return nil }
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(contrast, forKey: kCIInputContrastKey)
            return filter.outputImage
        }
        return self
    }

    func addBinarization() -> Self {
        operations.append { image in
            guard let filter = CIFilter(name: "CIColorControls") else { return nil }
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(0.0, forKey: kCIInputSaturationKey)
            filter.setValue(3.0, forKey: kCIInputContrastKey)
            return filter.outputImage
        }
        return self
    }

    func addEdgeEnhancement(intensity: Float) -> Self {
        operations.append { image in
            guard let edgeFilter = CIFilter(name: "CIEdges") else { return nil }
            edgeFilter.setValue(image, forKey: kCIInputImageKey)
            edgeFilter.setValue(intensity, forKey: kCIInputIntensityKey)

            guard let edges = edgeFilter.outputImage,
                  let blendFilter = CIFilter(name: "CIAdditionCompositing") else {
                return nil
            }
            blendFilter.setValue(edges, forKey: kCIInputImageKey)
            blendFilter.setValue(image, forKey: kCIInputBackgroundImageKey)
            return blendFilter.outputImage
        }
        return self
    }

    // MARK: - Build & Execute

    func build() -> (CGImage) -> CGImage? {
        return { [weak self] image in
            guard let self = self else { return nil }

            var ciImage = CIImage(cgImage: image)

            for operation in self.operations {
                guard let processed = operation(ciImage) else {
                    return nil
                }
                ciImage = processed
            }

            return self.ciContext.createCGImage(ciImage, from: ciImage.extent)
        }
    }

    func execute(on image: CGImage) -> CGImage? {
        return build()(image)
    }

    func reset() {
        operations.removeAll()
    }
}

// MARK: - Example Usage

/*
 Example usage:

 let preprocessor = SizeAdaptivePreprocessor()

 // Method 1: Use predefined profile
 let processed = preprocessor.preprocess(image, profile: .largeNumberOptimized)

 // Method 2: Adaptive based on text analysis
 let analyzer = TextRegionAnalyzer()
 if let analysis = try? analyzer.analyze(boundingBox: region, in: image),
    let processed = preprocessor.preprocess(image, for: analysis) {
     // Use processed image for OCR
 }

 // Method 3: Custom pipeline
 let builder = PreprocessingPipelineBuilder()
 let customProcessed = builder
     .addUpscaling(factor: 2.0)
     .addSharpening(intensity: 1.2)
     .addContrast(1.5)
     .addBinarization()
     .execute(on: image)
 */
