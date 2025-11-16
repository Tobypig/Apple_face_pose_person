//
//  TorsoRegionDetection.swift
//  Apple Vision Framework - Torso Region & Bib Number Detection
//
//  Defines torso regions for bib number detection in sports/race scenarios
//

import Vision
import CoreImage
import CoreGraphics
import Foundation

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Torso Region Definitions

/// Torso region zones for bib number detection
enum TorsoZone: String {
    case upperChest        // Standard bib placement (shoulders to mid-torso)
    case midTorso          // Lower chest placement (mid-torso to upper abdomen)
    case lowerTorso        // Lower abdomen/waist placement (abdomen to hips)
    case extendedLowerTorso // Extended lower region (hips to below hips) - for low bib placement
    case fullTorso         // Entire torso region (shoulders to hips)
}

/// Bib detection region with coordinates and metadata
struct BibDetectionRegion {
    let zone: TorsoZone
    let boundingBox: CGRect          // Normalized coordinates (0-1)
    let confidence: Float            // Joint detection confidence
    let personID: Int                // Associated person ID
    let centerPoint: CGPoint         // Center of the region
    let joints: TorsoJoints          // Associated joints
}

/// Key torso joints for region calculation
struct TorsoJoints {
    let leftShoulder: JointPoint?
    let rightShoulder: JointPoint?
    let leftHip: JointPoint?
    let rightHip: JointPoint?
    let leftElbow: JointPoint?       // For width estimation
    let rightElbow: JointPoint?      // For width estimation
    let neck: JointPoint?            // For upper boundary
    let root: JointPoint?            // For lower boundary (pelvis center)

    /// Average confidence of all detected joints
    var averageConfidence: Float {
        var confidences: [Float] = []
        if let ls = leftShoulder { confidences.append(ls.confidence) }
        if let rs = rightShoulder { confidences.append(rs.confidence) }
        if let lh = leftHip { confidences.append(lh.confidence) }
        if let rh = rightHip { confidences.append(rh.confidence) }
        if let le = leftElbow { confidences.append(le.confidence) }
        if let re = rightElbow { confidences.append(re.confidence) }
        if let n = neck { confidences.append(n.confidence) }
        if let r = root { confidences.append(r.confidence) }

        guard !confidences.isEmpty else { return 0.0 }
        return confidences.reduce(0, +) / Float(confidences.count)
    }
}

// MARK: - Torso Region Manager

class TorsoRegionManager {

    // MARK: - Configuration

    /// Width expansion factor for bib detection (default: 1.2 = 20% wider)
    var widthExpansionFactor: CGFloat = 1.2

    /// Height expansion factor for bib detection (default: 1.1 = 10% taller)
    var heightExpansionFactor: CGFloat = 1.1

    /// Minimum joint confidence required (default: 0.3)
    var minJointConfidence: Float = 0.3

    /// Enable extended lower torso region (for bibs placed at/below hip level)
    var enableExtendedLowerTorso: Bool = true

    /// Extension below hip level as factor of torso height (default: 0.3 = 30% of torso height below hips)
    var lowerExtensionFactor: CGFloat = 0.3

    // MARK: - Public Methods

    /// Extract torso regions from pose estimation results
    /// - Parameters:
    ///   - poses: Array of pose estimation results
    ///   - zones: Which zones to extract (default: all including extended lower torso)
    /// - Returns: Array of bib detection regions
    func extractTorsoRegions(
        from poses: [PoseEstimationResult],
        zones: [TorsoZone] = [.upperChest, .midTorso, .lowerTorso, .extendedLowerTorso]
    ) -> [BibDetectionRegion] {

        var regions: [BibDetectionRegion] = []

        for pose in poses {
            let joints = extractTorsoJoints(from: pose)

            // Only process if we have minimum required joints
            guard joints.averageConfidence >= minJointConfidence else {
                continue
            }

            for zone in zones {
                if let region = calculateBibRegion(for: zone, joints: joints, personID: pose.personID) {
                    regions.append(region)
                }
            }
        }

        return regions
    }

