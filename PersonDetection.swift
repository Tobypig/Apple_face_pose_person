//
//  PersonDetection.swift
//  Apple Vision Framework - Person Detection
//
//  Detects people/humans in images using Vision framework
//

import Vision
import CoreImage
import CoreGraphics

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Detection type for person detection
enum PersonDetectionType {
    case fullBody
    case upperBody
}

/// Result structure for person detection
struct PersonDetectionResult {
    let boundingBox: CGRect
    let confidence: Float
    let personID: Int
    let detectionType: PersonDetectionType
}

/// Person Detection Manager using Vision framework
class PersonDetectionManager {

    // MARK: - Properties

    private var humanDetectionRequest: VNDetectHumanRectanglesRequest?
    private var humanBodyDetectionRequest: VNDetectHumanBodyPoseRequest?

    // MARK: - Initialization

    init() {
        setupRequests()
    }

    // MARK: - Setup

    private func setupRequests() {
        // Human rectangle detection (for bounding boxes)
        humanDetectionRequest = VNDetectHumanRectanglesRequest()

        // Can also use body pose for person detection with more detail
        humanBodyDetectionRequest = VNDetectHumanBodyPoseRequest()
    }

    // MARK: - Public Methods

    /// Detect people in a CGImage
    /// - Parameters:
    ///   - image: The image to analyze
    ///   - upperBodyOnly: If true, detect upper body only; if false, detect full body
    /// - Returns: Array of person detection results
    func detectPeople(in image: CGImage, upperBodyOnly: Bool = false) throws -> [PersonDetectionResult] {
        guard let request = humanDetectionRequest else {
            throw VisionError.requestNotInitialized
        }

        // Configure request for upper body or full body
        request.upperBodyOnly = upperBodyOnly

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let observations = request.results as? [VNHumanObservation] else {
            return []
        }

        return observations.enumerated().map { index, observation in
            PersonDetectionResult(
                boundingBox: observation.boundingBox,
                confidence: observation.confidence,
                personID: index,
                detectionType: upperBodyOnly ? .upperBody : .fullBody
            )
        }
    }

