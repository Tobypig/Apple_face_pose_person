import Foundation
import CoreImage
import CoreGraphics
import Vision

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Image Difficulty Level

/// Difficulty level classification for race photos
enum ImageDifficultyLevel: String, CaseIterable {
    case light      // Easy: Good lighting, clear subjects, close distance
    case medium     // Moderate: Acceptable quality, some challenges
    case hard       // Difficult: Poor lighting, distant subjects, motion blur, occlusion
    case extreme    // Extreme: Multiple severe challenges
    case auto       // Auto-detect (will be resolved to light/medium/hard/extreme)

    var displayName: String {
        switch self {
        case .light: return "Light (Easy)"
        case .medium: return "Medium (Moderate)"
        case .hard: return "Hard (Difficult)"
        case .extreme: return "Extreme (Very Difficult)"
        case .auto: return "Auto (Detect Automatically)"
        }
    }

    var emoji: String {
        switch self {
        case .light: return "✅"
        case .medium: return "⚠️"
        case .hard: return "🔴"
        case .extreme: return "💀"
        case .auto: return "🤖"
        }
    }
}

// MARK: - Image Quality Metrics

/// Comprehensive image quality metrics
struct ImageQualityMetrics {
    // Resolution & Size
    let resolution: CGSize
    let megapixels: Float
    let aspectRatio: Float

    // Lighting
    let averageBrightness: Float       // 0-1 (0=dark, 1=bright)
    let brightnessVariance: Float      // Higher = more varied lighting
    let hasGoodLighting: Bool          // True if well-lit

    // Contrast & Sharpness
    let contrast: Float                // 0-1 (0=flat, 1=high contrast)
    let sharpness: Float               // 0-1 (0=blurry, 1=sharp)
    let edgeStrength: Float            // 0-1 (0=soft, 1=strong edges)

    // Noise & Quality
    let noiseLevel: Float              // 0-1 (0=clean, 1=noisy)
    let compressionArtifacts: Float    // 0-1 (0=none, 1=heavy)
    let overallQuality: Float          // 0-1 (0=poor, 1=excellent)

    // Subject Detection
    let hasDetectedPeople: Bool
    let largestPersonSize: Float?      // % of image (0-1)
    let numberOfPeople: Int
    let averagePersonConfidence: Float?

    // Scene Complexity
    let sceneComplexity: Float         // 0-1 (0=simple, 1=complex)
    let backgroundClutter: Float       // 0-1 (0=clean, 1=cluttered)
    let colorDiversity: Float          // 0-1 (0=monotone, 1=colorful)

    // Challenging Conditions
    let hasMotionBlur: Bool
    let hasBacklighting: Bool          // Subject darker than background
    let hasOcclusion: Bool             // People partially hidden
    let hasReflections: Bool           // Glare/reflections present

    var description: String {
        return """
        === Image Quality Metrics ===
        Resolution: \(Int(resolution.width))x\(Int(resolution.height)) (\(String(format: "%.1f", megapixels))MP)
        Brightness: \(String(format: "%.2f", averageBrightness)) (\(hasGoodLighting ? "Good" : "Poor"))
        Contrast: \(String(format: "%.2f", contrast))
        Sharpness: \(String(format: "%.2f", sharpness))
        Noise: \(String(format: "%.2f", noiseLevel))
        Overall Quality: \(String(format: "%.2f", overallQuality))
        People Detected: \(numberOfPeople) (\(hasDetectedPeople ? "Yes" : "No"))
        \(largestPersonSize != nil ? "Largest Person: \(String(format: "%.1f%%", largestPersonSize! * 100))" : "")
        Challenges: \(getChallengesList())
        """
    }

    private func getChallengesList() -> String {
        var challenges: [String] = []
        if hasMotionBlur { challenges.append("Motion Blur") }
        if hasBacklighting { challenges.append("Backlighting") }
        if hasOcclusion { challenges.append("Occlusion") }
        if hasReflections { challenges.append("Reflections") }
        if noiseLevel > 0.5 { challenges.append("High Noise") }
        if !hasGoodLighting { challenges.append("Poor Lighting") }
        return challenges.isEmpty ? "None" : challenges.joined(separator: ", ")
    }
}

// MARK: - Image Difficulty Analyzer

/// Analyzes images to determine difficulty level
class ImageDifficultyAnalyzer {

    private let ciContext = CIContext()
    private let personDetector = PersonDetection()

    // MARK: - Configuration Thresholds

