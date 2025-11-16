import Foundation
import Vision
import CoreImage
import CoreGraphics

#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

// MARK: - Example 1: Complete Bib Detection Pipeline

func example1_CompleteBibDetectionPipeline() {
    print("=== Example 1: Complete Bib Detection Pipeline ===\n")

    // Load image (example)
    guard let image = loadExampleImage(),
          let cgImage = image.cgImage else {
        print("Failed to load image")
        return
    }

    // Step 1: Detect person and get torso region
    let personDetector = PersonDetection()
    guard let people = personDetector.detectPeople(in: cgImage),
          let firstPerson = people.first else {
        print("No people detected")
        return
    }

    print("✓ Detected person with confidence: \(firstPerson.confidence)")

    // Step 2: Get pose and torso region
    let poseEstimator = PoseEstimation()
    guard let pose = try? poseEstimator.estimatePose(in: cgImage),
          !pose.isEmpty else {
        print("No pose detected")
        return
    }

    let torsoDetector = TorsoRegionDetector()
    let torsoRegions = torsoDetector.detectTorsoRegions(from: pose.first!)

    print("✓ Detected \(torsoRegions.count) torso regions")

    // Step 3: Analyze text regions in torso
    let analyzer = TextRegionAnalyzer()
    analyzer.config.referenceHeight = torsoRegions.first?.upperChest.height ?? 200

    // Combine all torso zones for analysis
    let searchRegions = torsoRegions.flatMap { region in
        [region.upperChest, region.midTorso, region.lowerTorso]
    }

    print("✓ Analyzing \(searchRegions.count) potential bib regions")

    // Step 4: Perform multi-pass OCR
    let ocrSystem = MultiPassBibOCR()
    var allResults: [BibNumberResult] = []

    for (index, searchRegion) in searchRegions.enumerated() {
        print("\nSearching region \(index + 1)...")

        // Analyze region
        if let analysis = try? analyzer.analyze(boundingBox: searchRegion, in: cgImage) {
            print("  Size: \(analysis.sizeClass.displayName)")
            print("  Confidence: \(analysis.confidence)")

            // Perform adaptive OCR
            if let result = ocrSystem.recognizeBibNumberAdaptive(in: cgImage, analysis: analysis) {
                print("  ✓ Found: \(result.number) (confidence: \(String(format: "%.2f", result.adjustedConfidence)))")
                allResults.append(result)
            }
        }
    }

    // Step 5: Select best result
    if let bestResult = allResults.max(by: { $0.adjustedConfidence < $1.adjustedConfidence }) {
        print("\n=== Final Result ===")
        print("Bib Number: \(bestResult.number)")
        print("Confidence: \(String(format: "%.2f", bestResult.adjustedConfidence))")
        print("Detected via: \(bestResult.passName ?? "unknown")")
        print("Detection time: \(String(format: "%.3f", bestResult.detectionTime ?? 0))s")
    } else {
        print("\n✗ No bib number detected")
    }
}

// MARK: - Example 2: Size-Adaptive Processing

func example2_SizeAdaptiveProcessing() {
    print("\n=== Example 2: Size-Adaptive Processing ===\n")

    guard let image = loadExampleImage(),
          let cgImage = image.cgImage else {
        return
    }

    let analyzer = TextRegionAnalyzer()
    let preprocessor = SizeAdaptivePreprocessor()

    // Simulate different text sizes
    let testRegions: [(String, CGRect)] = [
        ("Very Large (120px)", CGRect(x: 100, y: 100, width: 300, height: 120)),
        ("Large (70px)", CGRect(x: 100, y: 250, width: 200, height: 70)),
        ("Medium (35px)", CGRect(x: 100, y: 350, width: 150, height: 35)),
        ("Small (18px)", CGRect(x: 100, y: 400, width: 100, height: 18))
    ]

    for (name, region) in testRegions {
        print("Processing \(name)...")

        // Analyze
        guard let analysis = try? analyzer.analyze(boundingBox: region, in: cgImage) else {
            continue
        }

        print("  Detected size class: \(analysis.sizeClass.displayName)")
        print("  Contrast: \(analysis.contrast.displayName)")

        // Preprocess adaptively
        if let processed = preprocessor.preprocess(cgImage, for: analysis) {
            print("  ✓ Preprocessed successfully")
            print("  Quality improvement: \(String(format: "%.1f%%", preprocessor.measureQualityImprovement(original: cgImage, processed: processed) * 100))")

            // Measure size after preprocessing
            print("  Output size: \(processed.width)x\(processed.height)")
        }

        print("")
    }
}

