//
//  VisualizationExamples.swift
//  Apple Vision Framework - Visualization Usage Examples
//
//  Examples showing how to visualize detection results
//

import CoreGraphics
import Foundation

#if os(macOS)
import AppKit
#else
import UIKit
#endif

class VisualizationExamples {

    // MARK: - Example 1: Complete Visualization

    /// Example: Draw everything (person boxes, pose, torso regions, bib numbers)
    func completeVisualizationExample(image: CGImage) {
        print("=== Complete Visualization Example ===\n")

        // Step 1: Run all detections
        let personManager = PersonDetectionManager()
        let poseManager = PoseEstimationManager()
        let torsoManager = TorsoRegionManager()
        let bibDetector = BibNumberDetector()

        guard let people = try? personManager.detectPeople(in: image),
              let poses = try? poseManager.detectBodyPose(in: image) else {
            print("Detection failed")
            return
        }

        let torsoRegions = torsoManager.extractTorsoRegions(from: poses)
        let bibResults = try? bibDetector.detectBibNumbers(in: image)

        print("Detected:")
        print("  - \(people.count) people")
        print("  - \(poses.count) poses")
        print("  - \(torsoRegions.count) torso regions")
        print("  - \(bibResults?.count ?? 0) bib numbers")
        print()

        // Step 2: Create visualization
        let visualizer = ComprehensiveVisualizationManager()

        let annotatedImage = visualizer.drawCompleteVisualization(
            on: image,
            people: people,
            poses: poses,
            torsoRegions: torsoRegions,
            bibResults: bibResults
        )

        if let result = annotatedImage {
            print("✓ Complete visualization created")
            print("  Size: \(result.width)x\(result.height)")
            // Save or display result here
        } else {
            print("✗ Visualization failed")
        }

        print("\n======================================\n")
    }

    // MARK: - Example 2: Person Bounding Boxes Only

    /// Example: Draw only person detection boxes
    func personBoundingBoxesExample(image: CGImage) {
        print("=== Person Bounding Boxes Example ===\n")

        let personManager = PersonDetectionManager()

        guard let people = try? personManager.detectPeople(in: image) else {
            print("Person detection failed")
            return
        }

        print("Detected \(people.count) people")

        let visualizer = ComprehensiveVisualizationManager()

        // Customize style
        visualizer.style.personBoxColor = CGColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
        visualizer.style.personBoxLineWidth = 4.0
        visualizer.style.showPersonLabels = true

        let annotatedImage = visualizer.drawPersonBoundingBoxes(
            on: image,
            people: people
        )

        if annotatedImage != nil {
            print("✓ Person bounding boxes drawn")
        }

        print("\n=====================================\n")
    }

    // MARK: - Example 3: Pose Skeleton Only

    /// Example: Draw only pose estimation skeleton
    func poseSkeletonExample(image: CGImage) {
        print("=== Pose Skeleton Example ===\n")

        let poseManager = PoseEstimationManager()

        guard let poses = try? poseManager.detectBodyPose(in: image) else {
            print("Pose detection failed")
            return
        }

        print("Detected \(poses.count) poses")

        for (index, pose) in poses.enumerated() {
            print("  Pose \(index): \(pose.joints.count) joints")
        }

        let visualizer = ComprehensiveVisualizationManager()

        // Customize pose style
        visualizer.style.jointColor = CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        visualizer.style.jointRadius = 10.0
        visualizer.style.boneColor = CGColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0)
        visualizer.style.boneLineWidth = 5.0
        visualizer.style.showJointLabels = false // Set to true to show joint names

        let annotatedImage = visualizer.drawPoseSkeletons(
            on: image,
            poses: poses
        )

        if annotatedImage != nil {
            print("✓ Pose skeletons drawn")
        }

