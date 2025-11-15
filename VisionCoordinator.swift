//
//  VisionCoordinator.swift
//  Apple Vision Framework - Integrated Coordinator
//
//  Coordinates all Vision framework features in a unified interface
//

import Vision
import CoreImage
import CoreGraphics

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Combined analysis result containing all detection types
struct VisionAnalysisResult {
    let faces: [FaceDetectionResult]
    let faceRecognitions: [FaceRecognitionResult]
    let poses: [PoseEstimationResult]
    let people: [PersonDetectionResult]
    let processingTime: TimeInterval
}

/// Coordinator for all Vision framework capabilities
class VisionCoordinator {

    // MARK: - Properties

    private let faceDetectionManager: FaceDetectionManager
    private let faceRecognitionManager: FaceRecognitionManager
    private let poseEstimationManager: PoseEstimationManager
    private let personDetectionManager: PersonDetectionManager

    // Configuration options
    var enableFaceDetection: Bool = true
    var enableFaceRecognition: Bool = false
    var enablePoseEstimation: Bool = true
    var enablePersonDetection: Bool = true

    // MARK: - Initialization

    init() {
        self.faceDetectionManager = FaceDetectionManager()
        self.faceRecognitionManager = FaceRecognitionManager()
        self.poseEstimationManager = PoseEstimationManager()
        self.personDetectionManager = PersonDetectionManager()
    }

    // MARK: - Comprehensive Analysis

    /// Perform complete vision analysis on an image
    /// Processing order: Person Detection -> Pose Estimation -> Face Detection -> Face Recognition
    /// - Parameter image: The CGImage to analyze
    /// - Returns: Combined results from all enabled detectors
    func analyzeImage(_ image: CGImage) throws -> VisionAnalysisResult {
        let startTime = Date()

        var faces: [FaceDetectionResult] = []
        var faceRecognitions: [FaceRecognitionResult] = []
        var poses: [PoseEstimationResult] = []
        var people: [PersonDetectionResult] = []

        // Step 1: Person Detection (First)
        if enablePersonDetection {
            people = try personDetectionManager.detectPeople(in: image)
        }

        // Step 2: Pose Estimation (Second)
        if enablePoseEstimation {
            poses = try poseEstimationManager.detectBodyPose(in: image)
        }

        // Step 3: Face Detection (Third)
        if enableFaceDetection {
            faces = try faceDetectionManager.detectFaces(in: image)
        }

        // Step 4: Face Recognition (Last)
        if enableFaceRecognition {
            faceRecognitions = try faceRecognitionManager.recognizeFaces(in: image)
        }

        let processingTime = Date().timeIntervalSince(startTime)

        return VisionAnalysisResult(
            faces: faces,
            faceRecognitions: faceRecognitions,
            poses: poses,
            people: people,
            processingTime: processingTime
        )
    }

