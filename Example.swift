//
//  Example.swift
//  Apple Vision Framework - Usage Examples
//
//  Demonstrates how to use all Vision framework features
//  Processing order: Person Detection -> Pose Estimation -> Face Detection/Recognition
//

import Vision
import CoreImage
import CoreGraphics
import Foundation

#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

/// Example usage of all Vision framework features
class VisionExamples {

    // MARK: - Example 1: Complete Analysis with Ordered Processing

    /// Process image with specified order: Person -> Pose -> Face
    /// - Parameter image: The image to analyze
    func completeAnalysisOrdered(image: CGImage) {
        print("=== Complete Vision Analysis (Ordered Processing) ===\n")

        let startTime = Date()

        // Step 1: Person Detection (First)
        print("Step 1: Detecting People...")
        let personManager = PersonDetectionManager()
        if let people = try? personManager.detectPeople(in: image) {
            print("  ✓ Found \(people.count) people")
            for (index, person) in people.enumerated() {
                print("    Person \(index): confidence=\(person.confidence), type=\(person.detectionType)")
            }
        }
        print()

        // Step 2: Pose Estimation (Second)
        print("Step 2: Estimating Poses...")
        let poseManager = PoseEstimationManager()
        if let poses = try? poseManager.detectBodyPose(in: image) {
            print("  ✓ Found \(poses.count) poses")
            for (index, pose) in poses.enumerated() {
                print("    Pose \(index): \(pose.joints.count) joints detected")
                // Print some key joints
                if let nose = pose.joints["nose"] {
                    print("      - Nose: confidence=\(nose.confidence)")
                }
                if let leftWrist = pose.joints["left_wrist"] {
                    print("      - Left Wrist: confidence=\(leftWrist.confidence)")
                }
            }
        }
        print()

        // Step 3: Face Detection (Third)
        print("Step 3: Detecting Faces...")
        let faceManager = FaceDetectionManager()
        if let faces = try? faceManager.detectFaces(in: image) {
            print("  ✓ Found \(faces.count) faces")
            for (index, face) in faces.enumerated() {
                print("    Face \(index): confidence=\(face.confidence)")
                if let yaw = face.yaw, let pitch = face.pitch {
                    print("      Angles - yaw:\(String(format: "%.2f", yaw))°, pitch:\(String(format: "%.2f", pitch))°")
                }
            }
        }
        print()

        // Step 4: Face Recognition (Last)
        print("Step 4: Recognizing Face Landmarks...")
        let recognitionManager = FaceRecognitionManager()
        if let recognitions = try? recognitionManager.recognizeFaces(in: image) {
            print("  ✓ Analyzed \(recognitions.count) faces")
            for (index, recognition) in recognitions.enumerated() {
                print("    Face \(index):")
                if let landmarks = recognition.landmarks {
                    var landmarkCount = 0
                    if landmarks.faceContour != nil { landmarkCount += 1 }
                    if landmarks.leftEye != nil { landmarkCount += 1 }
                    if landmarks.rightEye != nil { landmarkCount += 1 }
                    if landmarks.nose != nil { landmarkCount += 1 }
                    if landmarks.outerLips != nil { landmarkCount += 1 }
                    print("      Landmark regions detected: \(landmarkCount)")
                }
                if let quality = recognition.captureQuality {
                    print("      Capture quality: \(String(format: "%.2f", quality))")
                }
            }
        }

        let totalTime = Date().timeIntervalSince(startTime)
        print("\nTotal Processing Time: \(String(format: "%.3f", totalTime))s")
        print("================================================\n")
    }

    // MARK: - Example 2: Person Detection Only

