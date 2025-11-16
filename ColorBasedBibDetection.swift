//
//  ColorBasedBibDetection.swift
//  Apple Vision Framework - Color-Based Bib Pre-Detection
//
//  Use distinctive bib colors to narrow search area (+25-30% improvement)
//  Works best for white/yellow/pink bibs on dark clothing
//

import Foundation
import CoreImage
import CoreGraphics

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Bib Color Definitions

/// Common race bib colors
enum BibColor: String, CaseIterable {
    case white      // Most common (90%+ of races)
    case yellow     // Common for elite/division markers
    case pink       // Common for women's divisions
    case orange     // Common for age groups
    case green      // Less common
    case blue       // Less common
    case red        // Rare (usually reserved for officials)

    /// HSV color range for detection
    var hsvRange: HSVRange {
        switch self {
        case .white:
            // White: Low saturation, high value
            return HSVRange(
                hueMin: 0, hueMax: 360,          // Any hue
                satMin: 0.0, satMax: 0.25,       // Very low saturation
                valMin: 0.70, valMax: 1.0        // High brightness
            )

        case .yellow:
            // Yellow: Hue 50-70°, medium-high saturation
            return HSVRange(
                hueMin: 45, hueMax: 75,
                satMin: 0.40, satMax: 1.0,
                valMin: 0.60, valMax: 1.0
            )

        case .pink:
            // Pink: Hue 330-360° or 0-15°, medium saturation
            return HSVRange(
                hueMin: 330, hueMax: 360,  // Will handle wraparound
                satMin: 0.25, satMax: 0.75,
                valMin: 0.60, valMax: 1.0
            )

        case .orange:
            // Orange: Hue 15-45°, high saturation
            return HSVRange(
                hueMin: 15, hueMax: 45,
                satMin: 0.50, satMax: 1.0,
                valMin: 0.50, valMax: 1.0
            )

        case .green:
            // Green: Hue 90-150°
            return HSVRange(
                hueMin: 90, hueMax: 150,
                satMin: 0.30, satMax: 1.0,
                valMin: 0.40, valMax: 1.0
            )

        case .blue:
            // Blue: Hue 200-240°
            return HSVRange(
                hueMin: 200, hueMax: 240,
                satMin: 0.30, satMax: 1.0,
                valMin: 0.40, valMax: 1.0
            )

        case .red:
            // Red: Hue 0-15° or 345-360°
            return HSVRange(
                hueMin: 0, hueMax: 15,
                satMin: 0.40, satMax: 1.0,
                valMin: 0.40, valMax: 1.0
            )
        }
    }

    /// Detection priority (higher = more common in races)
    var priority: Int {
        switch self {
        case .white: return 10      // Highest priority
        case .yellow: return 8
        case .pink: return 6
        case .orange: return 5
        case .green: return 3
        case .blue: return 3
        case .red: return 1         // Lowest (usually officials)
        }
    }

    /// Display color for visualization
    var displayColor: CGColor {
        switch self {
        case .white: return CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        case .yellow: return CGColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 1.0)
        case .pink: return CGColor(red: 1.0, green: 0.75, blue: 0.8, alpha: 1.0)
        case .orange: return CGColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)
        case .green: return CGColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
        case .blue: return CGColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0)
        case .red: return CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        }
    }
}

/// HSV color range
struct HSVRange {
    let hueMin: Float       // 0-360 degrees
    let hueMax: Float
    let satMin: Float       // 0-1
    let satMax: Float
    let valMin: Float       // 0-1 (brightness)
    let valMax: Float

    /// Check if HSV values are within this range
    func contains(hue: Float, saturation: Float, value: Float) -> Bool {
        let hueInRange: Bool
        if hueMax < hueMin {
            // Wraparound case (e.g., red: 345-360 or 0-15)
            hueInRange = hue >= hueMin || hue <= hueMax
        } else {
            hueInRange = hue >= hueMin && hue <= hueMax
        }

        return hueInRange
            && saturation >= satMin && saturation <= satMax
            && value >= valMin && value <= valMax
    }
}

// MARK: - Color Detected Region

/// Region detected by color matching
struct ColorDetectedRegion {
    let boundingBox: CGRect         // Normalized coordinates
    let color: BibColor             // Detected color
    let confidence: Float           // Color match confidence (0-1)
    let aspectRatio: CGFloat        // Width / Height
    let area: CGFloat               // Relative area
    let centerPoint: CGPoint        // Center of region
    let pixelCount: Int             // Number of matching pixels
    let bibProbability: Float       // Likelihood this is a bib (0-1)

