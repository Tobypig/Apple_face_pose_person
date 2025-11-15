//
//  BibNumberDetectionExample.swift
//  Apple Vision Framework - Bib Number Detection Example
//
//  Complete example for detecting and reading race bib numbers
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

// MARK: - Bib Number Result

struct BibNumberResult {
    let number: String              // Detected bib number
    let confidence: Float           // OCR confidence
    let region: BibDetectionRegion  // Where it was found
    let personID: Int               // Associated person
}

// MARK: - Bib Number Detector

class BibNumberDetector {

    // MARK: - Properties

    private let poseManager: PoseEstimationManager
    private let torsoManager: TorsoRegionManager
    private let scalingManager: SmartScalingManager

    // Configuration
    var minTextConfidence: Float = 0.5
    var preferredZones: [TorsoZone] = [.upperChest, .midTorso, .lowerTorso]
    var enableSmartScaling: Bool = true  // NEW: Enable smart scaling for better OCR

    // MARK: - Initialization

    init() {
        self.poseManager = PoseEstimationManager()
        self.torsoManager = TorsoRegionManager()
        self.scalingManager = SmartScalingManager()  // NEW: Smart scaling support
    }

    // MARK: - Detection Methods

    /// Detect bib numbers in an image
    /// - Parameter image: The image to analyze
    /// - Returns: Array of detected bib numbers with metadata
    func detectBibNumbers(in image: CGImage) throws -> [BibNumberResult] {
        // Step 1: Detect people and poses
        print("Step 1: Detecting poses...")
        let poses = try poseManager.detectBodyPose(in: image)
        print("  Found \(poses.count) people")

        guard !poses.isEmpty else {
            return []
        }

        var results: [BibNumberResult] = []

        // Step 2: For each person, extract torso regions and search for numbers
        for pose in poses {
            print("\nStep 2: Processing person \(pose.personID)...")

            // Get all possible bib regions (ordered by likelihood)
            let bibRegions = torsoManager.getAllBibRegions(from: pose)
            print("  Found \(bibRegions.count) potential bib regions")

            // Step 3: Try each region until we find a number
            for region in bibRegions {
                print("  Searching in \(region.zone) region...")

                // NEW: Apply smart scaling for better OCR
                let processedImage: CGImage?
                if enableSmartScaling {
                    processedImage = scalingManager.scaleForOCR(image: image, region: region)
                    if processedImage != nil {
                        let imageSize = CGSize(width: image.width, height: image.height)
                        let metrics = scalingManager.analyzeRegionQuality(region: region, imageSize: imageSize)
                        print("    Scaled \(String(format: "%.1fx", metrics.recommendedScale)) (\(metrics.distanceCategory))")
                    }
                } else {
                    processedImage = TorsoRegionManager.cropToBibRegion(image: image, region: region)
                }

                if let finalImage = processedImage {
                    // Step 4: Perform OCR on the scaled/cropped region
                    if let detectedNumbers = try? recognizeNumbers(in: finalImage) {
                        for (number, confidence) in detectedNumbers {
                            print("    ✓ Found number: \(number) (confidence: \(confidence))")

                            results.append(BibNumberResult(
                                number: number,
                                confidence: confidence,
                                region: region,
                                personID: pose.personID
                            ))
                        }

                        // If we found a number in this region, stop searching other regions
                        if !detectedNumbers.isEmpty {
                            break
                        }
                    }
                }
            }
        }

        return results
    }

    /// Fast bib detection - only checks primary region (upper chest)
    /// - Parameter image: The image to analyze
    /// - Returns: Array of detected bib numbers
    func detectBibNumbersFast(in image: CGImage) throws -> [BibNumberResult] {
        let poses = try poseManager.detectBodyPose(in: image)
        var results: [BibNumberResult] = []

        for pose in poses {
            // Only check primary bib region
            if let region = torsoManager.getPrimaryBibRegion(from: pose) {
                // NEW: Apply smart scaling for better OCR
                let processedImage: CGImage?
                if enableSmartScaling {
                    processedImage = scalingManager.scaleForOCR(image: image, region: region)
                } else {
                    processedImage = TorsoRegionManager.cropToBibRegion(image: image, region: region)
                }

                if let finalImage = processedImage,
                   let detectedNumbers = try? recognizeNumbers(in: finalImage) {

                    for (number, confidence) in detectedNumbers {
                        results.append(BibNumberResult(
                            number: number,
                            confidence: confidence,
                            region: region,
                            personID: pose.personID
                        ))
                    }
                }
            }
        }

        return results
    }

    // MARK: - OCR Processing

    /// Recognize numbers in a cropped bib region using Vision OCR
    /// - Parameter image: Cropped torso region image
    /// - Returns: Array of (number, confidence) tuples
    private func recognizeNumbers(in image: CGImage) throws -> [(String, Float)] {
        let request = VNRecognizeTextRequest()

        // Configure for optimal number recognition
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false  // Better for numbers
        request.minimumTextHeight = 0.05       // Detect smaller text

        // Custom words to improve number recognition (optional)
        request.customWords = (0...9999).map { String($0) }

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            return []
        }