    /// Get the most likely bib detection region for a person
    /// - Parameter pose: Pose estimation result
    /// - Returns: Best bib detection region (upper chest preferred)
    func getPrimaryBibRegion(from pose: PoseEstimationResult) -> BibDetectionRegion? {
        let joints = extractTorsoJoints(from: pose)

        guard joints.averageConfidence >= minJointConfidence else {
            return nil
        }

        // Try upper chest first (most common)
        if let upperRegion = calculateBibRegion(for: .upperChest, joints: joints, personID: pose.personID) {
            return upperRegion
        }

        // Fallback to mid torso
        if let midRegion = calculateBibRegion(for: .midTorso, joints: joints, personID: pose.personID) {
            return midRegion
        }

        // Last resort: lower torso
        return calculateBibRegion(for: .lowerTorso, joints: joints, personID: pose.personID)
    }

    /// Get all possible bib regions ordered by likelihood
    /// - Parameter pose: Pose estimation result
    /// - Returns: Array of regions ordered from most to least likely
    func getAllBibRegions(from pose: PoseEstimationResult) -> [BibDetectionRegion] {
        let joints = extractTorsoJoints(from: pose)

        guard joints.averageConfidence >= minJointConfidence else {
            return []
        }

        var regions: [BibDetectionRegion] = []

        // Order: upper chest (most common) -> mid torso -> lower torso -> extended lower (fallback)
        var zonePriority: [TorsoZone] = [.upperChest, .midTorso, .lowerTorso]
        if enableExtendedLowerTorso {
            zonePriority.append(.extendedLowerTorso)
        }

        for zone in zonePriority {
            if let region = calculateBibRegion(for: zone, joints: joints, personID: pose.personID) {
                regions.append(region)
            }
        }

        return regions
    }

    // MARK: - Private Helper Methods

    private func extractTorsoJoints(from pose: PoseEstimationResult) -> TorsoJoints {
        return TorsoJoints(
            leftShoulder: pose.joints["left_shoulder"],
            rightShoulder: pose.joints["right_shoulder"],
            leftHip: pose.joints["left_hip"],
            rightHip: pose.joints["right_hip"],
            leftElbow: pose.joints["left_elbow"],
            rightElbow: pose.joints["right_elbow"],
            neck: pose.joints["neck"],
            root: pose.joints["root"]
        )
    }

    private func calculateBibRegion(
        for zone: TorsoZone,
        joints: TorsoJoints,
        personID: Int
    ) -> BibDetectionRegion? {

        switch zone {
        case .upperChest:
            return calculateUpperChestRegion(joints: joints, personID: personID)
        case .midTorso:
            return calculateMidTorsoRegion(joints: joints, personID: personID)
        case .lowerTorso:
            return calculateLowerTorsoRegion(joints: joints, personID: personID)
        case .extendedLowerTorso:
            return calculateExtendedLowerTorsoRegion(joints: joints, personID: personID)
        case .fullTorso:
            return calculateFullTorsoRegion(joints: joints, personID: personID)
        }
    }

    // MARK: - Region Calculations

