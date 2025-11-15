//
//  PoseEstimation.swift
//  Apple Vision Framework - Human Pose Estimation
//
//  Estimates human body poses using Vision framework
//

import Vision
import CoreImage
import CoreGraphics

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Joint name enumeration for body pose
enum BodyJoint: String, CaseIterable {
    case nose = "nose"
    case neck = "neck"
    case rightShoulder = "right_shoulder"
    case rightElbow = "right_elbow"
    case rightWrist = "right_wrist"
    case leftShoulder = "left_shoulder"
    case leftElbow = "left_elbow"
    case leftWrist = "left_wrist"
    case rightHip = "right_hip"
    case rightKnee = "right_knee"
    case rightAnkle = "right_ankle"
    case leftHip = "left_hip"
    case leftKnee = "left_knee"
    case leftAnkle = "left_ankle"
    case rightEye = "right_eye"
    case leftEye = "left_eye"
    case rightEar = "right_ear"
    case leftEar = "left_ear"
    case root = "root"
}

/// Joint point with position and confidence
struct JointPoint {
    let position: CGPoint
    let confidence: Float
    let jointName: String
}

/// Result structure for pose estimation
struct PoseEstimationResult {
    let joints: [String: JointPoint]
    let confidence: Float
    let personID: Int
}

/// Pose Estimation Manager using Vision framework
class PoseEstimationManager {

    // MARK: - Properties

    private var bodyPoseRequest: VNDetectHumanBodyPoseRequest?
    private var handPoseRequest: VNDetectHumanHandPoseRequest?

    // MARK: - Initialization

    init() {
        setupRequests()
    }

    // MARK: - Setup

    private func setupRequests() {
        bodyPoseRequest = VNDetectHumanBodyPoseRequest()
        handPoseRequest = VNDetectHumanHandPoseRequest()
    }

    // MARK: - Public Methods - Body Pose

    /// Detect human body poses in a CGImage
    /// - Parameter image: The image to analyze
    /// - Returns: Array of pose estimation results
    func detectBodyPose(in image: CGImage) throws -> [PoseEstimationResult] {
        guard let request = bodyPoseRequest else {
            throw VisionError.requestNotInitialized
        }

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let observations = request.results as? [VNHumanBodyPoseObservation] else {
            return []
        }

        return try observations.enumerated().map { index, observation in
            try extractBodyPose(from: observation, personID: index)
        }
    }