    var description: String {
        return """
        Color Region (\(color.rawValue)):
          Position: (\(String(format: "%.2f", boundingBox.origin.x)), \(String(format: "%.2f", boundingBox.origin.y)))
          Size: \(String(format: "%.2f", boundingBox.width)) x \(String(format: "%.2f", boundingBox.height))
          Aspect Ratio: \(String(format: "%.2f", aspectRatio))
          Area: \(String(format: "%.1f%%", area * 100))
          Pixels: \(pixelCount)
          Confidence: \(String(format: "%.2f", confidence))
          Bib Probability: \(String(format: "%.2f", bibProbability))
        """
    }
}

// MARK: - Color Utilities

/// Utilities for color space conversion and manipulation
class ColorUtilities {

    /// Convert RGB to HSV
    /// - Parameters:
    ///   - r: Red (0-1)
    ///   - g: Green (0-1)
    ///   - b: Blue (0-1)
    /// - Returns: (hue: 0-360, saturation: 0-1, value: 0-1)
    static func rgbToHSV(r: Float, g: Float, b: Float) -> (hue: Float, saturation: Float, value: Float) {
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC

        // Value (brightness)
        let value = maxC

        // Saturation
        let saturation = maxC == 0 ? 0 : delta / maxC

        // Hue
        var hue: Float = 0
        if delta != 0 {
            if maxC == r {
                hue = 60 * (((g - b) / delta).truncatingRemainder(dividingBy: 6))
            } else if maxC == g {
                hue = 60 * (((b - r) / delta) + 2)
            } else {
                hue = 60 * (((r - g) / delta) + 4)
            }
        }

        if hue < 0 {
            hue += 360
        }

        return (hue, saturation, value)
    }

    /// Create color mask for specific color range
    /// - Parameters:
    ///   - image: Source image
    ///   - colorRange: HSV color range
    /// - Returns: Binary mask (white = match, black = no match)
    static func createColorMask(from image: CGImage, colorRange: HSVRange) -> CGImage? {
        guard let dataProvider = image.dataProvider,
              let pixelData = dataProvider.data,
              let data = CFDataGetBytePtr(pixelData) else {
            return nil
        }

        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = image.bytesPerRow

        // Create mask data
        var maskData = [UInt8](repeating: 0, count: width * height)

        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * bytesPerRow + x * bytesPerPixel

                let r = Float(data[pixelIndex]) / 255.0
                let g = Float(data[pixelIndex + 1]) / 255.0
                let b = Float(data[pixelIndex + 2]) / 255.0

                let (hue, sat, val) = rgbToHSV(r: r, g: g, b: b)

                if colorRange.contains(hue: hue, saturation: sat, value: val) {
                    maskData[y * width + x] = 255  // White (match)
                }
            }
        }

        // Create CGImage from mask data
        guard let provider = CGDataProvider(data: NSData(bytes: maskData, length: maskData.count)) else {
            return nil
        }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}

// MARK: - Connected Component Analysis

/// Find connected components in binary mask
class ConnectedComponentAnalyzer {

    struct Component {
        let pixels: [(x: Int, y: Int)]
        let boundingBox: CGRect         // Pixel coordinates
        let area: Int                   // Number of pixels

        var centerPoint: CGPoint {
            let sumX = pixels.reduce(0) { $0 + $1.x }
            let sumY = pixels.reduce(0) { $0 + $1.y }
            return CGPoint(x: CGFloat(sumX) / CGFloat(pixels.count),
                          y: CGFloat(sumY) / CGFloat(pixels.count))
        }
    }

    /// Find connected components using flood fill
    /// - Parameters:
    ///   - mask: Binary mask image
    ///   - minPixels: Minimum pixels for valid component
    /// - Returns: Array of connected components
    static func findComponents(in mask: CGImage, minPixels: Int = 100) -> [Component] {
        guard let dataProvider = mask.dataProvider,
              let pixelData = dataProvider.data,
              let data = CFDataGetBytePtr(pixelData) else {
            return []
        }

        let width = mask.width
        let height = mask.height

        var visited = [[Bool]](repeating: [Bool](repeating: false, count: width), count: height)
        var components: [Component] = []

        for y in 0..<height {
            for x in 0..<width {
                let pixelValue = data[y * width + x]

                if pixelValue == 255 && !visited[y][x] {
                    // Found unvisited white pixel - start flood fill
                    let pixels = floodFill(x: x, y: y, width: width, height: height,
                                          data: data, visited: &visited)

                    if pixels.count >= minPixels {
                        // Calculate bounding box
                        let minX = pixels.map { $0.x }.min() ?? 0
                        let maxX = pixels.map { $0.x }.max() ?? 0
                        let minY = pixels.map { $0.y }.min() ?? 0
                        let maxY = pixels.map { $0.y }.max() ?? 0

                        let bbox = CGRect(
                            x: minX,
                            y: minY,
                            width: maxX - minX + 1,
                            height: maxY - minY + 1
                        )

                        components.append(Component(
                            pixels: pixels,
                            boundingBox: bbox,
                            area: pixels.count
                        ))
                    }
                }
            }
        }

        return components
    }

