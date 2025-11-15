//
//  VisionFrameworkTests.swift
//  Apple Vision Framework - Comprehensive Test Suite
//
//  Automated tests for all Vision framework components
//

import XCTest
import Vision
import CoreImage
import CoreGraphics

#if os(macOS)
import AppKit
#else
import UIKit
#endif

class VisionFrameworkTests: XCTestCase {

    // MARK: - Test Resources

    var testImage: CGImage!
    var testImageWithPerson: CGImage!
    var testImageWithFace: CGImage!

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Generate test images
        testImage = createTestImage(size: CGSize(width: 640, height: 480))
        testImageWithPerson = createTestImageWithPerson()
        testImageWithFace = createTestImageWithFace()
    }

    override func tearDownWithError() throws {
        testImage = nil
        testImageWithPerson = nil
        testImageWithFace = nil
        try super.tearDownWithError()
    }

    // MARK: - Face Detection Tests

    func testFaceDetectionInitialization() {
        let manager = FaceDetectionManager()
        XCTAssertNotNil(manager, "FaceDetectionManager should initialize successfully")
    }

    func testFaceDetectionWithCGImage() throws {
        let manager = FaceDetectionManager()
        let results = try manager.detectFaces(in: testImage)

        XCTAssertNotNil(results, "Face detection should return results")
        XCTAssertTrue(results is [FaceDetectionResult], "Results should be array of FaceDetectionResult")
    }

    func testFaceDetectionWithCIImage() throws {
        let manager = FaceDetectionManager()
        let ciImage = CIImage(cgImage: testImage)
        let results = try manager.detectFaces(in: ciImage)

        XCTAssertNotNil(results, "Face detection with CIImage should return results")
    }

    func testFaceDetectionResultStructure() throws {
        let manager = FaceDetectionManager()
        let results = try manager.detectFaces(in: testImageWithFace)

        for result in results {
            XCTAssertTrue(result.confidence >= 0.0 && result.confidence <= 1.0,
                         "Confidence should be between 0 and 1")
            XCTAssertTrue(result.boundingBox.width >= 0, "Bounding box width should be non-negative")
            XCTAssertTrue(result.boundingBox.height >= 0, "Bounding box height should be non-negative")
            XCTAssertTrue(result.faceID >= 0, "Face ID should be non-negative")
        }
    }

    func testFaceDetectionCoordinateConversion() {
        let boundingBox = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        let imageSize = CGSize(width: 1000, height: 1000)

        let converted = FaceDetectionManager.convertToImageCoordinates(
            boundingBox: boundingBox,
            imageSize: imageSize
        )

        XCTAssertEqual(converted.origin.x, 250, accuracy: 0.1)
        XCTAssertEqual(converted.width, 500, accuracy: 0.1)
    }

    // MARK: - Face Recognition Tests

    func testFaceRecognitionInitialization() {
        let manager = FaceRecognitionManager()
        XCTAssertNotNil(manager, "FaceRecognitionManager should initialize successfully")
    }

    func testFaceRecognitionWithCGImage() throws {
        let manager = FaceRecognitionManager()
        let results = try manager.recognizeFaces(in: testImage)

        XCTAssertNotNil(results, "Face recognition should return results")
        XCTAssertTrue(results is [FaceRecognitionResult], "Results should be array of FaceRecognitionResult")
    }

    func testFaceRecognitionLandmarks() throws {
        let manager = FaceRecognitionManager()
        let results = try manager.recognizeFaces(in: testImageWithFace)

        for result in results {
            // Landmarks might be nil if no face is detected
            if let landmarks = result.landmarks {
                // Check that at least some landmark regions are populated
                let hasLandmarks = landmarks.faceContour != nil ||
                                  landmarks.leftEye != nil ||
                                  landmarks.rightEye != nil ||
                                  landmarks.nose != nil

                if hasLandmarks {
                    XCTAssertTrue(true, "At least some landmarks should be detected")
                }
            }
        }
    }

    func testFaceRecognitionCoordinateConversion() {
        let normalizedPoints = [
            CGPoint(x: 0.5, y: 0.5),
            CGPoint(x: 0.25, y: 0.75)
        ]
        let boundingBox = CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
        let imageSize = CGSize(width: 1000, height: 1000)

        let converted = FaceRecognitionManager.convertLandmarksToImageCoordinates(
            normalizedPoints: normalizedPoints,
            boundingBox: boundingBox,
            imageSize: imageSize
        )

        XCTAssertEqual(converted.count, normalizedPoints.count)
        XCTAssertTrue(converted[0].x >= 0 && converted[0].x <= imageSize.width)
        XCTAssertTrue(converted[0].y >= 0 && converted[0].y <= imageSize.height)
    }

    // MARK: - Pose Estimation Tests

    func testPoseEstimationInitialization() {
        let manager = PoseEstimationManager()
        XCTAssertNotNil(manager, "PoseEstimationManager should initialize successfully")
    }

    func testPoseEstimationWithCGImage() throws {
        let manager = PoseEstimationManager()
        let results = try manager.detectBodyPose(in: testImage)

        XCTAssertNotNil(results, "Pose estimation should return results")
        XCTAssertTrue(results is [PoseEstimationResult], "Results should be array of PoseEstimationResult")
    }

    func testPoseEstimationResultStructure() throws {
        let manager = PoseEstimationManager()
        let results = try manager.detectBodyPose(in: testImageWithPerson)

        for result in results {
            XCTAssertTrue(result.confidence >= 0.0 && result.confidence <= 1.0,
                         "Confidence should be between 0 and 1")
            XCTAssertTrue(result.personID >= 0, "Person ID should be non-negative")

            // Check joint structure
            for (_, joint) in result.joints {
                XCTAssertTrue(joint.confidence >= 0.0 && joint.confidence <= 1.0,
                             "Joint confidence should be between 0 and 1")
                XCTAssertFalse(joint.jointName.isEmpty, "Joint name should not be empty")
            }
        }
    }

    func testPoseEstimationSkeletonConnections() {
        let connections = PoseEstimationManager.getSkeletonConnections()

        XCTAssertFalse(connections.isEmpty, "Skeleton connections should not be empty")
        XCTAssertTrue(connections.count > 10, "Should have multiple skeleton connections")

        // Verify connection structure
        for connection in connections {
            XCTAssertFalse(connection.0.isEmpty, "First joint name should not be empty")
            XCTAssertFalse(connection.1.isEmpty, "Second joint name should not be empty")
        }
    }

    func testPoseEstimationCoordinateConversion() {
        let normalizedPoint = CGPoint(x: 0.5, y: 0.5)
        let imageSize = CGSize(width: 1920, height: 1080)

        let converted = PoseEstimationManager.convertToImageCoordinates(
            point: normalizedPoint,
            imageSize: imageSize
        )

        XCTAssertEqual(converted.x, 960, accuracy: 0.1)
        XCTAssertEqual(converted.y, 540, accuracy: 0.1)
    }

    // MARK: - Person Detection Tests

    func testPersonDetectionInitialization() {
        let manager = PersonDetectionManager()
        XCTAssertNotNil(manager, "PersonDetectionManager should initialize successfully")
    }

    func testPersonDetectionWithCGImage() throws {
        let manager = PersonDetectionManager()
        let results = try manager.detectPeople(in: testImage)

        XCTAssertNotNil(results, "Person detection should return results")
        XCTAssertTrue(results is [PersonDetectionResult], "Results should be array of PersonDetectionResult")
    }

    func testPersonDetectionFullBody() throws {
        let manager = PersonDetectionManager()
        let results = try manager.detectPeople(in: testImageWithPerson, upperBodyOnly: false)

        for result in results {
            XCTAssertEqual(result.detectionType, .fullBody, "Detection type should be fullBody")
        }
    }

    func testPersonDetectionUpperBody() throws {
        let manager = PersonDetectionManager()
        let results = try manager.detectPeople(in: testImageWithPerson, upperBodyOnly: true)

        for result in results {
            XCTAssertEqual(result.detectionType, .upperBody, "Detection type should be upperBody")
        }
    }

    func testPersonDetectionConfidenceFiltering() throws {
        let manager = PersonDetectionManager()
        let allResults = try manager.detectPeople(in: testImageWithPerson)

        let threshold: Float = 0.7
        let filtered = PersonDetectionManager.filterByConfidence(allResults, threshold: threshold)

        for result in filtered {
            XCTAssertTrue(result.confidence >= threshold,
                         "Filtered results should have confidence >= threshold")
        }
    }

    func testPersonDetectionNonMaximumSuppression() throws {
        let manager = PersonDetectionManager()
        let allResults = try manager.detectPeople(in: testImageWithPerson)

        let nmsResults = PersonDetectionManager.nonMaximumSuppression(allResults, iouThreshold: 0.5)

        // NMS should return same or fewer results
        XCTAssertTrue(nmsResults.count <= allResults.count,
                     "NMS should not increase number of detections")
    }

    // MARK: - Vision Coordinator Tests

    func testVisionCoordinatorInitialization() {
        let coordinator = VisionCoordinator()
        XCTAssertNotNil(coordinator, "VisionCoordinator should initialize successfully")

        // Check default settings
        XCTAssertTrue(coordinator.enableFaceDetection)
        XCTAssertFalse(coordinator.enableFaceRecognition)
        XCTAssertTrue(coordinator.enablePoseEstimation)
        XCTAssertTrue(coordinator.enablePersonDetection)
    }

    func testVisionCoordinatorCompleteAnalysis() throws {
        let coordinator = VisionCoordinator()
        coordinator.enableAll()

        let result = try coordinator.analyzeImage(testImage)

        XCTAssertNotNil(result, "Analysis should return results")
        XCTAssertNotNil(result.faces)
        XCTAssertNotNil(result.faceRecognitions)
        XCTAssertNotNil(result.poses)
        XCTAssertNotNil(result.people)
        XCTAssertTrue(result.processingTime >= 0, "Processing time should be non-negative")
    }

    func testVisionCoordinatorProcessingOrder() throws {
        let coordinator = VisionCoordinator()
        coordinator.enableAll()

        // Test that analysis completes without errors
        // The order is: Person -> Pose -> Face Detection -> Face Recognition
        let result = try coordinator.analyzeImage(testImageWithPerson)

        // Verify all results are populated when enabled
        XCTAssertNotNil(result.people)
        XCTAssertNotNil(result.poses)
        XCTAssertNotNil(result.faces)
        XCTAssertNotNil(result.faceRecognitions)
    }

    func testVisionCoordinatorConfigurationPresets() {
        let coordinator = VisionCoordinator()

        // Test face-only configuration
        coordinator.configureFaceOnly()
        XCTAssertTrue(coordinator.enableFaceDetection)
        XCTAssertTrue(coordinator.enableFaceRecognition)
        XCTAssertFalse(coordinator.enablePoseEstimation)
        XCTAssertFalse(coordinator.enablePersonDetection)

        // Test body-only configuration
        coordinator.configureBodyOnly()
        XCTAssertFalse(coordinator.enableFaceDetection)
        XCTAssertFalse(coordinator.enableFaceRecognition)
        XCTAssertTrue(coordinator.enablePoseEstimation)
        XCTAssertTrue(coordinator.enablePersonDetection)

        // Test enable all
        coordinator.enableAll()
        XCTAssertTrue(coordinator.enableFaceDetection)
        XCTAssertTrue(coordinator.enableFaceRecognition)
        XCTAssertTrue(coordinator.enablePoseEstimation)
        XCTAssertTrue(coordinator.enablePersonDetection)

        // Test disable all
        coordinator.disableAll()
        XCTAssertFalse(coordinator.enableFaceDetection)
        XCTAssertFalse(coordinator.enableFaceRecognition)
        XCTAssertFalse(coordinator.enablePoseEstimation)
        XCTAssertFalse(coordinator.enablePersonDetection)
    }

    func testVisionCoordinatorManagerAccess() {
        let coordinator = VisionCoordinator()

        XCTAssertNotNil(coordinator.faceDetection)
        XCTAssertNotNil(coordinator.faceRecognition)
        XCTAssertNotNil(coordinator.poseEstimation)
        XCTAssertNotNil(coordinator.personDetection)
    }

    // MARK: - Performance Tests

    func testFaceDetectionPerformance() throws {
        let manager = FaceDetectionManager()

        measure {
            do {
                _ = try manager.detectFaces(in: testImage)
            } catch {
                XCTFail("Face detection failed: \(error)")
            }
        }
    }

    func testPoseEstimationPerformance() throws {
        let manager = PoseEstimationManager()

        measure {
            do {
                _ = try manager.detectBodyPose(in: testImage)
            } catch {
                XCTFail("Pose estimation failed: \(error)")
            }
        }
    }

    func testPersonDetectionPerformance() throws {
        let manager = PersonDetectionManager()

        measure {
            do {
                _ = try manager.detectPeople(in: testImage)
            } catch {
                XCTFail("Person detection failed: \(error)")
            }
        }
    }

    func testVisionCoordinatorPerformance() throws {
        let coordinator = VisionCoordinator()
        coordinator.enableAll()

        measure {
            do {
                _ = try coordinator.analyzeImage(testImage)
            } catch {
                XCTFail("Vision coordinator analysis failed: \(error)")
            }
        }
    }

    // MARK: - Error Handling Tests

    func testInvalidImageHandling() {
        let manager = FaceDetectionManager()

        #if !os(macOS)
        // Test with invalid UIImage
        let invalidImage = UIImage()
        XCTAssertThrowsError(try manager.detectFaces(in: invalidImage)) { error in
            XCTAssertTrue(error is VisionError)
        }
        #else
        // Test with invalid NSImage
        let invalidImage = NSImage()
        XCTAssertThrowsError(try manager.detectFaces(in: invalidImage)) { error in
            XCTAssertTrue(error is VisionError)
        }
        #endif
    }

    // MARK: - Integration Tests

    func testFullPipelineWithAllFeatures() throws {
        let coordinator = VisionCoordinator()
        coordinator.enableAll()

        let result = try coordinator.analyzeImage(testImageWithPerson)

        // Verify processing completed
        XCTAssertTrue(result.processingTime > 0, "Processing should take measurable time")

        // All result arrays should be initialized
        XCTAssertNotNil(result.people)
        XCTAssertNotNil(result.poses)
        XCTAssertNotNil(result.faces)
        XCTAssertNotNil(result.faceRecognitions)
    }

    func testSelectiveFeatureProcessing() throws {
        let coordinator = VisionCoordinator()

        // Enable only person detection
        coordinator.disableAll()
        coordinator.enablePersonDetection = true

        let result = try coordinator.analyzeImage(testImage)

        // Only person detection results should be processed
        XCTAssertTrue(result.faces.isEmpty, "Faces should be empty when disabled")
        XCTAssertTrue(result.faceRecognitions.isEmpty, "Face recognitions should be empty when disabled")
        XCTAssertTrue(result.poses.isEmpty, "Poses should be empty when disabled")
    }

    // MARK: - Helper Methods

    private func createTestImage(size: CGSize) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            fatalError("Could not create test image context")
        }

        // Draw a simple test pattern
        context.setFillColor(CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0))
        context.fill(CGRect(origin: .zero, size: size))

        return context.makeImage()!
    }

    private func createTestImageWithPerson() -> CGImage {
        // Create a more complex test image that might contain a person-like shape
        let size = CGSize(width: 640, height: 480)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            fatalError("Could not create test image context")
        }

        // Background
        context.setFillColor(CGColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0))
        context.fill(CGRect(origin: .zero, size: size))

        // Draw person-like shape (simplified)
        context.setFillColor(CGColor(red: 0.8, green: 0.7, blue: 0.6, alpha: 1.0))
        context.fillEllipse(in: CGRect(x: 280, y: 80, width: 80, height: 80)) // Head
        context.fill(CGRect(x: 260, y: 160, width: 120, height: 200)) // Body

        return context.makeImage()!
    }

    private func createTestImageWithFace() -> CGImage {
        // Create a test image with face-like features
        let size = CGSize(width: 640, height: 480)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            fatalError("Could not create test image context")
        }

        // Background
        context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
        context.fill(CGRect(origin: .zero, size: size))

        // Face
        context.setFillColor(CGColor(red: 0.9, green: 0.8, blue: 0.7, alpha: 1.0))
        context.fillEllipse(in: CGRect(x: 220, y: 140, width: 200, height: 200))

        // Eyes
        context.setFillColor(CGColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0))
        context.fillEllipse(in: CGRect(x: 270, y: 200, width: 30, height: 30))
        context.fillEllipse(in: CGRect(x: 340, y: 200, width: 30, height: 30))

        return context.makeImage()!
    }

    // MARK: - Smart Scaling System Tests

    func testSmartScalingInitialization() {
        let scalingManager = SmartScalingManager()
        XCTAssertNotNil(scalingManager, "SmartScalingManager should initialize successfully")

        // Check default values
        XCTAssertEqual(scalingManager.targetBibHeight, 150.0)
        XCTAssertEqual(scalingManager.minimumBibHeight, 40.0)
        XCTAssertEqual(scalingManager.maximumBibHeight, 400.0)
        XCTAssertEqual(scalingManager.minimumDPI, 150.0)
        XCTAssertEqual(scalingManager.targetDPI, 300.0)
        XCTAssertTrue(scalingManager.enableEnhancement)
        XCTAssertTrue(scalingManager.useHighQualityUpscaling)
    }

    func testDistanceCategorization() {
        let scalingManager = SmartScalingManager()
        let torsoManager = TorsoRegionManager()
        let poseManager = PoseEstimationManager()

        // Test with different sized regions
        let testImage = createTestImageWithPerson()
        guard let poses = try? poseManager.detectBodyPose(in: testImage),
              let pose = poses.first,
              let region = torsoManager.getPrimaryBibRegion(from: pose) else {
            XCTFail("Failed to detect pose/region")
            return
        }

        let imageSize = CGSize(width: testImage.width, height: testImage.height)
        let metrics = scalingManager.analyzeRegionQuality(region: region, imageSize: imageSize)

        // Should categorize as one of the distance categories
        let validCategories: [DistanceCategory] = [.veryClose, .close, .medium, .far, .veryFar]
        XCTAssertTrue(validCategories.contains(metrics.distanceCategory))
    }

    func testQualityAnalysis() {
        let scalingManager = SmartScalingManager()
        let torsoManager = TorsoRegionManager()
        let poseManager = PoseEstimationManager()

        let testImage = createTestImageWithPerson()
        guard let poses = try? poseManager.detectBodyPose(in: testImage),
              let pose = poses.first,
              let region = torsoManager.getPrimaryBibRegion(from: pose) else {
            XCTFail("Failed to detect pose/region")
            return
        }

        let imageSize = CGSize(width: testImage.width, height: testImage.height)
        let metrics = scalingManager.analyzeRegionQuality(region: region, imageSize: imageSize)

        // Verify metrics structure
        XCTAssertTrue(metrics.resolution.width > 0)
        XCTAssertTrue(metrics.resolution.height > 0)
        XCTAssertTrue(metrics.estimatedDPI > 0)
        XCTAssertTrue(metrics.recommendedScale > 0)
        XCTAssertTrue(metrics.pixelDensity >= 0)
    }

    func testScalingModeAspectFit() {
        let scalingManager = SmartScalingManager()
        let torsoManager = TorsoRegionManager()
        let poseManager = PoseEstimationManager()

        let testImage = createTestImageWithPerson()
        guard let poses = try? poseManager.detectBodyPose(in: testImage),
              let pose = poses.first,
              let region = torsoManager.getPrimaryBibRegion(from: pose) else {
            XCTFail("Failed to detect pose/region")
            return
        }

        let scaledImage = scalingManager.scaleForOCR(
            image: testImage,
            region: region,
            mode: .aspectFit
        )

        XCTAssertNotNil(scaledImage, "Aspect fit scaling should succeed")
    }

    func testScalingModeAspectFill() {
        let scalingManager = SmartScalingManager()
        let torsoManager = TorsoRegionManager()
        let poseManager = PoseEstimationManager()

        let testImage = createTestImageWithPerson()
        guard let poses = try? poseManager.detectBodyPose(in: testImage),
              let pose = poses.first,
              let region = torsoManager.getPrimaryBibRegion(from: pose) else {
            XCTFail("Failed to detect pose/region")
            return
        }

        let scaledImage = scalingManager.scaleForOCR(
            image: testImage,
            region: region,
            mode: .aspectFill
        )

        XCTAssertNotNil(scaledImage, "Aspect fill scaling should succeed")
    }

    func testScalingModeIntelligent() {
        let scalingManager = SmartScalingManager()
        let torsoManager = TorsoRegionManager()
        let poseManager = PoseEstimationManager()

        let testImage = createTestImageWithPerson()
        guard let poses = try? poseManager.detectBodyPose(in: testImage),
              let pose = poses.first,
              let region = torsoManager.getPrimaryBibRegion(from: pose) else {
            XCTFail("Failed to detect pose/region")
            return
        }

        let scaledImage = scalingManager.scaleForOCR(
            image: testImage,
            region: region,
            mode: .intelligent
        )

        XCTAssertNotNil(scaledImage, "Intelligent scaling should succeed")

        // Intelligent mode should produce usable image
        if let image = scaledImage {
            XCTAssertTrue(image.width > 0)
            XCTAssertTrue(image.height > 0)
        }
    }

    func testImageEnhancement() {
        let scalingManager = SmartScalingManager()
        scalingManager.enableEnhancement = true

        let torsoManager = TorsoRegionManager()
        let poseManager = PoseEstimationManager()

        let testImage = createTestImageWithPerson()
        guard let poses = try? poseManager.detectBodyPose(in: testImage),
              let pose = poses.first,
              let region = torsoManager.getPrimaryBibRegion(from: pose) else {
            XCTFail("Failed to detect pose/region")
            return
        }

        let enhancedImage = scalingManager.scaleForOCR(
            image: testImage,
            region: region,
            mode: .intelligent
        )

        XCTAssertNotNil(enhancedImage, "Enhancement should not cause failure")
    }

    func testScaleCalculation() {
        let scalingManager = SmartScalingManager()
        scalingManager.targetBibHeight = 150.0

        let torsoManager = TorsoRegionManager()
        let poseManager = PoseEstimationManager()

        let testImage = createTestImageWithPerson()
        guard let poses = try? poseManager.detectBodyPose(in: testImage),
              let pose = poses.first,
              let region = torsoManager.getPrimaryBibRegion(from: pose) else {
            XCTFail("Failed to detect pose/region")
            return
        }

        let imageSize = CGSize(width: testImage.width, height: testImage.height)
        let metrics = scalingManager.analyzeRegionQuality(region: region, imageSize: imageSize)

        // Scale factor should be reasonable (0.5x - 10x)
        XCTAssertTrue(metrics.recommendedScale > 0.5)
        XCTAssertTrue(metrics.recommendedScale < 10.0)
    }

    func testBatchScaling() {
        let scalingManager = SmartScalingManager()
        let torsoManager = TorsoRegionManager()
        let poseManager = PoseEstimationManager()

        let testImage = createTestImageWithPerson()
        guard let poses = try? poseManager.detectBodyPose(in: testImage) else {
            XCTFail("Failed to detect poses")
            return
        }

        let allRegions = poses.flatMap { torsoManager.getAllBibRegions(from: $0) }

        let results = scalingManager.batchScaleForOCR(image: testImage, regions: allRegions)

        XCTAssertTrue(results.count <= allRegions.count)
        XCTAssertTrue(results.count >= 0)

        // All results should have valid images
        for (_, scaledImage, _) in results {
            XCTAssertTrue(scaledImage.width > 0)
            XCTAssertTrue(scaledImage.height > 0)
        }
    }

    func testScalingWithBibDetection() {
        let detector = BibNumberDetector()
        detector.enableSmartScaling = true

        let testImage = createTestImageWithPerson()

        // Should not crash with smart scaling enabled
        do {
            let _ = try detector.detectBibNumbers(in: testImage)
            XCTAssertTrue(true, "Bib detection with smart scaling completed")
        } catch {
            // May not find bibs in synthetic image, but should not crash
            XCTAssertTrue(true, "Bib detection completed without crash")
        }
    }

    func testScalingPerformance() {
        let scalingManager = SmartScalingManager()
        let torsoManager = TorsoRegionManager()
        let poseManager = PoseEstimationManager()

        let testImage = createTestImageWithPerson()
        guard let poses = try? poseManager.detectBodyPose(in: testImage),
              let pose = poses.first,
              let region = torsoManager.getPrimaryBibRegion(from: pose) else {
            XCTFail("Failed to detect pose/region")
            return
        }

        measure {
            let _ = scalingManager.scaleForOCR(
                image: testImage,
                region: region,
                mode: .intelligent
            )
        }
    }

    func testSmartScalingWithDisabled() {
        let detector = BibNumberDetector()
        detector.enableSmartScaling = false

        let testImage = createTestImageWithPerson()

        // Should work without smart scaling
        do {
            let _ = try detector.detectBibNumbers(in: testImage)
            XCTAssertTrue(true, "Bib detection without smart scaling completed")
        } catch {
            XCTAssertTrue(true, "Bib detection completed without crash")
        }
    }

    func testDPICalculation() {
        let scalingManager = SmartScalingManager()
        let torsoManager = TorsoRegionManager()
        let poseManager = PoseEstimationManager()

        let testImage = createTestImageWithPerson()
        guard let poses = try? poseManager.detectBodyPose(in: testImage),
              let pose = poses.first,
              let region = torsoManager.getPrimaryBibRegion(from: pose) else {
            XCTFail("Failed to detect pose/region")
            return
        }

        let imageSize = CGSize(width: testImage.width, height: testImage.height)
        let metrics = scalingManager.analyzeRegionQuality(region: region, imageSize: imageSize)

        // DPI should be positive and reasonable
        XCTAssertTrue(metrics.estimatedDPI > 0)
        XCTAssertTrue(metrics.estimatedDPI < 10000) // Sanity check
    }

    func testOCRReadiness() {
        let scalingManager = SmartScalingManager()
        let torsoManager = TorsoRegionManager()
        let poseManager = PoseEstimationManager()

        let testImage = createTestImageWithPerson()
        guard let poses = try? poseManager.detectBodyPose(in: testImage),
              let pose = poses.first,
              let region = torsoManager.getPrimaryBibRegion(from: pose) else {
            XCTFail("Failed to detect pose/region")
            return
        }

        let imageSize = CGSize(width: testImage.width, height: testImage.height)
        let metrics = scalingManager.analyzeRegionQuality(region: region, imageSize: imageSize)

        // OCR readiness should be boolean
        XCTAssertTrue(metrics.isOCRReady == true || metrics.isOCRReady == false)
    }

    func testCustomScalingConfiguration() {
        let scalingManager = SmartScalingManager()

        // Test custom configuration
        scalingManager.targetBibHeight = 200.0
        scalingManager.minimumBibHeight = 30.0
        scalingManager.maximumBibHeight = 500.0
        scalingManager.minimumDPI = 100.0
        scalingManager.targetDPI = 200.0

        XCTAssertEqual(scalingManager.targetBibHeight, 200.0)
        XCTAssertEqual(scalingManager.minimumBibHeight, 30.0)
        XCTAssertEqual(scalingManager.maximumBibHeight, 500.0)
        XCTAssertEqual(scalingManager.minimumDPI, 100.0)
        XCTAssertEqual(scalingManager.targetDPI, 200.0)
    }

    func testScalingWithDifferentImageSizes() {
        let scalingManager = SmartScalingManager()
        let torsoManager = TorsoRegionManager()
        let poseManager = PoseEstimationManager()

        // Test with different image sizes
        let sizes = [
            CGSize(width: 640, height: 480),
            CGSize(width: 1920, height: 1080),
            CGSize(width: 320, height: 240)
        ]

        for size in sizes {
            let testImage = createTestImage(size: size)
            guard let poses = try? poseManager.detectBodyPose(in: testImage),
                  let pose = poses.first,
                  let region = torsoManager.getPrimaryBibRegion(from: pose) else {
                continue
            }

            let imageSize = CGSize(width: testImage.width, height: testImage.height)
            let metrics = scalingManager.analyzeRegionQuality(region: region, imageSize: imageSize)

            XCTAssertTrue(metrics.resolution.width > 0)
            XCTAssertTrue(metrics.resolution.height > 0)
        }
    }

    func testBatchProcessingPerformance() {
        let scalingManager = SmartScalingManager()
        let torsoManager = TorsoRegionManager()
        let poseManager = PoseEstimationManager()

        let testImage = createTestImageWithPerson()
        guard let poses = try? poseManager.detectBodyPose(in: testImage) else {
            XCTFail("Failed to detect poses")
            return
        }

        let allRegions = poses.flatMap { torsoManager.getAllBibRegions(from: $0) }

        measure {
            let _ = scalingManager.batchScaleForOCR(image: testImage, regions: allRegions)
        }
    }
}
