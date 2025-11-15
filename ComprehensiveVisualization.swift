//
//  ComprehensiveVisualization.swift
//  Apple Vision Framework - Complete Visualization System
//
//  Draws person bounding boxes, pose skeletons, torso regions, and readable text
//

import CoreGraphics
import CoreImage
import Foundation

#if os(macOS)
import AppKit
typealias PlatformColor = NSColor
typealias PlatformFont = NSFont
#else
import UIKit
typealias PlatformColor = UIColor
typealias PlatformFont = UIFont
#endif

// MARK: - Visualization Configuration

struct VisualizationStyle {
    // Person bounding box
    var personBoxColor: CGColor = CGColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 0.8)
    var personBoxLineWidth: CGFloat = 3.0
    var showPersonLabels: Bool = true

    // Pose skeleton
    var jointColor: CGColor = CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
    var jointRadius: CGFloat = 8.0
    var boneColor: CGColor = CGColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 0.9)
    var boneLineWidth: CGFloat = 4.0
    var showJointLabels: Bool = false

    // Torso regions
    var torsoBoxColor: CGColor = CGColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.6)
    var torsoBoxLineWidth: CGFloat = 2.0
    var showTorsoLabels: Bool = true

    // Text rendering
    var textColor: PlatformColor = .white
    var textBackgroundColor: CGColor = CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.7)
    var textOutlineColor: CGColor = CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
    var textOutlineWidth: CGFloat = 3.0
    var fontSize: CGFloat = 16.0
    var fontWeight: PlatformFont.Weight = .bold

    // General
    var drawFilledBackground: Bool = true
    var backgroundPadding: CGFloat = 4.0
}

// MARK: - Comprehensive Visualization Manager

class ComprehensiveVisualizationManager {

    // MARK: - Properties

    var style = VisualizationStyle()

    // MARK: - Complete Visualization

    /// Draw complete visualization with all elements
    /// - Parameters:
    ///   - image: Source image
    ///   - people: Person detection results
    ///   - poses: Pose estimation results
    ///   - torsoRegions: Torso region detection results
    ///   - bibResults: Optional bib number results
    /// - Returns: Annotated image
    func drawCompleteVisualization(
        on image: CGImage,
        people: [PersonDetectionResult],
        poses: [PoseEstimationResult],
        torsoRegions: [BibDetectionRegion],
        bibResults: [BibNumberResult]? = nil
    ) -> CGImage? {

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

        // Layer 1: Person bounding boxes (background)
        for person in people {
            drawPersonBoundingBox(person, in: context, imageSize: imageSize)
        }

        // Layer 2: Torso regions
        for region in torsoRegions {
            drawTorsoRegion(region, in: context, imageSize: imageSize)
        }

        // Layer 3: Pose skeletons
        for pose in poses {
            drawPoseSkeleton(pose, in: context, imageSize: imageSize)
        }

        // Layer 4: Bib number results (if available)
        if let bibs = bibResults {
            for bib in bibs {
                drawBibNumber(bib, in: context, imageSize: imageSize)
            }
        }

        return context.makeImage()
    }

    // MARK: - Person Bounding Box

    /// Draw person bounding box with label
    func drawPersonBoundingBox(
        _ person: PersonDetectionResult,
        in context: CGContext,
        imageSize: CGSize
    ) {
        let bbox = PersonDetectionManager.convertToImageCoordinates(
            boundingBox: person.boundingBox,
            imageSize: imageSize
        )

        // Draw bounding box
        context.setStrokeColor(style.personBoxColor)
        context.setLineWidth(style.personBoxLineWidth)
        context.stroke(bbox)

        // Draw label if enabled
        if style.showPersonLabels {
            let label = "Person \(person.personID)"
            let sublabel = String(format: "%.2f", person.confidence)

            drawReadableText(
                label,
                sublabel: sublabel,
                at: CGPoint(x: bbox.origin.x, y: bbox.origin.y - 10),
                in: context,
                color: .green
            )
        }
    }

    // MARK: - Pose Skeleton