    func personDetectionExample(image: CGImage) {
        print("=== Person Detection Example ===\n")

        let manager = PersonDetectionManager()

        do {
            // Full body detection
            let fullBodyResults = try manager.detectPeople(in: image, upperBodyOnly: false)
            print("Full Body Detection: \(fullBodyResults.count) people found")

            // Upper body detection
            let upperBodyResults = try manager.detectPeople(in: image, upperBodyOnly: true)
            print("Upper Body Detection: \(upperBodyResults.count) people found")

            // Apply confidence filtering
            let filtered = PersonDetectionManager.filterByConfidence(fullBodyResults, threshold: 0.7)
            print("High Confidence (>0.7): \(filtered.count) people")

            // Apply non-maximum suppression
            let nms = PersonDetectionManager.nonMaximumSuppression(fullBodyResults)
            print("After NMS: \(nms.count) people")

        } catch {
            print("Error: \(error.localizedDescription)")
        }

        print("================================\n")
    }

    // MARK: - Example 3: Pose Estimation Only

    func poseEstimationExample(image: CGImage) {
        print("=== Pose Estimation Example ===\n")

        let manager = PoseEstimationManager()

        do {
            let poses = try manager.detectBodyPose(in: image)
            print("Detected \(poses.count) poses\n")

            for (index, pose) in poses.enumerated() {
                print("Person \(index):")
                print("  Joints detected: \(pose.joints.count)")
                print("  Confidence: \(pose.confidence)")

                // Print specific joints
                print("  Key joints:")
                for (name, joint) in pose.joints.sorted(by: { $0.key < $1.key }) {
                    print("    \(name): position(\(joint.position.x), \(joint.position.y)), confidence=\(joint.confidence)")
                }

                // Get skeleton connections for drawing
                let connections = PoseEstimationManager.getSkeletonConnections()
                print("  \(connections.count) skeleton connections available for drawing")
            }

        } catch {
            print("Error: \(error.localizedDescription)")
        }

        print("===============================\n")
    }

    // MARK: - Example 4: Face Detection Only

    func faceDetectionExample(image: CGImage) {
        print("=== Face Detection Example ===\n")

        let manager = FaceDetectionManager()

        do {
            let faces = try manager.detectFaces(in: image)
            print("Detected \(faces.count) faces\n")

            let imageSize = CGSize(width: image.width, height: image.height)

            for (index, face) in faces.enumerated() {
                print("Face \(index):")
                print("  Confidence: \(face.confidence)")

                // Convert to image coordinates
                let bbox = FaceDetectionManager.convertToImageCoordinates(
                    boundingBox: face.boundingBox,
                    imageSize: imageSize
                )
                print("  Bounding Box: x=\(Int(bbox.origin.x)), y=\(Int(bbox.origin.y)), w=\(Int(bbox.width)), h=\(Int(bbox.height))")

                if let yaw = face.yaw, let pitch = face.pitch, let roll = face.roll {
                    print("  Head Pose:")
                    print("    Yaw: \(String(format: "%.2f", yaw))°")
                    print("    Pitch: \(String(format: "%.2f", pitch))°")
                    print("    Roll: \(String(format: "%.2f", roll))°")
                }
            }

        } catch {
            print("Error: \(error.localizedDescription)")
        }

        print("==============================\n")
    }

    // MARK: - Example 5: Face Recognition with Landmarks

    func faceRecognitionExample(image: CGImage) {
        print("=== Face Recognition Example ===\n")

        let manager = FaceRecognitionManager()

        do {
            let results = try manager.recognizeFaces(in: image)
            print("Recognized \(results.count) faces\n")

            for (index, result) in results.enumerated() {
                print("Face \(index):")
                print("  Confidence: \(result.confidence)")

                if let quality = result.captureQuality {
                    print("  Capture Quality: \(String(format: "%.3f", quality))")
                }

                if let landmarks = result.landmarks {
                    print("  Facial Landmarks:")
                    if let faceContour = landmarks.faceContour {
                        print("    - Face Contour: \(faceContour.count) points")
                    }
                    if let leftEye = landmarks.leftEye {
                        print("    - Left Eye: \(leftEye.count) points")
                    }
                    if let rightEye = landmarks.rightEye {
                        print("    - Right Eye: \(rightEye.count) points")
                    }
                    if let nose = landmarks.nose {
                        print("    - Nose: \(nose.count) points")
                    }
                    if let outerLips = landmarks.outerLips {
                        print("    - Outer Lips: \(outerLips.count) points")
                    }
                    if let innerLips = landmarks.innerLips {
                        print("    - Inner Lips: \(innerLips.count) points")
                    }
                }
            }

        } catch {
            print("Error: \(error.localizedDescription)")
        }

        print("================================\n")
    }