    struct Thresholds {
        // Light difficulty thresholds
        var lightMinBrightness: Float = 0.35
        var lightMinContrast: Float = 0.4
        var lightMinSharpness: Float = 0.5
        var lightMaxNoise: Float = 0.3
        var lightMinPersonSize: Float = 0.15    // 15% of image

        // Medium difficulty thresholds
        var mediumMinBrightness: Float = 0.25
        var mediumMinContrast: Float = 0.25
        var mediumMinSharpness: Float = 0.3
        var mediumMaxNoise: Float = 0.5
        var mediumMinPersonSize: Float = 0.08   // 8% of image

        // Hard difficulty thresholds (below these = hard)
        var hardMinBrightness: Float = 0.15
        var hardMinContrast: Float = 0.15
        var hardMinSharpness: Float = 0.2
        var hardMaxNoise: Float = 0.7
        var hardMinPersonSize: Float = 0.03     // 3% of image

        // Challenge count thresholds
        var lightMaxChallenges: Int = 1
        var mediumMaxChallenges: Int = 2
        // Hard: 3+ challenges
    }

    var thresholds = Thresholds()

    // MARK: - Main Analysis

    /// Analyze image and determine difficulty level
    func analyzeDifficulty(_ image: CGImage) -> (level: ImageDifficultyLevel, metrics: ImageQualityMetrics) {
        let metrics = analyzeImageQuality(image)
        let level = determineDifficultyLevel(from: metrics)
        return (level, metrics)
    }

    /// Analyze comprehensive image quality metrics
    func analyzeImageQuality(_ image: CGImage) -> ImageQualityMetrics {
        let ciImage = CIImage(cgImage: image)

        // Resolution
        let resolution = CGSize(width: image.width, height: image.height)
        let megapixels = Float(image.width * image.height) / 1_000_000.0
        let aspectRatio = Float(image.width) / Float(image.height)

        // Lighting analysis
        let (brightness, brightnessVariance) = analyzeBrightness(ciImage)
        let hasGoodLighting = brightness >= 0.3 && brightness <= 0.85 && brightnessVariance < 0.4

        // Contrast & Sharpness
        let contrast = analyzeContrast(ciImage)
        let sharpness = analyzeSharpness(ciImage)
        let edgeStrength = analyzeEdgeStrength(ciImage)

        // Noise & Quality
        let noiseLevel = analyzeNoise(ciImage)
        let compressionArtifacts = analyzeCompressionArtifacts(ciImage)
        let overallQuality = calculateOverallQuality(
            brightness: brightness,
            contrast: contrast,
            sharpness: sharpness,
            noise: noiseLevel
        )

        // Person detection
        let (hasDetectedPeople, largestPersonSize, numberOfPeople, avgConfidence) = analyzePersonDetection(image)

        // Scene complexity
        let sceneComplexity = analyzeSceneComplexity(ciImage)
        let backgroundClutter = analyzeBackgroundClutter(ciImage)
        let colorDiversity = analyzeColorDiversity(ciImage)

        // Challenging conditions
        let hasMotionBlur = sharpness < 0.3 && edgeStrength < 0.3
        let hasBacklighting = detectBacklighting(ciImage, brightness: brightness, variance: brightnessVariance)
        let hasOcclusion = detectOcclusion(numberOfPeople: numberOfPeople, largestSize: largestPersonSize)
        let hasReflections = detectReflections(ciImage)

        return ImageQualityMetrics(
            resolution: resolution,
            megapixels: megapixels,
            aspectRatio: aspectRatio,
            averageBrightness: brightness,
            brightnessVariance: brightnessVariance,
            hasGoodLighting: hasGoodLighting,
            contrast: contrast,
            sharpness: sharpness,
            edgeStrength: edgeStrength,
            noiseLevel: noiseLevel,
            compressionArtifacts: compressionArtifacts,
            overallQuality: overallQuality,
            hasDetectedPeople: hasDetectedPeople,
            largestPersonSize: largestPersonSize,
            numberOfPeople: numberOfPeople,
            averagePersonConfidence: avgConfidence,
            sceneComplexity: sceneComplexity,
            backgroundClutter: backgroundClutter,
            colorDiversity: colorDiversity,
            hasMotionBlur: hasMotionBlur,
            hasBacklighting: hasBacklighting,
            hasOcclusion: hasOcclusion,
            hasReflections: hasReflections
        )
    }

    // MARK: - Difficulty Level Determination