        var numbers: [(String, Float)] = []

        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first,
                  topCandidate.confidence >= minTextConfidence else {
                continue
            }

            let text = topCandidate.string

            // Filter for numbers only (bib numbers are typically numeric)
            if let extractedNumber = extractNumber(from: text) {
                numbers.append((extractedNumber, topCandidate.confidence))
            }
        }

        return numbers
    }

    /// Extract numeric digits from text
    /// - Parameter text: Raw OCR text
    /// - Returns: Extracted number string (digits only)
    private func extractNumber(from text: String) -> String? {
        let digits = text.filter { $0.isNumber }
        return digits.isEmpty ? nil : digits
    }

    // MARK: - Multi-Strategy Detection

    /// Try multiple strategies to detect bib number
    /// Strategy 1: Fast detection (upper chest only)
    /// Strategy 2: Multi-zone search (upper, mid, lower)
    /// Strategy 3: Full torso scan (when others fail)
    /// - Parameter image: The image to analyze
    /// - Returns: Best detected bib numbers
    func detectBibNumbersMultiStrategy(in image: CGImage) throws -> [BibNumberResult] {
        print("Strategy 1: Fast detection (upper chest)...")
        let fastResults = try detectBibNumbersFast(in: image)

        if !fastResults.isEmpty {
            print("✓ Found \(fastResults.count) bib(s) using fast detection")
            return fastResults
        }

        print("Strategy 2: Multi-zone search...")
        let multiZoneResults = try detectBibNumbers(in: image)

        if !multiZoneResults.isEmpty {
            print("✓ Found \(multiZoneResults.count) bib(s) using multi-zone search")
            return multiZoneResults
        }

        print("Strategy 3: Full torso scan...")
        // Try full torso as last resort
        let poses = try poseManager.detectBodyPose(in: image)
        var fullTorsoResults: [BibNumberResult] = []

        for pose in poses {
            let joints = TorsoJoints(
                leftShoulder: pose.joints["left_shoulder"],
                rightShoulder: pose.joints["right_shoulder"],
                leftHip: pose.joints["left_hip"],
                rightHip: pose.joints["right_hip"],
                leftElbow: pose.joints["left_elbow"],
                rightElbow: pose.joints["right_elbow"],
                neck: pose.joints["neck"],
                root: pose.joints["root"]
            )

            // Extract full torso region
            let allRegions = torsoManager.extractTorsoRegions(
                from: [pose],
                zones: [.fullTorso]
            )

            for region in allRegions {
                if let croppedImage = TorsoRegionManager.cropToBibRegion(image: image, region: region),
                   let detectedNumbers = try? recognizeNumbers(in: croppedImage) {

                    for (number, confidence) in detectedNumbers {
                        fullTorsoResults.append(BibNumberResult(
                            number: number,
                            confidence: confidence,
                            region: region,
                            personID: pose.personID
                        ))
                    }
                }
            }
        }

        if !fullTorsoResults.isEmpty {
            print("✓ Found \(fullTorsoResults.count) bib(s) using full torso scan")
        } else {
            print("✗ No bibs detected")
        }

        return fullTorsoResults
    }
}

// MARK: - Usage Examples

class BibNumberDetectionExamples {

    /// Example 1: Basic bib number detection
    func basicBibDetection(image: CGImage) {
        print("=== Basic Bib Number Detection ===\n")

        let detector = BibNumberDetector()

        do {
            let results = try detector.detectBibNumbers(in: image)

            print("Detected \(results.count) bib number(s):\n")

            for result in results {
                print("Person \(result.personID):")
                print("  Bib Number: \(result.number)")
                print("  Confidence: \(String(format: "%.2f", result.confidence))")
                print("  Found in: \(result.region.zone.rawValue)")
                print("  Region confidence: \(String(format: "%.2f", result.region.confidence))")
                print()
            }

        } catch {
            print("Error: \(error)")
        }

        print("==================================\n")
    }

    /// Example 2: Fast detection for real-time processing
    func fastBibDetection(image: CGImage) {
        print("=== Fast Bib Detection (Real-time) ===\n")

        let detector = BibNumberDetector()
        let startTime = Date()

        do {
            let results = try detector.detectBibNumbersFast(in: image)
            let elapsed = Date().timeIntervalSince(startTime)

            print("Detected \(results.count) bib(s) in \(String(format: "%.3f", elapsed))s")

            for result in results {
                print("  Person \(result.personID): #\(result.number)")
            }

        } catch {
            print("Error: \(error)")
        }

        print("\n======================================\n")
    }

    /// Example 3: Multi-strategy detection (most robust)
    func robustBibDetection(image: CGImage) {
        print("=== Robust Multi-Strategy Detection ===\n")

        let detector = BibNumberDetector()

        do {
            let results = try detector.detectBibNumbersMultiStrategy(in: image)

            print("\nFinal Results:")
            print("  Total bibs detected: \(results.count)")

            for result in results {
                print("  Person \(result.personID): #\(result.number) (\(result.region.zone.rawValue))")
            }

        } catch {
            print("Error: \(error)")
        }

        print("\n========================================\n")
    }