// MARK: - Example 3: Multi-Pass Strategy Comparison

func example3_MultiPassComparison() {
    print("\n=== Example 3: Multi-Pass Strategy Comparison ===\n")

    guard let image = loadExampleImage(),
          let cgImage = image.cgImage else {
        return
    }

    let region = CGRect(x: 100, y: 100, width: 200, height: 80)

    // Test each pass individually
    let testPasses: [(String, OCRSettings, PreprocessingProfile)] = [
        ("Fast Large Numbers", BibNumberOCROptimizer.fastLargeNumbers, .minimal),
        ("Accurate + Division", BibNumberOCROptimizer.withDivisionMarkers, .standard),
        ("Enhanced Preprocessing", BibNumberOCROptimizer.accurateLargeNumbers, .enhanced),
        ("Aggressive", BibNumberOCROptimizer.mediumSizedBibs, .aggressive)
    ]

    for (name, settings, profile) in testPasses {
        print("Testing: \(name)")
        print("  Character set: \(settings.characterSet.displayName)")
        print("  Preprocessing: \(profile.displayName)")

        // Preprocess
        let preprocessor = SizeAdaptivePreprocessor()
        guard let processed = preprocessor.preprocess(cgImage, profile: profile),
              let cropped = processed.cropping(to: region) else {
            print("  ✗ Preprocessing failed\n")
            continue
        }

        // Perform OCR
        var ocrResults: [VNRecognizedText]?
        let request = BibNumberOCROptimizer.createRequest(with: settings) { request, error in
            ocrResults = request.results as? [VNRecognizedText]
        }

        let handler = VNImageRequestHandler(cgImage: cropped, options: [:])
        try? handler.perform([request])

        if let results = ocrResults, !results.isEmpty {
            print("  ✓ Detected \(results.count) text items")
            for (i, result) in results.prefix(3).enumerated() {
                print("    \(i+1). '\(result.string)' (confidence: \(String(format: "%.2f", result.confidence)))")
            }
        } else {
            print("  ✗ No text detected")
        }

        print("")
    }
}

// MARK: - Example 4: Pattern Validation

func example4_PatternValidation() {
    print("\n=== Example 4: Pattern Validation ===\n")

    let validator = BibNumberValidator()

    // Test various bib number formats
    let testCases: [(String, String)] = [
        ("123", "Pure number"),
        ("A456", "Division marker"),
        ("12345", "5-digit number"),
        ("AB123", "Multi-letter division"),
        ("123-45", "Hyphenated"),
        ("1", "Single digit"),
        ("ABCDEF", "No digits - INVALID"),
        ("12abc", "Lowercase - INVALID"),
        ("123456789", "Too long - INVALID")
    ]

    for (bibNumber, description) in testCases {
        let result = validator.validate(bibNumber)
        let isValid = result.isValid
        let symbol = isValid ? "✓" : "✗"

        print("\(symbol) '\(bibNumber)' (\(description))")

        if !isValid, case .invalid(let reason) = result {
            print("  Reason: \(reason)")
        }

        if isValid {
            let baseConfidence: Float = 0.75
            let adjusted = validator.adjustConfidence(baseConfidence, for: bibNumber)
            print("  Confidence adjustment: \(String(format: "%.2f", baseConfidence)) → \(String(format: "%.2f", adjusted))")
        }

        print("")
    }
}

// MARK: - Example 5: Custom Preprocessing Pipeline

