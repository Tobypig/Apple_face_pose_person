//
//  FaceDetection.swift
//  Apple Vision Framework - Face Detection
//
//  Detects faces in images using Vision framework
//

import Vision
import CoreImage
import CoreGraphics

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Result structure for face detection
struct FaceDetectionResult {
    let boundingBox: CGRect
    let confidence: Float
    let faceID: Int
    let yaw: Float?
    let pitch: Float?
    let roll: Float?
}

/// Face Detection Manager using Vision framework
class FaceDetectionManager {

    // MARK: - Properties

    private var faceDetectionRequest: VNDetectFaceRectanglesRequest?
    private var faceCaptureQualityRequest: VNDetectFaceCaptureQualityRequest?

    // MARK: - Initialization

    init() {
        setupRequests()
    }

    // MARK: - Setup

    private func setupRequests() {
        // Basic face detection request
        faceDetectionRequest = VNDetectFaceRectanglesRequest()

        // Face capture quality request (provides more details)
        faceCaptureQualityRequest = VNDetectFaceCaptureQualityRequest()
    }

    // MARK: - Public Methods

    /// Detect faces in a CGImage
    /// - Parameter image: The image to analyze
    /// - Returns: Array of detected face results
    func detectFaces(in image: CGImage) throws -> [FaceDetectionResult] {
        guard let request = faceCaptureQualityRequest else {
            throw VisionError.requestNotInitialized
        }

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let observations = request.results as? [VNFaceObservation] else {
            return []
        }

        return observations.enumerated().map { index, observation in
            FaceDetectionResult(
                boundingBox: observation.boundingBox,
                confidence: observation.confidence,
                faceID: index,
                yaw: observation.yaw?.floatValue,
                pitch: observation.pitch?.floatValue,
                roll: observation.roll?.floatValue
            )
        }
    }

    #if !os(macOS)
    /// Detect faces in a UIImage
    /// - Parameter image: The UIImage to analyze
    /// - Returns: Array of detected face results
    func detectFaces(in image: UIImage) throws -> [FaceDetectionResult] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }
        return try detectFaces(in: cgImage)
    }
    #else
    /// Detect faces in an NSImage
    /// - Parameter image: The NSImage to analyze
    /// - Returns: Array of detected face results
    func detectFaces(in image: NSImage) throws -> [FaceDetectionResult] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw VisionError.invalidImage
        }
        return try detectFaces(in: cgImage)
    }
    #endif

    /// Detect faces in a CIImage
    /// - Parameter ciImage: The CIImage to analyze
    /// - Returns: Array of detected face results
    func detectFaces(in ciImage: CIImage) throws -> [FaceDetectionResult] {
        guard let request = faceCaptureQualityRequest else {
            throw VisionError.requestNotInitialized
        }

        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        try handler.perform([request])

        guard let observations = request.results as? [VNFaceObservation] else {
            return []
        }

        return observations.enumerated().map { index, observation in
            FaceDetectionResult(
                boundingBox: observation.boundingBox,
                confidence: observation.confidence,
                faceID: index,
                yaw: observation.yaw?.floatValue,
                pitch: observation.pitch?.floatValue,
                roll: observation.roll?.floatValue
            )
        }
    }

    /// Detect faces in video frame (CVPixelBuffer)
    /// - Parameter pixelBuffer: The pixel buffer from video
    /// - Returns: Array of detected face results
    func detectFaces(in pixelBuffer: CVPixelBuffer) throws -> [FaceDetectionResult] {
        guard let request = faceCaptureQualityRequest else {
            throw VisionError.requestNotInitialized
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try handler.perform([request])

        guard let observations = request.results as? [VNFaceObservation] else {
            return []
        }

        return observations.enumerated().map { index, observation in
            FaceDetectionResult(
                boundingBox: observation.boundingBox,
                confidence: observation.confidence,
                faceID: index,
                yaw: observation.yaw?.floatValue,
                pitch: observation.pitch?.floatValue,
                roll: observation.roll?.floatValue
            )
        }
    }

    // MARK: - Helper Methods

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
}

// MARK: - Error Types

enum VisionError: Error {
    case requestNotInitialized
    case invalidImage
    case processingFailed

    var localizedDescription: String {
        switch self {
        case .requestNotInitialized:
            return "Vision request not properly initialized"
        case .invalidImage:
            return "Invalid image format"
        case .processingFailed:
            return "Failed to process image"
        }
    }
}