    /// Draw complete pose skeleton with joints and bones
    func drawPoseSkeleton(
        _ pose: PoseEstimationResult,
        in context: CGContext,
        imageSize: CGSize
    ) {
        // Convert joints to image coordinates
        var imageJoints: [String: CGPoint] = [:]
        for (name, joint) in pose.joints {
            let imagePoint = PoseEstimationManager.convertToImageCoordinates(
                point: joint.position,
                imageSize: imageSize
            )
            imageJoints[name] = imagePoint
        }

        // Draw bones (connections)
        let connections = PoseEstimationManager.getSkeletonConnections()
        context.setStrokeColor(style.boneColor)
        context.setLineWidth(style.boneLineWidth)
        context.setLineCap(.round)

        for (joint1Name, joint2Name) in connections {
            guard let point1 = imageJoints[joint1Name],
                  let point2 = imageJoints[joint2Name] else {
                continue
            }

            context.move(to: point1)
            context.addLine(to: point2)
            context.strokePath()
        }

        // Draw joints (on top of bones)
        context.setFillColor(style.jointColor)
        for (name, point) in imageJoints {
            let jointRect = CGRect(
                x: point.x - style.jointRadius,
                y: point.y - style.jointRadius,
                width: style.jointRadius * 2,
                height: style.jointRadius * 2
            )
            context.fillEllipse(in: jointRect)

            // Draw joint labels if enabled
            if style.showJointLabels {
                drawReadableText(
                    name,
                    sublabel: nil,
                    at: CGPoint(x: point.x + style.jointRadius + 5, y: point.y),
                    in: context,
                    color: .red,
                    fontSize: 12.0
                )
            }
        }
    }

    // MARK: - Torso Region

    /// Draw torso region with zone label
    func drawTorsoRegion(
        _ region: BibDetectionRegion,
        in context: CGContext,
        imageSize: CGSize
    ) {
        let bbox = TorsoRegionManager.convertToImageCoordinates(
            region: region,
            imageSize: imageSize
        )

        // Draw bounding box
        context.setStrokeColor(style.torsoBoxColor)
        context.setLineWidth(style.torsoBoxLineWidth)
        context.setLineDash(phase: 0, lengths: [5, 5]) // Dashed line
        context.stroke(bbox)
        context.setLineDash(phase: 0, lengths: []) // Reset

        // Draw center point
        let centerX = region.centerPoint.x * imageSize.width
        let centerY = (1 - region.centerPoint.y) * imageSize.height

        context.setFillColor(CGColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.8))
        context.fillEllipse(in: CGRect(
            x: centerX - 6,
            y: centerY - 6,
            width: 12,
            height: 12
        ))