func example5_CustomPreprocessingPipeline() {
    print("\n=== Example 5: Custom Preprocessing Pipeline ===\n")

    guard let image = loadExampleImage(),
          let cgImage = image.cgImage else {
        return
    }

    let builder = PreprocessingPipelineBuilder()

    // Build custom pipeline for very small, distant bibs
    print("Building custom pipeline for small distant bibs...")
    let customProcessed = builder
        .addUpscaling(factor: 4.0)
        .addBinarization()
        .addContrast(1.6)
        .addSharpening(intensity: 1.4)
        .addEdgeEnhancement(intensity: 2.0)
        .execute(on: cgImage)

    if let processed = customProcessed {
        print("✓ Custom preprocessing completed")
        print("  Original size: \(cgImage.width)x\(cgImage.height)")
        print("  Processed size: \(processed.width)x\(processed.height)")
        print("  Upscale factor: \(Float(processed.width) / Float(cgImage.width))x")
    }

    // Build different pipeline for large, low-contrast bibs
    builder.reset()

    print("\nBuilding pipeline for large low-contrast bibs...")
    let largeProcessed = builder
        .addBinarization()
        .addContrast(1.8)
        .addEdgeEnhancement(intensity: 3.0)
        .addSharpening(intensity: 0.6)
        .execute(on: cgImage)

    if let processed = largeProcessed {
        print("✓ Large bib preprocessing completed")
        print("  Applied: binarization, high contrast, edge enhancement")
    }
}

// MARK: - Example 6: Batch Processing

func example6_BatchProcessing() {
    print("\n=== Example 6: Batch Processing Multiple Regions ===\n")

    guard let image = loadExampleImage(),
          let cgImage = image.cgImage else {
        return
    }

    // Simulate multiple bib regions (e.g., from multiple people)
    let bibRegions: [CGRect] = [
        CGRect(x: 100, y: 100, width: 150, height: 80),
        CGRect(x: 300, y: 150, width: 180, height: 90),
        CGRect(x: 500, y: 120, width: 120, height: 60),
        CGRect(x: 700, y: 180, width: 200, height: 100)
    ]

    let ocrSystem = MultiPassBibOCR()
    ocrSystem.config.enableEarlyExit = true  // Fast processing

    print("Processing \(bibRegions.count) bib regions...\n")

    let results = ocrSystem.recognizeBibNumbers(in: cgImage, regions: bibRegions)

    print("=== Results ===")
    print("Successfully detected: \(results.count) / \(bibRegions.count)")

    for (index, result) in results.enumerated() {
        print("\nBib \(index + 1):")
        print("  Number: \(result.number)")
        print("  Confidence: \(String(format: "%.2f", result.adjustedConfidence))")
        print("  Pass: \(result.passName ?? "unknown")")
        print("  Time: \(String(format: "%.3f", result.detectionTime ?? 0))s")
    }
}

// MARK: - Example 7: OCR Configuration Comparison

func example7_OCRConfigurationComparison() {
    print("\n=== Example 7: OCR Configuration Comparison ===\n")

    let configurations: [(String, OCRSettings)] = [
        ("Fast (digits only)", BibNumberOCROptimizer.fastLargeNumbers),
        ("Accurate (digits only)", BibNumberOCROptimizer.accurateLargeNumbers),
        ("With divisions", BibNumberOCROptimizer.withDivisionMarkers),
        ("Medium sized", BibNumberOCROptimizer.mediumSizedBibs),
        ("Small/distant", BibNumberOCROptimizer.smallDistantBibs),
        ("Fallback", BibNumberOCROptimizer.fallback)
    ]

    for (name, config) in configurations {
        print("Configuration: \(name)")
        print("  Character set: \(config.characterSet.displayName)")
        print("  Recognition level: \(config.recognitionLevel == .accurate ? "Accurate" : "Fast")")
        print("  Min text height: \(config.minimumTextHeight > 0 ? String(format: "%.0f%%", config.minimumTextHeight * 100) : "None")")
        print("  Min confidence: \(String(format: "%.2f", config.minimumConfidence))")
        print("  Language correction: \(config.usesLanguageCorrection ? "Enabled" : "Disabled")")
        print("")
    }
}

// MARK: - Example 8: Real-Time Video Processing Simulation