    #if !os(macOS)
    /// Detect body poses in a UIImage
    /// - Parameter image: The UIImage to analyze
    /// - Returns: Array of pose estimation results
    func detectBodyPose(in image: UIImage) throws -> [PoseEstimationResult] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }
        return try detectBodyPose(in: cgImage)
    }
    #else
    /// Detect body poses in an NSImage
    /// - Parameter image: The NSImage to analyze
    /// - Returns: Array of pose estimation results
    func detectBodyPose(in image: NSImage) throws -> [PoseEstimationResult] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw VisionError.invalidImage
        }
        return try detectBodyPose(in: cgImage)
    }
    #endif

    /// Detect body poses in a CIImage
    /// - Parameter ciImage: The CIImage to analyze
    /// - Returns: Array of pose estimation results
    func detectBodyPose(in ciImage: CIImage) throws -> [PoseEstimationResult] {
        guard let request = bodyPoseRequest else {
            throw VisionError.requestNotInitialized
        }

        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        try handler.perform([request])

        guard let observations = request.results as? [VNHumanBodyPoseObservation] else {
            return []
        }

        return try observations.enumerated().map { index, observation in
            try extractBodyPose(from: observation, personID: index)
        }
    }

    /// Detect body poses in video frame (CVPixelBuffer)
    /// - Parameter pixelBuffer: The pixel buffer from video
    /// - Returns: Array of pose estimation results
    func detectBodyPose(in pixelBuffer: CVPixelBuffer) throws -> [PoseEstimationResult] {
        guard let request = bodyPoseRequest else {
            throw VisionError.requestNotInitialized
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try handler.perform([request])

        guard let observations = request.results as? [VNHumanBodyPoseObservation] else {
            return []
        }

        return try observations.enumerated().map { index, observation in
            try extractBodyPose(from: observation, personID: index)
        }
    }

    // MARK: - Public Methods - Hand Pose

    /// Detect hand poses in a CGImage
    /// - Parameter image: The image to analyze
    /// - Returns: Array of recognized points for each hand
    func detectHandPose(in image: CGImage) throws -> [[VNRecognizedPoint]] {
        guard let request = handPoseRequest else {
            throw VisionError.requestNotInitialized
        }

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let observations = request.results as? [VNHumanHandPoseObservation] else {
            return []
        }

        return try observations.map { observation in
            try extractHandPoints(from: observation)
        }
    }

    // MARK: - Private Helper Methods

    private func extractBodyPose(from observation: VNHumanBodyPoseObservation, personID: Int) throws -> PoseEstimationResult {
        var joints: [String: JointPoint] = [:]

        // Get all recognized points
        let recognizedPoints = try observation.recognizedPoints(.all)

        for (jointKey, point) in recognizedPoints {
            guard point.confidence > 0.1 else { continue } // Filter low confidence points

            joints[jointKey.rawValue] = JointPoint(
                position: point.location,
                confidence: point.confidence,
                jointName: jointKey.rawValue
            )
        }

        return PoseEstimationResult(
            joints: joints,
            confidence: observation.confidence,
            personID: personID
        )
    }

    private func extractHandPoints(from observation: VNHumanHandPoseObservation) throws -> [VNRecognizedPoint] {
        let allPoints = try observation.recognizedPoints(.all)
        return Array(allPoints.values)
    }

    // MARK: - Coordinate Conversion

    /// Convert normalized pose points to image coordinates
    /// - Parameters:
    ///   - point: Normalized point from Vision (0-1 range)
    ///   - imageSize: Size of the image
    /// - Returns: Point in image coordinate space
    static func convertToImageCoordinates(point: CGPoint, imageSize: CGSize) -> CGPoint {
        return CGPoint(
            x: point.x * imageSize.width,
            y: (1 - point.y) * imageSize.height
        )
    }

    // MARK: - Skeleton Drawing Helpers

    /// Get common skeleton connections for drawing
    /// - Returns: Array of joint name pairs representing connections
    static func getSkeletonConnections() -> [(String, String)] {
        return [
            // Head
            ("nose", "neck"),
            ("nose", "right_eye"),
            ("nose", "left_eye"),
            ("right_eye", "right_ear"),
            ("left_eye", "left_ear"),

            // Torso
            ("neck", "right_shoulder"),
            ("neck", "left_shoulder"),
            ("right_shoulder", "right_hip"),
            ("left_shoulder", "left_hip"),
            ("right_hip", "left_hip"),

            // Right arm
            ("right_shoulder", "right_elbow"),
            ("right_elbow", "right_wrist"),

            // Left arm
            ("left_shoulder", "left_elbow"),
            ("left_elbow", "left_wrist"),

            // Right leg
            ("right_hip", "right_knee"),
            ("right_knee", "right_ankle"),

            // Left leg
            ("left_hip", "left_knee"),
            ("left_knee", "left_ankle")
        ]
    }

    /// Check if a specific joint is available
    /// - Parameters:
    ///   - observation: The pose observation
    ///   - jointName: Name of the joint to check
    /// - Returns: The recognized point if available and confident
    func getJoint(from observation: VNHumanBodyPoseObservation, jointName: VNHumanBodyPoseObservation.JointName) -> VNRecognizedPoint? {
        guard let point = try? observation.recognizedPoint(jointName),
              point.confidence > 0.2 else {
            return nil
        }
        return point
    }
}