    #if !os(macOS)
    /// Detect people in a UIImage
    /// - Parameters:
    ///   - image: The UIImage to analyze
    ///   - upperBodyOnly: If true, detect upper body only
    /// - Returns: Array of person detection results
    func detectPeople(in image: UIImage, upperBodyOnly: Bool = false) throws -> [PersonDetectionResult] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }
        return try detectPeople(in: cgImage, upperBodyOnly: upperBodyOnly)
    }
    #else
    /// Detect people in an NSImage
    /// - Parameters:
    ///   - image: The NSImage to analyze
    ///   - upperBodyOnly: If true, detect upper body only
    /// - Returns: Array of person detection results
    func detectPeople(in image: NSImage, upperBodyOnly: Bool = false) throws -> [PersonDetectionResult] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw VisionError.invalidImage
        }
        return try detectPeople(in: cgImage, upperBodyOnly: upperBodyOnly)
    }
    #endif

    /// Detect people in a CIImage
    /// - Parameters:
    ///   - ciImage: The CIImage to analyze
    ///   - upperBodyOnly: If true, detect upper body only
    /// - Returns: Array of person detection results
    func detectPeople(in ciImage: CIImage, upperBodyOnly: Bool = false) throws -> [PersonDetectionResult] {
        guard let request = humanDetectionRequest else {
            throw VisionError.requestNotInitialized
        }

        request.upperBodyOnly = upperBodyOnly

        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        try handler.perform([request])

        guard let observations = request.results as? [VNHumanObservation] else {
            return []
        }

        return observations.enumerated().map { index, observation in
            PersonDetectionResult(
                boundingBox: observation.boundingBox,
                confidence: observation.confidence,
                personID: index,
                detectionType: upperBodyOnly ? .upperBody : .fullBody
            )
        }
    }

    /// Detect people in video frame (CVPixelBuffer)
    /// - Parameters:
    ///   - pixelBuffer: The pixel buffer from video
    ///   - upperBodyOnly: If true, detect upper body only
    /// - Returns: Array of person detection results
    func detectPeople(in pixelBuffer: CVPixelBuffer, upperBodyOnly: Bool = false) throws -> [PersonDetectionResult] {
        guard let request = humanDetectionRequest else {
            throw VisionError.requestNotInitialized
        }

        request.upperBodyOnly = upperBodyOnly

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try handler.perform([request])

        guard let observations = request.results as? [VNHumanObservation] else {
            return []
        }

        return observations.enumerated().map { index, observation in
            PersonDetectionResult(
                boundingBox: observation.boundingBox,
                confidence: observation.confidence,
                personID: index,
                detectionType: upperBodyOnly ? .upperBody : .fullBody
            )
        }
    }

    // MARK: - Advanced Detection with Body Pose

    /// Detect people using body pose (provides both detection and pose)
    /// - Parameter image: The image to analyze
    /// - Returns: Tuple of person detections and their corresponding poses
    func detectPeopleWithPose(in image: CGImage) throws -> ([PersonDetectionResult], [VNHumanBodyPoseObservation]) {
        guard let request = humanBodyDetectionRequest else {
            throw VisionError.requestNotInitialized
        }

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let observations = request.results as? [VNHumanBodyPoseObservation] else {
            return ([], [])
        }

        // Extract bounding boxes from pose observations
        let detections = observations.enumerated().map { index, observation in
            // Calculate bounding box from body joints
            let boundingBox = calculateBoundingBox(from: observation)

            return PersonDetectionResult(
                boundingBox: boundingBox,
                confidence: observation.confidence,
                personID: index,
                detectionType: .fullBody
            )
        }

        return (detections, observations)
    }

    // MARK: - Private Helper Methods

    private func calculateBoundingBox(from observation: VNHumanBodyPoseObservation) -> CGRect {
        guard let recognizedPoints = try? observation.recognizedPoints(.all) else {
            return .zero
        }

        var minX: CGFloat = 1.0
        var minY: CGFloat = 1.0
        var maxX: CGFloat = 0.0
        var maxY: CGFloat = 0.0

        for point in recognizedPoints.values where point.confidence > 0.2 {
            minX = min(minX, point.location.x)
            minY = min(minY, point.location.y)
            maxX = max(maxX, point.location.x)
            maxY = max(maxY, point.location.y)
        }

        // Add some padding (5%)
        let padding: CGFloat = 0.05
        minX = max(0, minX - padding)
        minY = max(0, minY - padding)
        maxX = min(1, maxX + padding)
        maxY = min(1, maxY + padding)

        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }

    // MARK: - Coordinate Conversion

    /// Convert Vision coordinates to image coordinates
    /// - Parameters:
    ///   - boundingBox: Vision framework bounding box (normalized 0-1)
    ///   - imageSize: Size of the image
    /// - Returns: Bounding box in image coordinates
    static func convertToImageCoordinates(boundingBox: CGRect, imageSize: CGSize) -> CGRect {
        let width = boundingBox.width * imageSize.width
        let height = boundingBox.height * imageSize.height
        let x = boundingBox.origin.x * imageSize.width
        let y = (1 - boundingBox.origin.y - boundingBox.height) * imageSize.height

        return CGRect(x: x, y: y, width: width, height: height)
    }

    // MARK: - Filtering and Tracking

    /// Filter detections by minimum confidence threshold
    /// - Parameters:
    ///   - detections: Array of person detections
    ///   - threshold: Minimum confidence (0.0 to 1.0)
    /// - Returns: Filtered array of detections
    static func filterByConfidence(_ detections: [PersonDetectionResult], threshold: Float = 0.5) -> [PersonDetectionResult] {
        return detections.filter { $0.confidence >= threshold }
    }

    /// Filter overlapping detections using non-maximum suppression
    /// - Parameters:
    ///   - detections: Array of person detections
    ///   - iouThreshold: Intersection over Union threshold for suppression
    /// - Returns: Filtered array with non-overlapping detections
    static func nonMaximumSuppression(_ detections: [PersonDetectionResult], iouThreshold: Float = 0.5) -> [PersonDetectionResult] {
        // Sort by confidence (highest first)
        let sorted = detections.sorted { $0.confidence > $1.confidence }
        var selected: [PersonDetectionResult] = []

        for detection in sorted {
            var shouldSelect = true

            for selectedDetection in selected {
                let iou = calculateIOU(detection.boundingBox, selectedDetection.boundingBox)
                if iou > CGFloat(iouThreshold) {
                    shouldSelect = false
                    break
                }
            }

            if shouldSelect {
                selected.append(detection)
            }
        }

        return selected
    }

    /// Calculate Intersection over Union for two bounding boxes
    private static func calculateIOU(_ box1: CGRect, _ box2: CGRect) -> CGFloat {
        let intersection = box1.intersection(box2)
        if intersection.isNull {
            return 0.0
        }

        let intersectionArea = intersection.width * intersection.height
        let unionArea = box1.width * box1.height + box2.width * box2.height - intersectionArea

        return intersectionArea / unionArea
    }
}