func example8_RealTimeProcessing() {
    print("\n=== Example 8: Real-Time Processing Simulation ===\n")

    guard let image = loadExampleImage(),
          let cgImage = image.cgImage else {
        return
    }

    // Simulate processing multiple frames
    let frameCount = 10
    var detectedBibs: [String: Int] = [:] // Bib number : detection count

    print("Simulating \(frameCount) video frames...\n")

    let ocrSystem = MultiPassBibOCR()
    ocrSystem.config.enableEarlyExit = true  // Fast mode for real-time
    ocrSystem.config.maxPasses = 2           // Limit passes for speed

    let region = CGRect(x: 100, y: 100, width: 200, height: 80)

    for frame in 1...frameCount {
        let startTime = Date()

        if let result = ocrSystem.recognizeBibNumber(in: cgImage, region: region) {
            detectedBibs[result.number, default: 0] += 1

            let processingTime = Date().timeIntervalSince(startTime)
            print("Frame \(frame): Detected '\(result.number)' in \(String(format: "%.0f", processingTime * 1000))ms")
        } else {
            print("Frame \(frame): No detection")
        }
    }

    // Determine most consistent detection
    print("\n=== Detection Summary ===")
    for (bibNumber, count) in detectedBibs.sorted(by: { $0.value > $1.value }) {
        let percentage = Float(count) / Float(frameCount) * 100
        print("Bib '\(bibNumber)': detected in \(count)/\(frameCount) frames (\(String(format: "%.0f", percentage))%)")
    }
}

// MARK: - Example 9: Complete Integration Example

func example9_CompleteIntegration() {
    print("\n=== Example 9: Complete Integration Example ===\n")

    guard let image = loadExampleImage(),
          let cgImage = image.cgImage else {
        return
    }

    // Complete race photo processing pipeline
    print("Processing race photo...\n")

    // 1. Detect all people
    let personDetector = PersonDetection()
    guard let people = personDetector.detectPeople(in: cgImage) else {
        print("No people detected")
        return
    }
    print("✓ Detected \(people.count) people")

    // 2. For each person, detect pose and bib
    let poseEstimator = PoseEstimation()
    let torsoDetector = TorsoRegionDetector()
    let ocrSystem = MultiPassBibOCR()

    for (index, person) in people.enumerated() {
        print("\n--- Person \(index + 1) ---")

        // Get pose
        guard let poses = try? poseEstimator.estimatePose(in: cgImage),
              !poses.isEmpty else {
            print("  No pose detected")
            continue
        }

        // Get torso region
        let torsoRegions = torsoDetector.detectTorsoRegions(from: poses.first!)
        guard !torsoRegions.isEmpty else {
            print("  No torso detected")
            continue
        }

        // Try each torso zone
        var foundBib: BibNumberResult?
        let zones = [torsoRegions[0].upperChest, torsoRegions[0].midTorso, torsoRegions[0].lowerTorso]

        for (zoneIndex, zone) in zones.enumerated() {
            if let result = ocrSystem.recognizeBibNumber(in: cgImage, region: zone) {
                if foundBib == nil || result.adjustedConfidence > foundBib!.adjustedConfidence {
                    foundBib = result
                    print("  Found bib in zone \(zoneIndex + 1): \(result.number)")
                }
            }
        }

        if let bibResult = foundBib {
            print("  ✓ Bib Number: \(bibResult.number)")
            print("  ✓ Confidence: \(String(format: "%.2f", bibResult.adjustedConfidence))")
        } else {
            print("  ✗ No bib detected")
        }
    }
}

// MARK: - Utility Functions

func loadExampleImage() -> PlatformImage? {
    // In real usage, load actual race photo
    // For example purposes, create a placeholder
    #if os(macOS)
    return NSImage(size: NSSize(width: 1920, height: 1080))
    #else
    return UIImage(systemName: "person.fill")
    #endif
}

// MARK: - Main Runner

func runAllOCRExamples() {
    example1_CompleteBibDetectionPipeline()
    example2_SizeAdaptiveProcessing()
    example3_MultiPassComparison()
    example4_PatternValidation()
    example5_CustomPreprocessingPipeline()
    example6_BatchProcessing()
    example7_OCRConfigurationComparison()
    example8_RealTimeProcessing()
    example9_CompleteIntegration()
}

/*
 Usage:

 // Run all examples
 runAllOCRExamples()

 // Or run individually
 example1_CompleteBibDetectionPipeline()
 example4_PatternValidation()
 */