    private func determineDifficultyLevel(from metrics: ImageQualityMetrics) -> ImageDifficultyLevel {
        // Count challenges
        var challengeCount = 0
        var challengeScores: [String: Float] = [:]

        // Lighting challenges
        if !metrics.hasGoodLighting {
            challengeCount += 1
            challengeScores["lighting"] = 1.0 - abs(metrics.averageBrightness - 0.5) * 2
        }

        // Contrast challenges
        if metrics.contrast < thresholds.mediumMinContrast {
            challengeCount += 1
            challengeScores["contrast"] = metrics.contrast
        }

        // Sharpness challenges
        if metrics.sharpness < thresholds.mediumMinSharpness {
            challengeCount += 1
            challengeScores["sharpness"] = metrics.sharpness
        }

        // Noise challenges
        if metrics.noiseLevel > thresholds.mediumMaxNoise {
            challengeCount += 1
            challengeScores["noise"] = metrics.noiseLevel
        }

        // Size challenges
        if let personSize = metrics.largestPersonSize, personSize < thresholds.mediumMinPersonSize {
            challengeCount += 1
            challengeScores["size"] = personSize
        } else if !metrics.hasDetectedPeople {
            challengeCount += 2  // No people is a major challenge
            challengeScores["detection"] = 0.0
        }

        // Condition challenges
        if metrics.hasMotionBlur { challengeCount += 1; challengeScores["blur"] = 1.0 }
        if metrics.hasBacklighting { challengeCount += 1; challengeScores["backlighting"] = 1.0 }
        if metrics.hasOcclusion { challengeCount += 1; challengeScores["occlusion"] = 1.0 }
        if metrics.hasReflections { challengeCount += 1; challengeScores["reflections"] = 1.0 }

        // Calculate severity score (0-1, higher = more difficult)
        let severityScore = Float(challengeCount) / 10.0 + (1.0 - metrics.overallQuality) * 0.5

        // Determine level
        if challengeCount <= thresholds.lightMaxChallenges && metrics.overallQuality >= 0.7 {
            return .light
        } else if challengeCount <= thresholds.mediumMaxChallenges && metrics.overallQuality >= 0.4 {
            return .medium
        } else if severityScore >= 0.8 || challengeCount >= 5 {
            return .extreme
        } else {
            return .hard
        }
    }

    // MARK: - Individual Metric Analyzers

    private func analyzeBrightness(_ image: CIImage) -> (average: Float, variance: Float) {
        guard let avgFilter = CIFilter(name: "CIAreaAverage") else {
            return (0.5, 0.0)
        }

        avgFilter.setValue(image, forKey: kCIInputImageKey)
        avgFilter.setValue(CIVector(cgRect: image.extent), forKey: kCIInputExtentKey)

        guard let output = avgFilter.outputImage,
              let bitmap = ciContext.createCGImage(output, from: output.extent),
              let data = bitmap.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else {
            return (0.5, 0.0)
        }

        // Average brightness
        let avg = (Float(bytes[0]) + Float(bytes[1]) + Float(bytes[2])) / (3.0 * 255.0)

        // Variance (simplified - use histogram for accuracy)
        let variance: Float = 0.2 // Placeholder

        return (avg, variance)
    }

    private func analyzeContrast(_ image: CIImage) -> Float {
        // Use histogram-based contrast measurement
        guard let histogramFilter = CIFilter(name: "CIAreaHistogram") else {
            return 0.5
        }

        histogramFilter.setValue(image, forKey: kCIInputImageKey)
        histogramFilter.setValue(256, forKey: "inputCount")
        histogramFilter.setValue(CIVector(cgRect: image.extent), forKey: "inputExtent")

        // Simplified: return mid-range value
        return 0.5
    }

    private func analyzeSharpness(_ image: CIImage) -> Float {
        // Edge-based sharpness measurement
        guard let edgeFilter = CIFilter(name: "CIEdges") else {
            return 0.5
        }

        edgeFilter.setValue(image, forKey: kCIInputImageKey)
        edgeFilter.setValue(1.0, forKey: kCIInputIntensityKey)

        guard let edges = edgeFilter.outputImage,
              let avgFilter = CIFilter(name: "CIAreaAverage") else {
            return 0.5
        }

        avgFilter.setValue(edges, forKey: kCIInputImageKey)
        avgFilter.setValue(CIVector(cgRect: edges.extent), forKey: kCIInputExtentKey)

        guard let output = avgFilter.outputImage,
              let bitmap = ciContext.createCGImage(output, from: output.extent),
              let data = bitmap.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else {
            return 0.5
        }

        let sharpness = Float(bytes[0]) / 255.0
        return min(sharpness * 2.0, 1.0)  // Normalize
    }

    private func analyzeEdgeStrength(_ image: CIImage) -> Float {
        // Similar to sharpness but focuses on edge strength
        return analyzeSharpness(image) * 0.9  // Simplified
    }