    // MARK: - Example 6: Using the Coordinator

    func coordinatorExample(image: CGImage) {
        print("=== Vision Coordinator Example ===\n")

        let coordinator = VisionCoordinator()

        // Enable all features
        coordinator.enableAll()

        do {
            let result = try coordinator.analyzeImage(image)
            coordinator.printSummary(result)

        } catch {
            print("Error: \(error.localizedDescription)")
        }

        print("==================================\n")
    }

    // MARK: - Example 7: Real-time Video Processing

    func videoProcessingExample(pixelBuffer: CVPixelBuffer) {
        print("=== Video Frame Processing Example ===\n")

        // Use coordinator for efficient video processing
        let coordinator = VisionCoordinator()

        // Configure for performance (disable expensive operations)
        coordinator.enableFaceDetection = true
        coordinator.enableFaceRecognition = false  // Disable for better performance
        coordinator.enablePoseEstimation = true
        coordinator.enablePersonDetection = true

        do {
            let result = try coordinator.analyzeVideoFrame(pixelBuffer)
            print("Frame processed in \(String(format: "%.3f", result.processingTime))s")
            print("  People: \(result.people.count)")
            print("  Poses: \(result.poses.count)")
            print("  Faces: \(result.faces.count)")

        } catch {
            print("Error: \(error.localizedDescription)")
        }

        print("======================================\n")
    }

    // MARK: - Example 8: Complete Pipeline Demo

    #if !os(macOS)
    func runCompletePipeline(image: UIImage) {
        guard let cgImage = image.cgImage else {
            print("Invalid image")
            return
        }
        runCompletePipeline(cgImage: cgImage)
    }
    #else
    func runCompletePipeline(image: NSImage) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("Invalid image")
            return
        }
        runCompletePipeline(cgImage: cgImage)
    }
    #endif

    private func runCompletePipeline(cgImage: CGImage) {
        print("\n")
        print("╔════════════════════════════════════════════════╗")
        print("║   Apple Vision Framework - Complete Pipeline  ║")
        print("╚════════════════════════════════════════════════╝")
        print()

        // Run ordered analysis
        completeAnalysisOrdered(image: cgImage)

        // Run individual examples
        personDetectionExample(image: cgImage)
        poseEstimationExample(image: cgImage)
        faceDetectionExample(image: cgImage)
        faceRecognitionExample(image: cgImage)
        coordinatorExample(image: cgImage)
    }
}

// MARK: - Usage Instructions

/*
 To use these examples in your iOS/macOS app:

 1. Import the necessary frameworks:
    import Vision
    import CoreImage
    import CoreGraphics
    import UIKit // or AppKit for macOS

 2. Create an instance and run examples:
    let examples = VisionExamples()

    // Load your image
    if let image = UIImage(named: "test.jpg")?.cgImage {
        // Run complete ordered analysis
        examples.completeAnalysisOrdered(image: image)

        // Or run specific examples
        examples.personDetectionExample(image: image)
        examples.poseEstimationExample(image: image)
        examples.faceDetectionExample(image: image)
        examples.faceRecognitionExample(image: image)
    }

 3. For video processing:
    // In your AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput,
                      didOutput sampleBuffer: CMSampleBuffer,
                      from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        examples.videoProcessingExample(pixelBuffer: pixelBuffer)
    }

 Processing Order:
 1. Person Detection - Detect all people in the image first
 2. Pose Estimation - Estimate poses for detected people
 3. Face Detection - Detect faces in the image
 4. Face Recognition - Extract facial landmarks and features

 Performance Tips:
 - Disable face recognition for real-time video (it's slower)
 - Use appropriate confidence thresholds
 - Apply non-maximum suppression for person detection
 - Process frames on a background queue
 - Consider reducing image resolution for video
*/