    #if !os(macOS)
    /// Perform complete vision analysis on a UIImage
    /// - Parameter image: The UIImage to analyze
    /// - Returns: Combined results from all enabled detectors
    func analyzeImage(_ image: UIImage) throws -> VisionAnalysisResult {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }
        return try analyzeImage(cgImage)
    }
    #else
    /// Perform complete vision analysis on an NSImage
    /// - Parameter image: The NSImage to analyze
    /// - Returns: Combined results from all enabled detectors
    func analyzeImage(_ image: NSImage) throws -> VisionAnalysisResult {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw VisionError.invalidImage
        }
        return try analyzeImage(cgImage)
    }
    #endif

    /// Perform complete vision analysis on a CIImage
    /// Processing order: Person Detection -> Pose Estimation -> Face Detection -> Face Recognition
    /// - Parameter ciImage: The CIImage to analyze
    /// - Returns: Combined results from all enabled detectors
    func analyzeImage(_ ciImage: CIImage) throws -> VisionAnalysisResult {
        let startTime = Date()

        var faces: [FaceDetectionResult] = []
        var faceRecognitions: [FaceRecognitionResult] = []
        var poses: [PoseEstimationResult] = []
        var people: [PersonDetectionResult] = []

        // Step 1: Person Detection (First)
        if enablePersonDetection {
            people = try personDetectionManager.detectPeople(in: ciImage)
        }

        // Step 2: Pose Estimation (Second)
        if enablePoseEstimation {
            poses = try poseEstimationManager.detectBodyPose(in: ciImage)
        }

        // Step 3: Face Detection (Third)
        if enableFaceDetection {
            faces = try faceDetectionManager.detectFaces(in: ciImage)
        }

        // Step 4: Face Recognition (Last)
        if enableFaceRecognition {
            faceRecognitions = try faceRecognitionManager.recognizeFaces(in: ciImage)
        }

        let processingTime = Date().timeIntervalSince(startTime)

        return VisionAnalysisResult(
            faces: faces,
            faceRecognitions: faceRecognitions,
            poses: poses,
            people: people,
            processingTime: processingTime
        )
    }

    /// Perform complete vision analysis on a video frame
    /// Processing order: Person Detection -> Pose Estimation -> Face Detection -> Face Recognition
    /// - Parameter pixelBuffer: The CVPixelBuffer from video
    /// - Returns: Combined results from all enabled detectors
    func analyzeVideoFrame(_ pixelBuffer: CVPixelBuffer) throws -> VisionAnalysisResult {
        let startTime = Date()

        var faces: [FaceDetectionResult] = []
        var faceRecognitions: [FaceRecognitionResult] = []
        var poses: [PoseEstimationResult] = []
        var people: [PersonDetectionResult] = []

        // Step 1: Person Detection (First)
        if enablePersonDetection {
            people = try personDetectionManager.detectPeople(in: pixelBuffer)
        }

        // Step 2: Pose Estimation (Second)
        if enablePoseEstimation {
            poses = try poseEstimationManager.detectBodyPose(in: pixelBuffer)
        }

        // Step 3: Face Detection (Third)
        if enableFaceDetection {
            faces = try faceDetectionManager.detectFaces(in: pixelBuffer)
        }

        // Step 4: Face Recognition (Last)
        if enableFaceRecognition {
            faceRecognitions = try faceRecognitionManager.recognizeFaces(in: pixelBuffer)
        }

        let processingTime = Date().timeIntervalSince(startTime)

        return VisionAnalysisResult(
            faces: faces,
            faceRecognitions: faceRecognitions,
            poses: poses,
            people: people,
            processingTime: processingTime
        )
    }

    // MARK: - Individual Manager Access

    /// Get direct access to face detection manager
    var faceDetection: FaceDetectionManager {
        return faceDetectionManager
    }

    /// Get direct access to face recognition manager
    var faceRecognition: FaceRecognitionManager {
        return faceRecognitionManager
    }

    /// Get direct access to pose estimation manager
    var poseEstimation: PoseEstimationManager {
        return poseEstimationManager
    }

    /// Get direct access to person detection manager
    var personDetection: PersonDetectionManager {
        return personDetectionManager
    }

    // MARK: - Configuration Presets

    /// Configure for face-only analysis
    func configureFaceOnly() {
        enableFaceDetection = true
        enableFaceRecognition = true
        enablePoseEstimation = false
        enablePersonDetection = false
    }

    /// Configure for body/pose-only analysis
    func configureBodyOnly() {
        enableFaceDetection = false
        enableFaceRecognition = false
        enablePoseEstimation = true
        enablePersonDetection = true
    }

    /// Enable all analysis types
    func enableAll() {
        enableFaceDetection = true
        enableFaceRecognition = true
        enablePoseEstimation = true
        enablePersonDetection = true
    }

    /// Disable all analysis types
    func disableAll() {
        enableFaceDetection = false
        enableFaceRecognition = false
        enablePoseEstimation = false
        enablePersonDetection = false
    }

    // MARK: - Utility Methods

    /// Print analysis results summary
    func printSummary(_ result: VisionAnalysisResult) {
        print("Vision Analysis Results:")
        print("  Processing Time: \(String(format: "%.3f", result.processingTime))s")
        print("  Faces Detected: \(result.faces.count)")
        print("  Face Recognitions: \(result.faceRecognitions.count)")
        print("  Poses Detected: \(result.poses.count)")
        print("  People Detected: \(result.people.count)")

        if !result.faces.isEmpty {
            print("\n  Face Details:")
            for (index, face) in result.faces.enumerated() {
                print("    Face \(index): confidence=\(face.confidence)")
                if let yaw = face.yaw, let pitch = face.pitch, let roll = face.roll {
                    print("      Angles - yaw:\(yaw), pitch:\(pitch), roll:\(roll)")
                }
            }
        }

        if !result.poses.isEmpty {
            print("\n  Pose Details:")
            for (index, pose) in result.poses.enumerated() {
                print("    Person \(index): \(pose.joints.count) joints detected")
            }
        }
    }
}