        print("\n=============================\n")
    }

    // MARK: - Example 4: Torso Regions Only

    /// Example: Draw only torso region detection zones
    func torsoRegionsExample(image: CGImage) {
        print("=== Torso Regions Example ===\n")

        let poseManager = PoseEstimationManager()
        let torsoManager = TorsoRegionManager()

        guard let poses = try? poseManager.detectBodyPose(in: image) else {
            print("Pose detection failed")
            return
        }

        let torsoRegions = torsoManager.extractTorsoRegions(from: poses)

        print("Detected \(torsoRegions.count) torso regions")

        for region in torsoRegions {
            print("  - \(region.zone.rawValue): confidence \(region.confidence)")
        }

        let visualizer = ComprehensiveVisualizationManager()

        // Customize torso style
        visualizer.style.torsoBoxColor = CGColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.7)
        visualizer.style.torsoBoxLineWidth = 3.0
        visualizer.style.showTorsoLabels = true

        let annotatedImage = visualizer.drawTorsoRegions(
            on: image,
            regions: torsoRegions
        )

        if annotatedImage != nil {
            print("✓ Torso regions drawn")
        }

        print("\n=============================\n")
    }

    // MARK: - Example 5: Custom Text Style

    /// Example: Customize text rendering for readability
    func customTextStyleExample(image: CGImage) {
        print("=== Custom Text Style Example ===\n")

        let personManager = PersonDetectionManager()

        guard let people = try? personManager.detectPeople(in: image) else {
            return
        }

        let visualizer = ComprehensiveVisualizationManager()

        // High-contrast readable text style
        visualizer.style.fontSize = 20.0
        visualizer.style.fontWeight = .bold
        visualizer.style.textBackgroundColor = CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.8)
        visualizer.style.textOutlineWidth = 4.0
        visualizer.style.drawFilledBackground = true
        visualizer.style.backgroundPadding = 6.0

        let annotatedImage = visualizer.drawPersonBoundingBoxes(
            on: image,
            people: people
        )

        if annotatedImage != nil {
            print("✓ Custom text style applied")
            print("  Font size: 20pt")
            print("  Background: Semi-transparent black")
            print("  Outline: 4px for readability")
        }

        print("\n=================================\n")
    }

    // MARK: - Example 6: Layered Visualization

    /// Example: Build visualization in layers
    func layeredVisualizationExample(image: CGImage) {
        print("=== Layered Visualization Example ===\n")

        // Run all detections
        let personManager = PersonDetectionManager()
        let poseManager = PoseEstimationManager()
        let torsoManager = TorsoRegionManager()

        guard let people = try? personManager.detectPeople(in: image),
              let poses = try? poseManager.detectBodyPose(in: image) else {
            return
        }

        let torsoRegions = torsoManager.extractTorsoRegions(from: poses)

        let visualizer = ComprehensiveVisualizationManager()

        // Layer 1: Start with person boxes (green)
        print("Layer 1: Drawing person bounding boxes...")
        visualizer.style.personBoxColor = CGColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 0.5)
        var currentImage = visualizer.drawPersonBoundingBoxes(on: image, people: people) ?? image

        // Layer 2: Add torso regions (orange, dashed)
        print("Layer 2: Adding torso regions...")
        visualizer.style.torsoBoxColor = CGColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.6)
        currentImage = visualizer.drawTorsoRegions(on: currentImage, regions: torsoRegions) ?? currentImage

        // Layer 3: Add pose skeleton on top (blue bones, red joints)
        print("Layer 3: Adding pose skeletons...")
        visualizer.style.boneColor = CGColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 0.8)
        visualizer.style.jointColor = CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        currentImage = visualizer.drawPoseSkeletons(on: currentImage, poses: poses) ?? currentImage

        print("✓ Layered visualization complete")

        print("\n=====================================\n")
    }

    // MARK: - Example 7: Bib Number Highlighting

    /// Example: Highlight detected bib numbers
    func bibNumberHighlightingExample(image: CGImage) {
        print("=== Bib Number Highlighting Example ===\n")

        let bibDetector = BibNumberDetector()

        guard let bibResults = try? bibDetector.detectBibNumbers(in: image) else {
            print("Bib detection failed")
            return
        }

        print("Detected \(bibResults.count) bib numbers:")
        for bib in bibResults {
            print("  - Person \(bib.personID): Bib #\(bib.number) (confidence: \(bib.confidence))")
        }

        // Get required data for visualization
        let poseManager = PoseEstimationManager()
        let personManager = PersonDetectionManager()
        let torsoManager = TorsoRegionManager()

        guard let poses = try? poseManager.detectBodyPose(in: image),
              let people = try? personManager.detectPeople(in: image) else {
            return
        }

        let torsoRegions = torsoManager.extractTorsoRegions(from: poses)

        let visualizer = ComprehensiveVisualizationManager()

        // Bright highlighting for bib numbers
        visualizer.style.showPersonLabels = false // Hide person labels
        visualizer.style.showTorsoLabels = false  // Hide torso labels

        let annotatedImage = visualizer.drawCompleteVisualization(
            on: image,
            people: people,
            poses: poses,
            torsoRegions: torsoRegions,
            bibResults: bibResults
        )

        if annotatedImage != nil {
            print("✓ Bib numbers highlighted")
        }

        print("\n=======================================\n")
    }

    // MARK: - Example 8: Real-time Video Annotation

    /// Example: Optimized visualization for real-time video
    func realtimeVideoAnnotationExample(pixelBuffer: CVPixelBuffer) {
        print("=== Real-time Video Annotation ===\n")

        // Convert pixel buffer to CGImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            print("Failed to convert pixel buffer")
            return
        }

        // Fast detection (minimal zones, no bib OCR)
        let personManager = PersonDetectionManager()
        let poseManager = PoseEstimationManager()

        guard let people = try? personManager.detectPeople(in: cgImage),
              let poses = try? poseManager.detectBodyPose(in: cgImage) else {
            return
        }

        let visualizer = ComprehensiveVisualizationManager()

        // Minimal visualization for speed
        visualizer.style.showPersonLabels = true
        visualizer.style.showJointLabels = false
        visualizer.style.showTorsoLabels = false

        // Only draw person boxes and poses (skip torso regions for speed)
        let annotatedImage = visualizer.drawCompleteVisualization(
            on: cgImage,
            people: people,
            poses: poses,
            torsoRegions: [], // Empty for speed
            bibResults: nil
        )

        if annotatedImage != nil {
            print("✓ Frame annotated")
            print("  People: \(people.count)")
            print("  Poses: \(poses.count)")
        }

        print("\n==================================\n")
    }

    // MARK: - Example 9: Side-by-Side Comparison

    /// Example: Create side-by-side comparison images
    func sideBySideComparisonExample(image: CGImage) {
        print("=== Side-by-Side Comparison ===\n")

        let poseManager = PoseEstimationManager()
        let personManager = PersonDetectionManager()
        let torsoManager = TorsoRegionManager()

        guard let poses = try? poseManager.detectBodyPose(in: image),
              let people = try? personManager.detectPeople(in: image) else {
            return
        }

        let torsoRegions = torsoManager.extractTorsoRegions(from: poses)

        let visualizer = ComprehensiveVisualizationManager()

        // Create different versions
        print("Creating visualization variants...")

        // Version 1: Person boxes only
        let version1 = visualizer.drawPersonBoundingBoxes(on: image, people: people)

        // Version 2: Pose skeleton only
        let version2 = visualizer.drawPoseSkeletons(on: image, poses: poses)

        // Version 3: Torso regions only
        let version3 = visualizer.drawTorsoRegions(on: image, regions: torsoRegions)

        // Version 4: Complete
        let version4 = visualizer.drawCompleteVisualization(
            on: image,
            people: people,
            poses: poses,
            torsoRegions: torsoRegions
        )

        print("✓ Created 4 visualization variants")
        print("  1. Person boxes")
        print("  2. Pose skeletons")
        print("  3. Torso regions")
        print("  4. Complete (all layers)")

        print("\n===============================\n")
    }
}