    /// Upper chest region: Shoulders to mid-torso (MOST COMMON BIB PLACEMENT)
    /// Typical bib placement: 60-80% between shoulders and hips
    private func calculateUpperChestRegion(joints: TorsoJoints, personID: Int) -> BibDetectionRegion? {
        guard let leftShoulder = joints.leftShoulder,
              let rightShoulder = joints.rightShoulder,
              let leftHip = joints.leftHip,
              let rightHip = joints.rightHip else {
            return nil
        }

        // Calculate shoulder midpoint (top boundary)
        let shoulderMidX = (leftShoulder.position.x + rightShoulder.position.x) / 2
        let shoulderMidY = (leftShoulder.position.y + rightShoulder.position.y) / 2

        // Calculate hip midpoint
        let hipMidX = (leftHip.position.x + rightHip.position.x) / 2
        let hipMidY = (leftHip.position.y + rightHip.position.y) / 2

        // Torso height
        let torsoHeight = abs(shoulderMidY - hipMidY)

        // Upper chest region: Top 60% of torso
        let regionTop = shoulderMidY
        let regionBottom = shoulderMidY - (torsoHeight * 0.6)
        let regionHeight = abs(regionTop - regionBottom)

        // Width: shoulder width + expansion
        let shoulderWidth = abs(rightShoulder.position.x - leftShoulder.position.x)
        let regionWidth = shoulderWidth * widthExpansionFactor

        // Center horizontally between shoulders
        let regionCenterX = shoulderMidX

        // Bounding box (normalized coordinates)
        let bbox = CGRect(
            x: regionCenterX - regionWidth / 2,
            y: regionBottom,  // Vision uses bottom-left origin
            width: regionWidth,
            height: regionHeight * heightExpansionFactor
        )

        let centerPoint = CGPoint(
            x: regionCenterX,
            y: (regionTop + regionBottom) / 2
        )

        return BibDetectionRegion(
            zone: .upperChest,
            boundingBox: bbox,
            confidence: joints.averageConfidence,
            personID: personID,
            centerPoint: centerPoint,
            joints: joints
        )
    }

    /// Mid torso region: Mid-torso to upper abdomen (ALTERNATIVE BIB PLACEMENT)
    /// Typical placement: 40-60% between shoulders and hips
    private func calculateMidTorsoRegion(joints: TorsoJoints, personID: Int) -> BibDetectionRegion? {
        guard let leftShoulder = joints.leftShoulder,
              let rightShoulder = joints.rightShoulder,
              let leftHip = joints.leftHip,
              let rightHip = joints.rightHip else {
            return nil
        }

        let shoulderMidX = (leftShoulder.position.x + rightShoulder.position.x) / 2
        let shoulderMidY = (leftShoulder.position.y + rightShoulder.position.y) / 2
        let hipMidX = (leftHip.position.x + rightHip.position.x) / 2
        let hipMidY = (leftHip.position.y + rightHip.position.y) / 2

        let torsoHeight = abs(shoulderMidY - hipMidY)

        // Mid torso: 40-60% range (20% height)
        let regionTop = shoulderMidY - (torsoHeight * 0.4)
        let regionBottom = shoulderMidY - (torsoHeight * 0.6)
        let regionHeight = abs(regionTop - regionBottom)

        // Width: average of shoulder and hip width
        let shoulderWidth = abs(rightShoulder.position.x - leftShoulder.position.x)
        let hipWidth = abs(rightHip.position.x - leftHip.position.x)
        let avgWidth = (shoulderWidth + hipWidth) / 2
        let regionWidth = avgWidth * widthExpansionFactor

        let regionCenterX = (shoulderMidX + hipMidX) / 2

        let bbox = CGRect(
            x: regionCenterX - regionWidth / 2,
            y: regionBottom,
            width: regionWidth,
            height: regionHeight * heightExpansionFactor
        )

        let centerPoint = CGPoint(
            x: regionCenterX,
            y: (regionTop + regionBottom) / 2
        )

        return BibDetectionRegion(
            zone: .midTorso,
            boundingBox: bbox,
            confidence: joints.averageConfidence,
            personID: personID,
            centerPoint: centerPoint,
            joints: joints
        )
    }

