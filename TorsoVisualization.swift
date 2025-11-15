//
//  TorsoVisualization.swift
//  Apple Vision Framework - Torso Region Visualization
//
//  Utilities for visualizing torso regions and bib detection zones
//

import CoreGraphics
import CoreImage
import Foundation

#if os(macOS)
import AppKit
typealias PlatformColor = NSColor
#else
import UIKit
typealias PlatformColor = UIColor
#endif

// MARK: - Visualization Manager

class TorsoVisualizationManager {

    // MARK: - Configuration

    var drawBoundingBoxes: Bool = true
    var drawJointPoints: Bool = true
    var drawLabels: Bool = true
    var drawZonePercentages: Bool = true
    var lineWidth: CGFloat = 3.0
    var jointRadius: CGFloat = 6.0
    var fontSize: CGFloat = 16.0

    // MARK: - Visualization Methods

    /// Draw torso regions on an image
    /// - Parameters:
    ///   - image: Source image
    ///   - regions: Bib detection regions to visualize
    /// - Returns: Image with overlaid visualization
    func drawTorsoRegions(on image: CGImage, regions: [BibDetectionRegion]) -> CGImage? {
        let imageSize = CGSize(width: image.width, height: image.height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        // Draw original image
        context.draw(image, in: CGRect(origin: .zero, size: imageSize))

        // Draw each region
        for region in regions {
            drawRegion(region, in: context, imageSize: imageSize)
        }

        return context.makeImage()
    }

    /// Draw a single bib detection region
    private func drawRegion(_ region: BibDetectionRegion, in context: CGContext, imageSize: CGSize) {
        let bbox = TorsoRegionManager.convertToImageCoordinates(region: region, imageSize: imageSize)

        // Draw bounding box
        if drawBoundingBoxes {
            context.setStrokeColor(TorsoRegionManager.colorForZone(region.zone))
            context.setLineWidth(lineWidth)
            context.stroke(bbox)
        }

        // Draw center point
        if drawJointPoints {
            let centerX = region.centerPoint.x * imageSize.width
            let centerY = (1 - region.centerPoint.y) * imageSize.height

            context.setFillColor(CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.8))
            context.fillEllipse(in: CGRect(
                x: centerX - jointRadius,
                y: centerY - jointRadius,
                width: jointRadius * 2,
                height: jointRadius * 2
            ))
        }

        // Draw label
        if drawLabels {
            drawLabel(for: region, bbox: bbox, in: context)
        }

        // Draw zone percentages
        if drawZonePercentages {
            drawPercentageGuide(for: region, bbox: bbox, in: context, imageSize: imageSize)
        }
    }

    /// Draw label for region
    private func drawLabel(for region: BibDetectionRegion, bbox: CGRect, in context: CGContext) {
        let label = TorsoRegionManager.labelForZone(region.zone)
        let confidenceText = String(format: "%.2f", region.confidence)
        let text = "\(label) (\(confidenceText))"

        // Position above bounding box
        let textX = bbox.origin.x
        let textY = bbox.origin.y - 25

        #if os(macOS)
        // macOS text drawing
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: NSColor.white,
            .strokeColor: NSColor.black,
            .strokeWidth: -3.0
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        attributedString.draw(at: CGPoint(x: textX, y: textY))
        #else
        // iOS text drawing
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: UIColor.white,
            .strokeColor: UIColor.black,
            .strokeWidth: -3.0
        ]
        text.draw(at: CGPoint(x: textX, y: textY), withAttributes: attributes)
        #endif
    }

    /// Draw percentage guide lines
    private func drawPercentageGuide(for region: BibDetectionRegion, bbox: CGRect, in context: CGContext, imageSize: CGSize) {
        guard let joints = extractJointPositions(from: region.joints, imageSize: imageSize) else {
            return
        }

        // Draw shoulder line (100%)
        if let leftShoulder = joints.leftShoulder, let rightShoulder = joints.rightShoulder {
            drawPercentageLine(
                from: leftShoulder,
                to: rightShoulder,
                label: "100% (Shoulders)",
                in: context
            )
        }

        // Draw hip line (0%)
        if let leftHip = joints.leftHip, let rightHip = joints.rightHip {
            drawPercentageLine(
                from: leftHip,
                to: rightHip,
                label: "0% (Hips)",
                in: context
            )
        }
    }

    /// Draw a percentage guide line
    private func drawPercentageLine(from start: CGPoint, to end: CGPoint, label: String, in context: CGContext) {
        // Draw dashed line
        context.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.7))
        context.setLineWidth(1.5)
        context.setLineDash(phase: 0, lengths: [5, 5])

        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()

        // Reset line dash
        context.setLineDash(phase: 0, lengths: [])
    }

    /// Extract joint positions in image coordinates
    private func extractJointPositions(from joints: TorsoJoints, imageSize: CGSize) -> (
        leftShoulder: CGPoint?,
        rightShoulder: CGPoint?,
        leftHip: CGPoint?,
        rightHip: CGPoint?
    )? {
        func convert(_ joint: JointPoint?) -> CGPoint? {
            guard let joint = joint else { return nil }
            return CGPoint(
                x: joint.position.x * imageSize.width,
                y: (1 - joint.position.y) * imageSize.height
            )
        }

        return (
            leftShoulder: convert(joints.leftShoulder),
            rightShoulder: convert(joints.rightShoulder),
            leftHip: convert(joints.leftHip),
            rightHip: convert(joints.rightHip)
        )
    }

    // MARK: - Diagnostic Visualization

    /// Create diagnostic image showing all possible bib zones
    /// - Parameters:
    ///   - image: Source image
    ///   - pose: Pose estimation result
    /// - Returns: Image with all zones visualized
    func drawAllZones(on image: CGImage, pose: PoseEstimationResult) -> CGImage? {
        let torsoManager = TorsoRegionManager()

        // Extract all possible zones
        let allZones: [TorsoZone] = [.upperChest, .midTorso, .lowerTorso, .fullTorso]
        let regions = torsoManager.extractTorsoRegions(from: [pose], zones: allZones)

        return drawTorsoRegions(on: image, regions: regions)
    }

    /// Create side-by-side comparison of all zones
    /// - Parameters:
    ///   - image: Source image
    ///   - pose: Pose estimation result
    /// - Returns: Array of images, one per zone
    func createZoneComparison(image: CGImage, pose: PoseEstimationResult) -> [CGImage] {
        let torsoManager = TorsoRegionManager()
        var images: [CGImage] = []

        let zones: [TorsoZone] = [.upperChest, .midTorso, .lowerTorso]

        for zone in zones {
            let regions = torsoManager.extractTorsoRegions(from: [pose], zones: [zone])
            if let visualized = drawTorsoRegions(on: image, regions: regions) {
                images.append(visualized)
            }
        }

        return images
    }

    // MARK: - Annotated Output

    /// Create annotated image with bib numbers overlaid
    /// - Parameters:
    ///   - image: Source image
    ///   - bibResults: Detected bib numbers
    /// - Returns: Image with bib numbers annotated
    func annotateBibNumbers(on image: CGImage, bibResults: [BibNumberResult]) -> CGImage? {
        let imageSize = CGSize(width: image.width, height: image.height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        // Draw original image
        context.draw(image, in: CGRect(origin: .zero, size: imageSize))

        // Draw each bib result
        for result in bibResults {
            let bbox = TorsoRegionManager.convertToImageCoordinates(region: result.region, imageSize: imageSize)

            // Draw bounding box in green (detected!)
            context.setStrokeColor(CGColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0))
            context.setLineWidth(4.0)
            context.stroke(bbox)

            // Draw bib number
            let bibText = "BIB #\(result.number)"
            let textX = bbox.origin.x
            let textY = bbox.origin.y - 30

            #if os(macOS)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 20, weight: .bold),
                .foregroundColor: NSColor.green,
                .strokeColor: NSColor.black,
                .strokeWidth: -4.0
            ]
            let attributedString = NSAttributedString(string: bibText, attributes: attributes)
            attributedString.draw(at: CGPoint(x: textX, y: textY))
            #else
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .bold),
                .foregroundColor: UIColor.green,
                .strokeColor: UIColor.black,
                .strokeWidth: -4.0
            ]
            bibText.draw(at: CGPoint(x: textX, y: textY), withAttributes: attributes)
            #endif
        }

        return context.makeImage()
    }
}