        // Draw label if enabled
        if style.showTorsoLabels {
            let label = TorsoRegionManager.labelForZone(region.zone)
            let sublabel = String(format: "%.2f", region.confidence)

            drawReadableText(
                label,
                sublabel: sublabel,
                at: CGPoint(x: bbox.origin.x, y: bbox.origin.y - 10),
                in: context,
                color: .orange
            )
        }
    }

    // MARK: - Bib Number

    /// Draw bib number result with highlighting
    func drawBibNumber(
        _ bib: BibNumberResult,
        in context: CGContext,
        imageSize: CGSize
    ) {
        let bbox = TorsoRegionManager.convertToImageCoordinates(
            region: bib.region,
            imageSize: imageSize
        )

        // Draw highlighted bounding box
        context.setStrokeColor(CGColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0))
        context.setLineWidth(5.0)
        context.stroke(bbox)

        // Draw bib number label
        let label = "BIB #\(bib.number)"
        let sublabel = String(format: "%.2f", bib.confidence)

        drawReadableText(
            label,
            sublabel: sublabel,
            at: CGPoint(x: bbox.origin.x, y: bbox.origin.y - 40),
            in: context,
            color: .green,
            fontSize: 20.0
        )
    }

    // MARK: - Readable Text Rendering

    /// Draw text with background and outline for maximum readability
    func drawReadableText(
        _ text: String,
        sublabel: String?,
        at position: CGPoint,
        in context: CGContext,
        color: PlatformColor,
        fontSize: CGFloat? = nil
    ) {
        let actualFontSize = fontSize ?? style.fontSize

        #if os(macOS)
        let font = NSFont.systemFont(ofSize: actualFontSize, weight: style.fontWeight)

        // Main text attributes with outline
        let mainAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .strokeColor: PlatformColor(cgColor: style.textOutlineColor) ?? .black,
            .strokeWidth: -style.textOutlineWidth
        ]

        let attributedText = NSAttributedString(string: text, attributes: mainAttributes)
        let textSize = attributedText.size()

        // Calculate background rect
        var backgroundRect = CGRect(
            x: position.x - style.backgroundPadding,
            y: position.y - style.backgroundPadding,
            width: textSize.width + style.backgroundPadding * 2,
            height: textSize.height + style.backgroundPadding * 2
        )

        // Adjust for sublabel if present
        if let sublabelText = sublabel {
            let sublabelAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: actualFontSize - 4, weight: .regular),
                .foregroundColor: color,
                .strokeColor: PlatformColor(cgColor: style.textOutlineColor) ?? .black,
                .strokeWidth: -style.textOutlineWidth
            ]
            let sublabelAttributed = NSAttributedString(string: sublabelText, attributes: sublabelAttributes)
            let sublabelSize = sublabelAttributed.size()

            backgroundRect.size.height += sublabelSize.height + 2
            backgroundRect.size.width = max(backgroundRect.size.width, sublabelSize.width + style.backgroundPadding * 2)
        }

        // Draw background
        if style.drawFilledBackground {
            context.setFillColor(style.textBackgroundColor)
            context.fill(backgroundRect)
        }

        // Draw main text
        attributedText.draw(at: position)

        // Draw sublabel if present
        if let sublabelText = sublabel {
            let sublabelAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: actualFontSize - 4, weight: .regular),
                .foregroundColor: color,
                .strokeColor: PlatformColor(cgColor: style.textOutlineColor) ?? .black,
                .strokeWidth: -style.textOutlineWidth
            ]
            let sublabelAttributed = NSAttributedString(string: sublabelText, attributes: sublabelAttributes)
            let sublabelPosition = CGPoint(x: position.x, y: position.y + textSize.height + 2)
            sublabelAttributed.draw(at: sublabelPosition)
        }

        #else
        // iOS implementation
        let font = UIFont.systemFont(ofSize: actualFontSize, weight: style.fontWeight)

        let mainAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .strokeColor: PlatformColor(cgColor: style.textOutlineColor) ?? .black,
            .strokeWidth: -style.textOutlineWidth
        ]

        let attributedText = NSAttributedString(string: text, attributes: mainAttributes)
        let textSize = attributedText.size()

        var backgroundRect = CGRect(
            x: position.x - style.backgroundPadding,
            y: position.y - style.backgroundPadding,
            width: textSize.width + style.backgroundPadding * 2,
            height: textSize.height + style.backgroundPadding * 2
        )

        if let sublabelText = sublabel {
            let sublabelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: actualFontSize - 4, weight: .regular),
                .foregroundColor: color,
                .strokeColor: PlatformColor(cgColor: style.textOutlineColor) ?? .black,
                .strokeWidth: -style.textOutlineWidth
            ]
            let sublabelAttributed = NSAttributedString(string: sublabelText, attributes: sublabelAttributes)
            let sublabelSize = sublabelAttributed.size()

            backgroundRect.size.height += sublabelSize.height + 2
            backgroundRect.size.width = max(backgroundRect.size.width, sublabelSize.width + style.backgroundPadding * 2)
        }

        if style.drawFilledBackground {
            context.setFillColor(style.textBackgroundColor)
            context.fill(backgroundRect)
        }

        attributedText.draw(at: position)

        if let sublabelText = sublabel {
            let sublabelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: actualFontSize - 4, weight: .regular),
                .foregroundColor: color,
                .strokeColor: PlatformColor(cgColor: style.textOutlineColor) ?? .black,
                .strokeWidth: -style.textOutlineWidth
            ]
            let sublabelAttributed = NSAttributedString(string: sublabelText, attributes: sublabelAttributes)
            let sublabelPosition = CGPoint(x: position.x, y: position.y + textSize.height + 2)
            sublabelAttributed.draw(at: sublabelPosition)
        }
        #endif
    }

    // MARK: - Individual Visualization Methods

    /// Draw only person bounding boxes
    func drawPersonBoundingBoxes(
        on image: CGImage,
        people: [PersonDetectionResult]
    ) -> CGImage? {
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

        context.draw(image, in: CGRect(origin: .zero, size: imageSize))

        for person in people {
            drawPersonBoundingBox(person, in: context, imageSize: imageSize)
        }

        return context.makeImage()
    }

    /// Draw only pose skeletons
    func drawPoseSkeletons(
        on image: CGImage,
        poses: [PoseEstimationResult]
    ) -> CGImage? {
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

        context.draw(image, in: CGRect(origin: .zero, size: imageSize))

        for pose in poses {
            drawPoseSkeleton(pose, in: context, imageSize: imageSize)
        }

        return context.makeImage()
    }

    /// Draw only torso regions
    func drawTorsoRegions(
        on image: CGImage,
        regions: [BibDetectionRegion]
    ) -> CGImage? {
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

        context.draw(image, in: CGRect(origin: .zero, size: imageSize))

        for region in regions {
            drawTorsoRegion(region, in: context, imageSize: imageSize)
        }

        return context.makeImage()
    }
}
