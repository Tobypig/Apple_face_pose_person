//
//  FaceRecognition.swift
//  Apple Vision Framework - Face Recognition & Landmarks
//
//  Recognizes facial features and landmarks using Vision framework
//

import Vision
import CoreImage
import CoreGraphics

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Facial landmark regions
struct FaceLandmarkRegions {
    let faceContour: [CGPoint]?
    let leftEye: [CGPoint]?
    let rightEye: [CGPoint]?
    let leftEyebrow: [CGPoint]?
    let rightEyebrow: [CGPoint]?
    let nose: [CGPoint]?
    let noseCrest: [CGPoint]?
    let medianLine: [CGPoint]?
    let outerLips: [CGPoint]?
    let innerLips: [CGPoint]?
    let leftPupil: [CGPoint]?
    let rightPupil: [CGPoint]?
}

/// Result structure for face recognition
struct FaceRecognitionResult {
    let boundingBox: CGRect
    let confidence: Float
    let landmarks: FaceLandmarkRegions?
    let captureQuality: Float?
    let yaw: Float?
    let pitch: Float?
    let roll: Float?
}

/// Face Recognition Manager using Vision framework
class FaceRecognitionManager {

    // MARK: - Properties

    private var faceLandmarksRequest: VNDetectFaceLandmarksRequest?

    // MARK: - Initialization

    init() {
        setupRequests()
    }

    // MARK: - Setup

    private func setupRequests() {
        faceLandmarksRequest = VNDetectFaceLandmarksRequest()
        // Request all available landmarks
        faceLandmarksRequest?.revision = VNDetectFaceLandmarksRequestRevision3
    }

    // MARK: - Public Methods

    /// Recognize faces and extract landmarks in a CGImage
    /// - Parameter image: The image to analyze
    /// - Returns: Array of face recognition results with landmarks
    func recognizeFaces(in image: CGImage) throws -> [FaceRecognitionResult] {
        guard let request = faceLandmarksRequest else {
            throw VisionError.requestNotInitialized
        }

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let observations = request.results as? [VNFaceObservation] else {
            return []
        }

        return observations.map { observation in
            let landmarks = extractLandmarks(from: observation)

            return FaceRecognitionResult(
                boundingBox: observation.boundingBox,
                confidence: observation.confidence,
                landmarks: landmarks,
                captureQuality: (observation as? VNFaceObservation)?.faceCaptureQuality,
                yaw: observation.yaw?.floatValue,
                pitch: observation.pitch?.floatValue,
                roll: observation.roll?.floatValue
            )
        }
    }

    #if !os(macOS)
    /// Recognize faces in a UIImage
    /// - Parameter image: The UIImage to analyze
    /// - Returns: Array of face recognition results
    func recognizeFaces(in image: UIImage) throws -> [FaceRecognitionResult] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }
        return try recognizeFaces(in: cgImage)
    }
    #else
    /// Recognize faces in an NSImage
    /// - Parameter image: The NSImage to analyze
    /// - Returns: Array of face recognition results
    func recognizeFaces(in image: NSImage) throws -> [FaceRecognitionResult] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw VisionError.invalidImage
        }
        return try recognizeFaces(in: cgImage)
    }
    #endif

    /// Recognize faces in a CIImage
    /// - Parameter ciImage: The CIImage to analyze
    /// - Returns: Array of face recognition results
    func recognizeFaces(in ciImage: CIImage) throws -> [FaceRecognitionResult] {
        guard let request = faceLandmarksRequest else {
            throw VisionError.requestNotInitialized
        }

        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        try handler.perform([request])

        guard let observations = request.results as? [VNFaceObservation] else {
            return []
        }

        return observations.map { observation in
            let landmarks = extractLandmarks(from: observation)

            return FaceRecognitionResult(
                boundingBox: observation.boundingBox,
                confidence: observation.confidence,
                landmarks: landmarks,
                captureQuality: (observation as? VNFaceObservation)?.faceCaptureQuality,
                yaw: observation.yaw?.floatValue,
                pitch: observation.pitch?.floatValue,
                roll: observation.roll?.floatValue
            )
        }
    }

    /// Recognize faces in video frame (CVPixelBuffer)
    /// - Parameter pixelBuffer: The pixel buffer from video
    /// - Returns: Array of face recognition results
    func recognizeFaces(in pixelBuffer: CVPixelBuffer) throws -> [FaceRecognitionResult] {
        guard let request = faceLandmarksRequest else {
            throw VisionError.requestNotInitialized
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try handler.perform([request])

        guard let observations = request.results as? [VNFaceObservation] else {
            return []
        }

        return observations.map { observation in
            let landmarks = extractLandmarks(from: observation)

            return FaceRecognitionResult(
                boundingBox: observation.boundingBox,
                confidence: observation.confidence,
                landmarks: landmarks,
                captureQuality: (observation as? VNFaceObservation)?.faceCaptureQuality,
                yaw: observation.yaw?.floatValue,
                pitch: observation.pitch?.floatValue,
                roll: observation.roll?.floatValue
            )
        }
    }

    // MARK: - Private Helper Methods

    private func extractLandmarks(from observation: VNFaceObservation) -> FaceLandmarkRegions? {
        guard let landmarks = observation.landmarks else {
            return nil
        }

        return FaceLandmarkRegions(
            faceContour: landmarks.faceContour?.normalizedPoints,
            leftEye: landmarks.leftEye?.normalizedPoints,
            rightEye: landmarks.rightEye?.normalizedPoints,
            leftEyebrow: landmarks.leftEyebrow?.normalizedPoints,
            rightEyebrow: landmarks.rightEyebrow?.normalizedPoints,
            nose: landmarks.nose?.normalizedPoints,
            noseCrest: landmarks.noseCrest?.normalizedPoints,
            medianLine: landmarks.medianLine?.normalizedPoints,
            outerLips: landmarks.outerLips?.normalizedPoints,
            innerLips: landmarks.innerLips?.normalizedPoints,
            leftPupil: landmarks.leftPupil?.normalizedPoints,
            rightPupil: landmarks.rightPupil?.normalizedPoints
        )
    }

    // MARK: - Coordinate Conversion

    /// Convert normalized landmark points to image coordinates
    /// - Parameters:
    ///   - normalizedPoints: Normalized points from Vision (0-1 range)
    ///   - boundingBox: Face bounding box
    ///   - imageSize: Size of the image
    /// - Returns: Points in image coordinate space
    static func convertLandmarksToImageCoordinates(
        normalizedPoints: [CGPoint],
        boundingBox: CGRect,
        imageSize: CGSize
    ) -> [CGPoint] {
        return normalizedPoints.map { point in
            let x = boundingBox.origin.x + point.x * boundingBox.width
            let y = boundingBox.origin.y + point.y * boundingBox.height

            return CGPoint(
                x: x * imageSize.width,
                y: (1 - y) * imageSize.height
            )
        }
    }
}

// MARK: - Extension for VNFaceLandmarkRegion2D

extension VNFaceLandmarkRegion2D {
    /// Get normalized points as CGPoint array
    var normalizedPoints: [CGPoint] {
        return (0..<pointCount).map { index in
            let point = normalizedPoints[index]
            return CGPoint(x: CGFloat(point.x), y: CGFloat(point.y))
        }
    }
}