// MARK: - Usage Guide

/*
 VISUALIZATION USAGE GUIDE
 =========================

 1. BASIC COMPLETE VISUALIZATION:
 --------------------------------
 let visualizer = ComprehensiveVisualizationManager()
 let annotated = visualizer.drawCompleteVisualization(
     on: image,
     people: people,
     poses: poses,
     torsoRegions: torsoRegions,
     bibResults: bibResults
 )

 2. INDIVIDUAL VISUALIZATIONS:
 -----------------------------
 // Person boxes only
 visualizer.drawPersonBoundingBoxes(on: image, people: people)

 // Pose skeletons only
 visualizer.drawPoseSkeletons(on: image, poses: poses)

 // Torso regions only
 visualizer.drawTorsoRegions(on: image, regions: torsoRegions)

 3. CUSTOMIZING STYLE:
 --------------------
 visualizer.style.personBoxColor = CGColor(red: 0, green: 1, blue: 0, alpha: 1)
 visualizer.style.personBoxLineWidth = 4.0
 visualizer.style.showPersonLabels = true

 visualizer.style.jointColor = CGColor(red: 1, green: 0, blue: 0, alpha: 1)
 visualizer.style.jointRadius = 10.0
 visualizer.style.boneColor = CGColor(red: 0, green: 0.5, blue: 1, alpha: 1)
 visualizer.style.boneLineWidth = 5.0

 visualizer.style.fontSize = 18.0
 visualizer.style.fontWeight = .bold
 visualizer.style.textBackgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0.7)

 4. TEXT READABILITY OPTIONS:
 ---------------------------
 visualizer.style.drawFilledBackground = true      // Background box behind text
 visualizer.style.backgroundPadding = 6.0          // Padding around text
 visualizer.style.textOutlineWidth = 4.0           // Outline for contrast
 visualizer.style.fontSize = 20.0                  // Larger text

 5. LAYER CONTROL:
 ----------------
 visualizer.style.showPersonLabels = true/false
 visualizer.style.showJointLabels = true/false
 visualizer.style.showTorsoLabels = true/false

 6. VISUALIZATION LAYERS (bottom to top):
 ----------------------------------------
 Layer 1: Person bounding boxes (background)
 Layer 2: Torso regions (middle)
 Layer 3: Pose skeletons (bones + joints)
 Layer 4: Bib numbers (top, highlighted)

 7. COLOR SCHEME:
 ---------------
 Person boxes:  Green (0, 1, 0)
 Pose bones:    Blue (0, 0.5, 1)
 Pose joints:   Red (1, 0, 0)
 Torso regions: Orange (1, 0.5, 0)
 Bib numbers:   Bright green (0, 1, 0)

 8. PERFORMANCE TIPS:
 -------------------
 • For real-time video: Disable labels, reduce line widths
 • For high-quality images: Increase font size, enable all labels
 • For debugging: Enable joint labels to see joint names
 • For presentations: Use high contrast colors and thick lines

 9. SAVE/DISPLAY OUTPUT:
 ----------------------
 #if os(macOS)
 let nsImage = NSImage(cgImage: annotatedImage, size: .zero)
 // Display or save nsImage
 #else
 let uiImage = UIImage(cgImage: annotatedImage)
 // Display or save uiImage
 #endif
*/