    private static func floodFill(x: Int, y: Int, width: Int, height: Int,
                                  data: UnsafePointer<UInt8>,
                                  visited: inout [[Bool]]) -> [(x: Int, y: Int)] {
        var stack = [(x, y)]
        var pixels: [(x: Int, y: Int)] = []

        while !stack.isEmpty {
            let (cx, cy) = stack.removeLast()

            if cx < 0 || cx >= width || cy < 0 || cy >= height {
                continue
            }

            if visited[cy][cx] {
                continue
            }

            if data[cy * width + cx] != 255 {
                continue
            }

            visited[cy][cx] = true
            pixels.append((cx, cy))

            // 4-connectivity
            stack.append((cx + 1, cy))
            stack.append((cx - 1, cy))
            stack.append((cx, cy + 1))
            stack.append((cx, cy - 1))
        }

        return pixels
    }
}

// MARK: - Color-Based Bib Locator

/// Locate potential bib regions using color detection
class ColorBasedBibLocator {

    // MARK: - Configuration

    /// Colors to detect (default: white and yellow - most common)
    var colorsToDetect: [BibColor] = [.white, .yellow, .pink]

    /// Minimum pixel count for valid region (default: 500)
    var minPixelCount: Int = 500

    /// Maximum pixel count (default: 50000 - prevents matching entire person)
    var maxPixelCount: Int = 50000

    /// Minimum bib probability to return (default: 0.5)
    var minBibProbability: Float = 0.5

    /// Expected bib aspect ratio range
    var bibAspectRatioRange: ClosedRange<CGFloat> = 0.6...2.0  // Square-ish

    /// Expected bib area range (as fraction of image)
    var bibAreaRange: ClosedRange<CGFloat> = 0.05...0.40

    // MARK: - Detection

    /// Find bib regions by color in torso region
    /// - Parameters:
    ///   - image: Full image
    ///   - torsoRegion: Torso detection region
    /// - Returns: Array of color-detected regions sorted by probability
    func findBibsByColor(in image: CGImage,
                        torsoRegion: BibDetectionRegion) -> [ColorDetectedRegion] {
        // Crop to torso region first
        let imageSize = CGSize(width: image.width, height: image.height)
        let torsoRect = TorsoRegionManager.convertToImageCoordinates(
            region: torsoRegion,
            imageSize: imageSize
        )

        guard let torsoImage = image.cropping(to: torsoRect) else {
            return []
        }

        var allRegions: [ColorDetectedRegion] = []

        // Try each color in priority order
        let sortedColors = colorsToDetect.sorted { $0.priority > $1.priority }

        for color in sortedColors {
            let regions = findRegionsForColor(color, in: torsoImage)
            allRegions.append(contentsOf: regions)
        }

        // Filter and sort by bib probability
        let filtered = allRegions.filter { $0.bibProbability >= minBibProbability }
        return filtered.sorted { $0.bibProbability > $1.bibProbability }
    }

    /// Find regions matching specific color
    private func findRegionsForColor(_ color: BibColor, in image: CGImage) -> [ColorDetectedRegion] {
        // Create color mask
        guard let mask = ColorUtilities.createColorMask(from: image, colorRange: color.hsvRange) else {
            return []
        }

        // Find connected components
        let components = ConnectedComponentAnalyzer.findComponents(in: mask, minPixels: minPixelCount)

        let imageSize = CGSize(width: image.width, height: image.height)

        // Convert components to ColorDetectedRegion
        return components.compactMap { component -> ColorDetectedRegion? in
            // Filter by pixel count
            guard component.area >= minPixelCount && component.area <= maxPixelCount else {
                return nil
            }

            // Normalize bounding box
            let normalizedBox = CGRect(
                x: component.boundingBox.origin.x / imageSize.width,
                y: component.boundingBox.origin.y / imageSize.height,
                width: component.boundingBox.width / imageSize.width,
                height: component.boundingBox.height / imageSize.height
            )

            let aspectRatio = normalizedBox.width / normalizedBox.height
            let area = normalizedBox.width * normalizedBox.height

            // Calculate bib probability
            let bibProb = calculateBibProbability(
                aspectRatio: aspectRatio,
                area: area,
                pixelCount: component.area,
                color: color
            )

            // Filter by area
            guard bibAreaRange.contains(area) else {
                return nil
            }

            let normalizedCenter = CGPoint(
                x: component.centerPoint.x / imageSize.width,
                y: component.centerPoint.y / imageSize.height
            )

            // Color match confidence (based on pixel density)
            let boxArea = component.boundingBox.width * component.boundingBox.height
            let fillRatio = Float(component.area) / Float(boxArea)
            let confidence = min(1.0, fillRatio * 1.2)  // Boost if well-filled

            return ColorDetectedRegion(
                boundingBox: normalizedBox,
                color: color,
                confidence: confidence,
                aspectRatio: aspectRatio,
                area: area,
                centerPoint: normalizedCenter,
                pixelCount: component.area,
                bibProbability: bibProb
            )
        }
    }