    private func analyzeNoise(_ image: CIImage) -> Float {
        // Noise estimation using local variance
        // Simplified implementation
        return 0.2  // Placeholder
    }

    private func analyzeCompressionArtifacts(_ image: CIImage) -> Float {
        // Detect JPEG compression artifacts
        // Simplified implementation
        return 0.1  // Placeholder
    }

    private func calculateOverallQuality(brightness: Float, contrast: Float, sharpness: Float, noise: Float) -> Float {
        // Weighted quality score
        let brightnessScore = 1.0 - abs(brightness - 0.5) * 2  // Penalize too dark or too bright
        let contrastScore = contrast
        let sharpnessScore = sharpness
        let noiseScore = 1.0 - noise

        return (brightnessScore * 0.25 + contrastScore * 0.25 + sharpnessScore * 0.3 + noiseScore * 0.2)
    }

    private func analyzePersonDetection(_ image: CGImage) -> (hasDetected: Bool, largestSize: Float?, count: Int, avgConfidence: Float?) {
        guard let people = personDetector.detectPeople(in: image), !people.isEmpty else {
            return (false, nil, 0, nil)
        }

        let imageArea = Float(image.width * image.height)
        let largestPerson = people.max { a, b in
            (a.boundingBox.width * a.boundingBox.height) < (b.boundingBox.width * b.boundingBox.height)
        }

        let largestSize = largestPerson.map { person in
            let area = Float(person.boundingBox.width * person.boundingBox.height)
            return area / imageArea
        }

        let avgConfidence = people.map { $0.confidence }.reduce(0, +) / Float(people.count)

        return (true, largestSize, people.count, avgConfidence)
    }

    private func analyzeSceneComplexity(_ image: CIImage) -> Float {
        // Based on color diversity and edge count
        return 0.5  // Placeholder
    }

    private func analyzeBackgroundClutter(_ image: CIImage) -> Float {
        // Edge density outside person regions
        return 0.3  // Placeholder
    }

    private func analyzeColorDiversity(_ image: CIImage) -> Float {
        // Color histogram variance
        return 0.4  // Placeholder
    }

    private func detectBacklighting(_ image: CIImage, brightness: Float, variance: Float) -> Bool {
        // High variance with low average suggests backlighting
        return brightness < 0.3 && variance > 0.4
    }

    private func detectOcclusion(numberOfPeople: Int, largestSize: Float?) -> Bool {
        // Small person size or multiple people suggests possible occlusion
        if let size = largestSize, size < 0.4 && numberOfPeople > 1 {
            return true
        }
        return false
    }

    private func detectReflections(_ image: CIImage) -> Bool {
        // Detect very bright spots (highlights filter)
        // Simplified implementation
        return false  // Placeholder
    }

    // MARK: - Batch Analysis

    func analyzeBatch(_ images: [CGImage]) -> [(ImageDifficultyLevel, ImageQualityMetrics)] {
        return images.map { analyzeDifficulty($0) }
    }

    func printDetailedAnalysis(_ image: CGImage) {
        let (level, metrics) = analyzeDifficulty(image)

        print("\n╔════════════════════════════════════════════════════════════╗")
        print("║   IMAGE DIFFICULTY ANALYSIS                                ║")
        print("╚════════════════════════════════════════════════════════════╝\n")

        print("Difficulty Level: \(level.emoji) \(level.displayName)\n")
        print(metrics.description)
        print("")
    }
}

// MARK: - Example Usage

/*
 Example usage:

 let analyzer = ImageDifficultyAnalyzer()

 // Analyze single image
 let (level, metrics) = analyzer.analyzeDifficulty(image)
 print("Difficulty: \(level.displayName)")
 print("Overall Quality: \(metrics.overallQuality)")

 // Detailed analysis
 analyzer.printDetailedAnalysis(image)

 // Batch analysis
 let results = analyzer.analyzeBatch(images)
 for (level, metrics) in results {
     print("\(level.displayName): Quality \(metrics.overallQuality)")
 }

 // Use with feedback loop
 let (level, _) = analyzer.analyzeDifficulty(image)
 switch level {
 case .light:
     // Use minimal rescue strategies
     pipeline.config.rescueStrategies = [.extremeContrast]
 case .medium:
     // Use moderate rescue strategies
     pipeline.config.rescueStrategies = [.extremeContrast, .adaptiveThreshold]
 case .hard, .extreme:
     // Use all rescue strategies
     pipeline.config.rescueStrategies = RescueEnhancementStrategy.allCases
 case .auto:
     // Will be resolved automatically
     break
 }
 */