    /// Example 4: Batch processing for race photos
    func batchProcessing(images: [CGImage]) {
        print("=== Batch Processing Race Photos ===\n")

        let detector = BibNumberDetector()
        var allResults: [(imageIndex: Int, results: [BibNumberResult])] = []

        for (index, image) in images.enumerated() {
            print("Processing image \(index + 1)/\(images.count)...")

            do {
                let results = try detector.detectBibNumbersMultiStrategy(in: image)
                allResults.append((index, results))
                print("  Found \(results.count) bib(s)")
            } catch {
                print("  Error: \(error)")
            }
        }

        print("\n=== Summary ===")
        print("Total images processed: \(images.count)")

        let totalBibs = allResults.reduce(0) { $0 + $1.results.count }
        print("Total bibs detected: \(totalBibs)")

        print("\n====================================\n")
    }

    /// Example 5: Integration with complete pipeline
    func completePipelineExample(image: CGImage) {
        print("=== Complete Pipeline: Person → Pose → Bib Detection ===\n")

        // Step 1: Detect people
        let personManager = PersonDetectionManager()
        guard let people = try? personManager.detectPeople(in: image) else {
            print("No people detected")
            return
        }
        print("Step 1: Detected \(people.count) people")

        // Step 2: Estimate poses
        let poseManager = PoseEstimationManager()
        guard let poses = try? poseManager.detectBodyPose(in: image) else {
            print("No poses detected")
            return
        }
        print("Step 2: Detected \(poses.count) poses")

        // Step 3: Extract torso regions
        let torsoManager = TorsoRegionManager()
        let bibRegions = torsoManager.extractTorsoRegions(from: poses)
        print("Step 3: Extracted \(bibRegions.count) bib regions")

        // Step 4: Detect bib numbers
        let detector = BibNumberDetector()
        guard let bibNumbers = try? detector.detectBibNumbers(in: image) else {
            print("No bib numbers detected")
            return
        }
        print("Step 4: Detected \(bibNumbers.count) bib numbers")

        // Display results
        print("\n=== Final Results ===")
        for result in bibNumbers {
            print("Person \(result.personID): Bib #\(result.number)")
            print("  Location: \(result.region.zone.rawValue)")
            print("  Confidence: \(String(format: "%.1f%%", result.confidence * 100))")
        }

        print("\n=========================================================\n")
    }
}

// MARK: - Configuration Guide

/*
 CONFIGURATION FOR DIFFERENT RACE SCENARIOS:

 1. MARATHON / ROAD RACE (Standard):
    - Primary zone: .upperChest (most common)
    - Bib typically 60-80% from shoulders to hips
    - Use fast detection for real-time

 2. TRIATHLON:
    - Check: .midTorso and .lowerTorso
    - Bibs often placed lower (on belt/waist)
    - Use multi-strategy detection

 3. TRACK & FIELD:
    - Primary: .upperChest
    - Usually standard placement
    - Fast detection sufficient

 4. CROSS-COUNTRY / TRAIL:
    - Check all zones (.upperChest, .midTorso, .lowerTorso)
    - Bibs can shift during movement
    - Use robust multi-strategy

 5. CYCLING:
    - Primary: .midTorso (often on lower back)
    - May need .lowerTorso for waist placement
    - Check multiple zones

 TORSO ZONE BREAKDOWN:
 ┌─────────────────────────┐
 │                         │ ← Shoulders (top boundary)
 │    UPPER CHEST          │   60-80% region
 │    (Primary Bib)        │   • Most common placement
 │    [Zone 1]             │   • Marathon, road race
 ├─────────────────────────┤
 │    MID TORSO            │   40-60% region
 │    (Alternative)        │   • Mid-chest to upper abdomen
 │    [Zone 2]             │   • Triathlon, some races
 ├─────────────────────────┤
 │    LOWER TORSO          │   20-40% region
 │    (Lower Placement)    │   • Lower abdomen to waist
 │    [Zone 3]             │   • Triathlon belt, cycling
 └─────────────────────────┘ ← Hips (bottom boundary)

 PERCENTAGE GUIDE (from shoulders to hips):
 • 100% = Shoulders (top)
 • 80-60% = Upper chest (MOST COMMON)
 • 60-40% = Mid torso
 • 40-20% = Lower torso
 • 0% = Hips (bottom)

 CONFIDENCE THRESHOLDS:
 • Joint confidence: >= 0.3 (default)
 • Text/OCR confidence: >= 0.5 (default)
 • Adjust based on image quality

 PERFORMANCE OPTIMIZATION:
 • Fast detection: ~50-100ms (upper chest only)
 • Multi-zone: ~100-200ms (all zones)
 • Full torso scan: ~150-300ms (fallback)
*/