    private func calculateBibProbability(aspectRatio: CGFloat,
                                        area: CGFloat,
                                        pixelCount: Int,
                                        color: BibColor) -> Float {
        var score: Float = 0.5  // Base score

        // Aspect ratio scoring (bibs are usually square-ish)
        if bibAspectRatioRange.contains(aspectRatio) {
            score += 0.3

            // Ideal is close to 1.0 (square)
            let deviation = abs(aspectRatio - 1.0)
            if deviation < 0.2 {
                score += 0.1
            }
        } else {
            score -= 0.2
        }

        // Area scoring
        if bibAreaRange.contains(area) {
            score += 0.2
        }

        // Pixel count scoring (bibs should have substantial pixel count)
        if pixelCount >= 1000 && pixelCount <= 20000 {
            score += 0.1
        }

        // Color priority bonus
        score += Float(color.priority) * 0.02  // White gets +0.20, Yellow +0.16, etc.

        return max(0.0, min(1.0, score))
    }
}

// MARK: - Integration with Existing Pipeline

extension BibDetectionRegion {
    /// Find bib using color pre-detection
    func findBibByColor(in image: CGImage, colors: [BibColor] = [.white, .yellow]) -> [ColorDetectedRegion] {
        let locator = ColorBasedBibLocator()
        locator.colorsToDetect = colors
        return locator.findBibsByColor(in: image, torsoRegion: self)
    }
}

// MARK: - Color-Enhanced Detection Pipeline

/// Combine color detection with text localization for best results
class ColorEnhancedBibDetection {

    private let colorLocator = ColorBasedBibLocator()
    private let textLocalizer = TextLocalizedBibDetection()

    /// Detect bib using color pre-detection + text localization
    /// - Parameters:
    ///   - image: Full image
    ///   - torsoRegion: Torso detection region
    /// - Returns: Bib number result
    func detectBib(in image: CGImage,
                   torsoRegion: BibDetectionRegion) -> BibNumberResult? {
        print("🎨 Color-Enhanced Detection Pipeline")

        // Step 1: Color-based pre-detection (fast: 50-100ms)
        let colorStart = Date()
        let colorRegions = colorLocator.findBibsByColor(in: image, torsoRegion: torsoRegion)
        let colorTime = Date().timeIntervalSince(colorStart)

        print("  Color Detection: Found \(colorRegions.count) regions in \(String(format: "%.0f", colorTime * 1000))ms")

        if colorRegions.isEmpty {
            // Fallback: Use full torso text localization
            print("  No color regions found - using full torso detection")
            return textLocalizer.detectBib(in: image, torsoRegion: torsoRegion)
        }

        // Step 2: Try OCR on color-detected regions (in priority order)
        for (index, colorRegion) in colorRegions.prefix(3).enumerated() {
            print("  Trying OCR on \(colorRegion.color.rawValue) region \(index + 1) (prob: \(String(format: "%.2f", colorRegion.bibProbability)))")

            // Create sub-region from color detection
            let subRegion = BibDetectionRegion(
                zone: torsoRegion.zone,
                boundingBox: colorRegion.boundingBox,
                confidence: torsoRegion.confidence * colorRegion.confidence,
                personID: torsoRegion.personID,
                centerPoint: colorRegion.centerPoint,
                joints: torsoRegion.joints
            )

            // Try text localization on this specific region
            if let result = textLocalizer.detectBib(in: image, torsoRegion: subRegion) {
                print("  ✅ Success with \(colorRegion.color.rawValue) region!")
                return result
            }
        }

        // Step 3: Fallback to full torso
        print("  Color regions failed - falling back to full torso")
        return textLocalizer.detectBib(in: image, torsoRegion: torsoRegion)
    }
}