    /// Lower torso region: Abdomen to hips (LOWER BIB PLACEMENT)
    /// Sometimes used in triathlons or when bibs are placed lower
    /// Range: 20-40% between shoulders and hips
    private func calculateLowerTorsoRegion(joints: TorsoJoints, personID: Int) -> BibDetectionRegion? {
        guard let leftShoulder = joints.leftShoulder,
              let rightShoulder = joints.rightShoulder,
              let leftHip = joints.leftHip,
              let rightHip = joints.rightHip else {
            return nil
        }

        let shoulderMidX = (leftShoulder.position.x + rightShoulder.position.x) / 2
        let shoulderMidY = (leftShoulder.position.y + rightShoulder.position.y) / 2
        let hipMidX = (leftHip.position.x + rightHip.position.x) / 2
        let hipMidY = (leftHip.position.y + rightHip.position.y) / 2

        let torsoHeight = abs(shoulderMidY - hipMidY)

        // Lower torso: 20-40% range (20% height)
        let regionTop = shoulderMidY - (torsoHeight * 0.2)
        let regionBottom = shoulderMidY - (torsoHeight * 0.4)
        let regionHeight = abs(regionTop - regionBottom)

        // Width: primarily hip width
        let hipWidth = abs(rightHip.position.x - leftHip.position.x)
        let regionWidth = hipWidth * widthExpansionFactor

        let regionCenterX = hipMidX

        let bbox = CGRect(
            x: regionCenterX - regionWidth / 2,
            y: regionBottom,
            width: regionWidth,
            height: regionHeight * heightExpansionFactor
        )

        let centerPoint = CGPoint(
            x: regionCenterX,
            y: (regionTop + regionBottom) / 2
        )

        return BibDetectionRegion(
            zone: .lowerTorso,
            boundingBox: bbox,
            confidence: joints.averageConfidence,
            personID: personID,
            centerPoint: centerPoint,
            joints: joints
        )
    }

    /// Extended lower torso region: Hips to below hips (VERY LOW BIB PLACEMENT)
    /// Fallback for unusual cases where bibs are worn at or below hip level
    /// Extends below hip by configurable factor (default 30% of torso height)
    private func calculateExtendedLowerTorsoRegion(joints: TorsoJoints, personID: Int) -> BibDetectionRegion? {
        guard enableExtendedLowerTorso else {
            return nil
        }

        guard let leftShoulder = joints.leftShoulder,
              let rightShoulder = joints.rightShoulder,
              let leftHip = joints.leftHip,
              let rightHip = joints.rightHip else {
            return nil
        }

        let shoulderMidX = (leftShoulder.position.x + rightShoulder.position.x) / 2
        let shoulderMidY = (leftShoulder.position.y + rightShoulder.position.y) / 2
        let hipMidX = (leftHip.position.x + rightHip.position.x) / 2
        let hipMidY = (leftHip.position.y + rightHip.position.y) / 2

        let torsoHeight = abs(shoulderMidY - hipMidY)

        // Extended region: From hip level down to (hip - extension)
        // Extension factor = 0.3 means 30% of torso height below hips
        let extensionHeight = torsoHeight * lowerExtensionFactor

        let regionTop = hipMidY
        let regionBottom = hipMidY - extensionHeight
        let regionHeight = abs(regionTop - regionBottom)

        // Width: hip width + expansion (slightly wider for lower placement)
        let hipWidth = abs(rightHip.position.x - leftHip.position.x)
        let regionWidth = hipWidth * widthExpansionFactor * 1.1  // Slightly wider for lower region

        let regionCenterX = hipMidX

        let bbox = CGRect(
            x: regionCenterX - regionWidth / 2,
            y: regionBottom,
            width: regionWidth,
            height: regionHeight * heightExpansionFactor
        )

        let centerPoint = CGPoint(
            x: regionCenterX,
            y: (regionTop + regionBottom) / 2
        )

        return BibDetectionRegion(
            zone: .extendedLowerTorso,
            boundingBox: bbox,
            confidence: joints.averageConfidence * 0.8,  // Lower confidence for this unusual placement
            personID: personID,
            centerPoint: centerPoint,
            joints: joints
        )
    }