// MARK: - ASCII Art Visualization (for console debugging)

class TorsoASCIIVisualizer {

    /// Print ASCII visualization of torso regions
    /// - Parameter region: Bib detection region
    static func printRegion(_ region: BibDetectionRegion) {
        print("┌─────────────────────────────────────┐")
        print("│  Torso Region: \(region.zone.rawValue.padding(toLength: 18, withPad: " ", startingAt: 0))│")
        print("├─────────────────────────────────────┤")
        print("│  Person ID: \(String(region.personID).padding(toLength: 23, withPad: " ", startingAt: 0))│")
        print("│  Confidence: \(String(format: "%.2f", region.confidence).padding(toLength: 22, withPad: " ", startingAt: 0))│")
        print("│  Center: (\(String(format: "%.3f", region.centerPoint.x)), \(String(format: "%.3f", region.centerPoint.y)))       │")
        print("├─────────────────────────────────────┤")
        print("│  Bounding Box (normalized):         │")
        print("│    X: \(String(format: "%.3f", region.boundingBox.origin.x).padding(toLength: 27, withPad: " ", startingAt: 0))│")
        print("│    Y: \(String(format: "%.3f", region.boundingBox.origin.y).padding(toLength: 27, withPad: " ", startingAt: 0))│")
        print("│    Width: \(String(format: "%.3f", region.boundingBox.width).padding(toLength: 23, withPad: " ", startingAt: 0))│")
        print("│    Height: \(String(format: "%.3f", region.boundingBox.height).padding(toLength: 22, withPad: " ", startingAt: 0))│")
        print("└─────────────────────────────────────┘")
    }

    /// Print visual torso map
    static func printTorsoMap() {
        print("""

        TORSO REGION MAP (Side View)
        ════════════════════════════

        ┌─────────────────────────┐
        │                         │ ← 100% Shoulders
        │    UPPER CHEST          │
        │    [Primary Bib]        │   80%
        │    Zone 1               │
        │    • Marathon           │   60%
        │    • Road Race          │
        ├─────────────────────────┤
        │    MID TORSO            │
        │    [Alternative]        │   40%
        │    Zone 2               │
        │    • Triathlon          │
        ├─────────────────────────┤   20%
        │    LOWER TORSO          │
        │    [Lower Placement]    │
        │    Zone 3               │
        │    • Belt/Waist         │
        └─────────────────────────┘ ← 0% Hips

        Key Joints:
        • Shoulders (left_shoulder, right_shoulder)
        • Hips (left_hip, right_hip)
        • Neck (upper boundary)
        • Root (pelvis center)

        Recommended Search Order:
        1. Upper Chest (60-80%)  ← MOST COMMON
        2. Mid Torso (40-60%)
        3. Lower Torso (20-40%)

        """)
    }
}