    /// Full torso region: Entire torso from shoulders to hips
    /// Use when bib placement is unknown
    private func calculateFullTorsoRegion(joints: TorsoJoints, personID: Int) -> BibDetectionRegion? {
        guard let leftShoulder = joints.leftShoulder,
              let rightShoulder = joints.rightShoulder,
              let leftHip = joints.leftHip,
              let rightHip = joints.rightHip else {
            return nil
        }

        let shoulderMidX = (leftShoulder.position.x + rightShoulder.position.x) / 2
        let shoulderMidY = (leftShoulder.position.y + rightShoulder.position.y) / 2
        let hipMidX = (leftHip.position.x + rightHip.position.x) / 2
        let hipMidY = (leftHip.position.y + rightHip.position.y) / 2

        let regionTop = shoulderMidY
        let regionBottom = hipMidY
        let regionHeight = abs(regionTop - regionBottom)

        // Width: maximum of shoulder and hip width
        let shoulderWidth = abs(rightShoulder.position.x - leftShoulder.position.x)
        let hipWidth = abs(rightHip.position.x - leftHip.position.x)
        let maxWidth = max(shoulderWidth, hipWidth)
        let regionWidth = maxWidth * widthExpansionFactor

        let regionCenterX = (shoulderMidX + hipMidX) / 2

        let bbox = CGRect(
            x: regionCenterX - regionWidth / 2,
            y: regionBottom,
            width: regionWidth,
            height: regionHeight * heightExpansionFactor
        )

        let centerPoint = CGPoint(
            x: regionCenterX,
            y: (regionTop + regionBottom) / 2
        )

        return BibDetectionRegion(
            zone: .fullTorso,
            boundingBox: bbox,
            confidence: joints.averageConfidence,
            personID: personID,
            centerPoint: centerPoint,
            joints: joints
        )
    }

    // MARK: - Utility Methods

    /// Convert bib region to image coordinates
    /// - Parameters:
    ///   - region: Bib detection region (normalized)
    ///   - imageSize: Size of the image
    /// - Returns: Bounding box in pixel coordinates
    static func convertToImageCoordinates(region: BibDetectionRegion, imageSize: CGSize) -> CGRect {
        let bbox = region.boundingBox

        let width = bbox.width * imageSize.width
        let height = bbox.height * imageSize.height
        let x = bbox.origin.x * imageSize.width
        // Convert from Vision coordinates (bottom-left) to UIKit (top-left)
        let y = (1 - bbox.origin.y - bbox.height) * imageSize.height

        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Crop image to bib detection region
    /// - Parameters:
    ///   - image: Source image
    ///   - region: Bib detection region
    /// - Returns: Cropped image for OCR processing
    static func cropToBibRegion(image: CGImage, region: BibDetectionRegion) -> CGImage? {
        let imageSize = CGSize(width: image.width, height: image.height)
        let bbox = convertToImageCoordinates(region: region, imageSize: imageSize)

        // Clamp to image bounds
        let clampedRect = CGRect(
            x: max(0, bbox.origin.x),
            y: max(0, bbox.origin.y),
            width: min(bbox.width, CGFloat(image.width) - bbox.origin.x),
            height: min(bbox.height, CGFloat(image.height) - bbox.origin.y)
        )

        return image.cropping(to: clampedRect)
    }
}

// MARK: - Visualization Extensions

extension TorsoRegionManager {

    /// Get color for zone (for debugging visualization)
    static func colorForZone(_ zone: TorsoZone) -> CGColor {
        switch zone {
        case .upperChest:
            return CGColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 0.5) // Green
        case .midTorso:
            return CGColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 0.5) // Yellow
        case .lowerTorso:
            return CGColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.5) // Orange
        case .extendedLowerTorso:
            return CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.5) // Red (fallback region)
        case .fullTorso:
            return CGColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 0.3) // Blue
        }
    }

    /// Get label for zone
    static func labelForZone(_ zone: TorsoZone) -> String {
        switch zone {
        case .upperChest:
            return "Upper Chest (Primary)"
        case .midTorso:
            return "Mid Torso"
        case .lowerTorso:
            return "Lower Torso"
        case .extendedLowerTorso:
            return "Extended Lower (Below Hips)"
        case .fullTorso:
            return "Full Torso"
        }
    }
}
