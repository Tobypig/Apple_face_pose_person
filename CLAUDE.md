# CLAUDE.md - AI Assistant Guide

## Project Overview

This repository implements a comprehensive Apple Vision Framework solution for sports photography, specifically focused on race bib number detection and OCR. The system combines multiple Vision framework capabilities to detect people, analyze poses, and read race bib numbers with high accuracy.

### Project Purpose

**Primary Goal**: Detect and read race bib numbers from sports photography with 85-98% accuracy across various distances and conditions.

**Key Features**:
- Face detection and recognition with 76 facial landmarks
- Human pose estimation with 19 body joints
- Person detection (full body and upper body modes)
- Torso region detection with 3-zone bib placement analysis
- Smart scaling system for OCR optimization at any distance
- Comprehensive OCR strategy optimized for large numbers
- Visualization system with readable text rendering

### Technology Stack

- **Language**: Swift 5.0+
- **Platforms**: iOS 14.0+ / macOS 11.0+
- **Primary Framework**: Apple Vision framework
- **Image Processing**: Core Image, Core Graphics
- **Performance**: Neural Engine (Apple Silicon), GPU acceleration (Metal)
- **Testing**: Shell scripts with comprehensive test suites

---

## Codebase Structure

### File Organization

```
Apple_face_pose_person/
├── Core Detection Components (Vision Framework)
│   ├── FaceDetection.swift              # Face bounding boxes, head pose
│   ├── FaceRecognition.swift            # 76 facial landmarks
│   ├── PoseEstimation.swift             # 19 body joints detection
│   ├── PersonDetection.swift            # Person bounding boxes
│   └── VisionCoordinator.swift          # Unified detection interface
│
├── Bib Number Detection System
│   ├── TorsoRegionDetection.swift       # 3-zone torso detection
│   ├── BibNumberDetectionExample.swift  # Complete bib detection pipeline
│   └── TorsoVisualization.swift         # Visual debugging tools
│
├── OCR Optimization System
│   ├── TextRegionAnalyzer.swift         # Text size classification
│   ├── BibNumberOCROptimizer.swift      # Number-only OCR config
│   ├── SizeAdaptivePreprocessor.swift   # Size-specific preprocessing
│   ├── MultiPassBibOCR.swift            # Multi-pass strategy
│   ├── SmartScalingSystem.swift         # Distance-based scaling
│   └── OptimizedOCRExamples.swift       # OCR usage examples
│
├── Visualization & Testing
│   ├── ComprehensiveVisualization.swift # Complete viz system
│   ├── VisualizationExamples.swift      # Viz usage examples
│   ├── SmartScalingExamples.swift       # Scaling usage examples
│   ├── VisionFrameworkTests.swift       # 49 comprehensive tests
│   ├── run_tests.sh                     # Test automation script
│   └── Example.swift                    # Basic usage examples
│
└── Documentation
    ├── README.md                        # Project overview
    ├── CLAUDE.md                        # This file
    ├── PIPELINE_FLOWCHART.md            # Complete processing pipeline
    ├── BIB_NUMBER_DETECTION_GUIDE.md    # Bib detection guide
    ├── BIB_OCR_STRATEGY.md              # OCR optimization strategy
    └── SMART_SCALING_GUIDE.md           # Smart scaling documentation
```

### Module Dependencies

```
VisionCoordinator (Entry Point)
    ├── PersonDetectionManager
    ├── PoseEstimationManager
    ├── FaceDetectionManager
    └── FaceRecognitionManager

BibNumberDetector (Specialized Pipeline)
    ├── PersonDetection + PoseEstimation
    ├── TorsoRegionManager (3 zones)
    ├── SmartScalingSystem (distance-based)
    ├── TextRegionAnalyzer (size classification)
    ├── BibNumberOCROptimizer (number-only config)
    ├── SizeAdaptivePreprocessor (preprocessing)
    └── MultiPassBibOCR (5-pass strategy)

ComprehensiveVisualization
    ├── Person bounding boxes
    ├── Pose skeleton rendering
    ├── Torso region highlighting
    └── Bib number annotations
```

---

## Core Concepts & Architecture

### 1. Processing Pipeline Order

**CRITICAL**: The Vision framework processes in this specific order:

```
1. Person Detection    → Establishes where people are (bounding boxes)
2. Pose Estimation     → Detailed body joint analysis (19 points)
3. Face Detection      → Identifies faces within detected people
4. Face Recognition    → Detailed facial landmarks (76 points)
```

This order is **sequential** and **conditional** - each step can be enabled/disabled independently via `VisionCoordinator`.

### 2. Coordinate Systems

**Vision Framework** (Normalized):
- Origin: Bottom-left (0, 0)
- Range: 0.0 to 1.0 for both X and Y
- Y-axis: Bottom to top

**UIKit/AppKit** (Pixels):
- Origin: Top-left (0, 0)
- Range: 0 to image width/height
- Y-axis: Top to bottom

**Conversion Formula**:
```swift
// Vision → Image coordinates
let imageX = visionX * imageWidth
let imageY = (1 - visionY - visionHeight) * imageHeight
```

### 3. Torso Region Detection (3-Zone System)

The torso is divided into 3 zones based on shoulder-to-hip distance:

| Zone | Range | Priority | Use Case |
|------|-------|----------|----------|
| **Zone 1: Upper Chest** | 60-80% | ★★★★★ | Marathon, road races (95% of bibs) |
| **Zone 2: Mid Torso** | 40-60% | ★★★★☆ | Triathlons, alternative placement |
| **Zone 3: Lower Torso** | 20-40% | ★★★☆☆ | Triathlon belts, low placement |

**Required Joints** (minimum confidence 0.3):
- left_shoulder, right_shoulder (top boundary)
- left_hip, right_hip (bottom boundary)

### 4. Smart Scaling Strategy

Automatically scales bib regions based on detected distance:

| Distance | Region Size | Scale Factor | Use Case |
|----------|-------------|--------------|----------|
| Very Close | >80% of image | 0.8-1.0x | Minimal scaling |
| Close | 40-80% | 0.9-1.2x | Light adjustment |
| Medium | 20-40% | 1.5-3.0x | Moderate upscaling |
| Far | 5-20% | 3.0-4.0x | Aggressive upscaling |
| Very Far | <5% | 4.0-6.0x | Maximum upscaling |

**Scaling Modes**:
- `aspectFit`: Maintain aspect ratio, fit within bounds (default)
- `aspectFill`: Maintain aspect ratio, fill bounds (may crop)
- `scaleToFill`: Stretch to exact size (may distort)
- `intelligent`: Auto-select based on content analysis

### 5. OCR Optimization System

**Text Size Classification** (4 classes):
- Very Large: >100px height (primary bib numbers)
- Large: 50-100px (secondary bibs, division markers)
- Medium: 20-50px (sponsor text, event names)
- Small: <20px (noise, fine print)

**Number-Only Configuration**:
- Character set restricted to 0-9 (or 0-9 + A-Z for divisions)
- Accuracy improvement: +15-30%
- 6 predefined configurations: fast, accurate, divisionMarkers, medium, small, fallback

**Multi-Pass Strategy** (5 passes):
1. Fast detection (minimal preprocessing)
2. Enhanced contrast (sharpening + contrast boost)
3. Binarization (black/white conversion)
4. Aggressive upscaling (for small text)
5. Fallback with relaxed constraints

**Early exit**: Stops on first successful detection to save processing time.

---

## Development Workflows

### Working with Detection Features

#### Enable/Disable Features

```swift
// VisionCoordinator provides flexible configuration
let coordinator = VisionCoordinator()

// Configuration presets
coordinator.enableAll()           // All features
coordinator.configureFaceOnly()   // Face detection + recognition only
coordinator.configureBodyOnly()   // Person + pose only

// Custom configuration
coordinator.enablePersonDetection = true
coordinator.enablePoseEstimation = true
coordinator.enableFaceDetection = true
coordinator.enableFaceRecognition = false  // Skip for performance
```

#### Processing Order Matters

When working with bib number detection:

```swift
// CORRECT: Full pipeline
1. Detect people (PersonDetection)
2. Estimate poses (PoseEstimation)
3. Extract torso regions (from pose joints)
4. Scale regions (SmartScaling)
5. Run OCR (with optimization)

// WRONG: Don't skip pose estimation
1. Detect people ✓
2. [Skip pose] ✗  // Without pose, can't find torso zones
3. Try to detect bib ✗  // Will fail - no region to analyze
```

### Adding New Detection Features

When extending the system:

1. **Create a new manager class** following the pattern:
   ```swift
   class NewFeatureManager {
       private var request: VNRequest?

       func detect(in image: CGImage) throws -> [NewFeatureResult] {
           // 1. Create VNImageRequestHandler
           // 2. Perform request
           // 3. Process observations
           // 4. Return results
       }
   }
   ```

2. **Define a result structure**:
   ```swift
   struct NewFeatureResult {
       let boundingBox: CGRect    // Always normalized (0-1)
       let confidence: Float       // Always 0.0-1.0
       let featureID: Int         // Sequential identifier
       // ... feature-specific properties
   }
   ```

3. **Integrate with VisionCoordinator**:
   - Add enable/disable flag
   - Add to processing pipeline (consider order)
   - Add to `VisionAnalysisResult`

### Testing Workflow

#### Running Tests

```bash
# Run all tests
./run_tests.sh

# Run with specific platform
./run_tests.sh iOS      # Default
./run_tests.sh macOS    # macOS testing
```

#### Test Structure (49 tests total)

The test suite in `VisionFrameworkTests.swift` covers:
- 5 Face Detection tests
- 4 Face Recognition tests
- 5 Pose Estimation tests
- 6 Person Detection tests
- 5 Vision Coordinator tests
- 5 Bib Detection tests
- 6 Smart Scaling tests
- 5 OCR Optimizer tests
- 4 Performance benchmarks
- 4 Integration tests

#### Writing New Tests

Follow the existing pattern:

```swift
func testNewFeature() {
    // 1. Setup
    let manager = NewFeatureManager()
    let testImage = createTestImage()

    // 2. Execute
    let results = try? manager.detect(in: testImage)

    // 3. Assert
    XCTAssertNotNil(results)
    XCTAssertGreaterThan(results?.count ?? 0, 0)

    // 4. Validate results
    if let result = results?.first {
        XCTAssertGreaterThan(result.confidence, 0.5)
        XCTAssertTrue(result.boundingBox.width > 0)
    }
}
```

---

## File Naming & Code Conventions

### File Naming Patterns

1. **Core Components**: `{Feature}{Type}.swift`
   - Examples: `FaceDetection.swift`, `PersonDetection.swift`
   - Pattern: Feature name + Detection/Recognition/Estimation

2. **Examples**: `{Feature}Examples.swift`
   - Examples: `OptimizedOCRExamples.swift`, `VisualizationExamples.swift`
   - Purpose: Demonstrate usage patterns

3. **Managers**: `{Feature}Manager` class within files
   - Examples: `FaceDetectionManager`, `TorsoRegionManager`
   - Purpose: Encapsulate detection logic

4. **Documentation**: `{TOPIC}_{TYPE}.md`
   - Examples: `BIB_NUMBER_DETECTION_GUIDE.md`, `PIPELINE_FLOWCHART.md`
   - Pattern: ALL_CAPS with underscores

### Code Style Conventions

#### Class/Struct Naming

```swift
// Manager classes - singular noun + Manager
class PersonDetectionManager { }
class TorsoRegionManager { }

// Result structures - singular noun + Result
struct FaceDetectionResult { }
struct PoseEstimationResult { }

// Enums - descriptive names
enum TextSizeClass { }
enum ScalingMode { }
enum TorsoZone { }
```

#### Property Naming

```swift
// Boolean flags - enable prefix for features
var enableFaceDetection: Bool
var enablePoseEstimation: Bool

// Confidence thresholds - min prefix
var minJointConfidence: Float = 0.3
var minTextConfidence: Float = 0.5

// Expansion factors - descriptive + Factor suffix
var widthExpansionFactor: Float = 1.2
var heightExpansionFactor: Float = 1.1
```

#### Method Naming

```swift
// Detection methods - verb + object
func detectFaces(in image: CGImage) -> [FaceDetectionResult]
func detectBodyPose(in image: CGImage) -> [PoseEstimationResult]

// Configuration methods - configure prefix
func configureFaceOnly()
func configureBodyOnly()

// Utility methods - descriptive verbs
func extractTorsoRegions(from poses: [Pose]) -> [TorsoRegion]
func convertToImageCoordinates(region: CGRect) -> CGRect
```

### Documentation Comments

Use standard Swift documentation:

```swift
/// Brief description of class/function
///
/// Detailed explanation if needed with:
/// - Multiple points
/// - Usage notes
/// - Important caveats
///
/// - Parameter image: Description of parameter
/// - Returns: Description of return value
/// - Throws: Conditions that cause errors
func detect(in image: CGImage) throws -> [Result]
```

---

## Common Tasks & Patterns

### Task 1: Adding a New Detection Strategy

**Scenario**: Need to add a new way to detect bib numbers for a specific race type.

**Steps**:

1. **Identify the variation** - What's different?
   - Different torso zones?
   - Different OCR settings?
   - Different preprocessing?

2. **Create a new method** in appropriate manager:
   ```swift
   // In BibNumberDetector
   func detectBibNumbersFor{RaceType}(in image: CGImage) throws -> [BibResult] {
       // Custom logic here
   }
   ```

3. **Add configuration options**:
   ```swift
   enum RaceType {
       case marathon, triathlon, cycling, trail
   }

   func detectBibNumbers(in image: CGImage, raceType: RaceType) throws -> [BibResult]
   ```

4. **Update documentation**:
   - Add to `BIB_NUMBER_DETECTION_GUIDE.md`
   - Include usage example
   - Document expected success rates

5. **Add tests**:
   ```swift
   func testNewRaceTypeDetection() {
       // Test implementation
   }
   ```

### Task 2: Optimizing Performance

**Common Performance Bottlenecks**:

1. **Face Recognition** (slowest component)
   - **Solution**: Disable if not needed
   - **Impact**: ~15-30ms saved per face

2. **Multiple OCR passes** (for small/distant bibs)
   - **Solution**: Use fast detection mode for standard marathons
   - **Impact**: ~100ms saved per person

3. **High resolution images** (>1080p)
   - **Solution**: Downscale to 720p or 1080p before processing
   - **Impact**: ~40% faster processing

**Performance Optimization Pattern**:

```swift
// For real-time video (30fps = 33ms budget)
let coordinator = VisionCoordinator()
coordinator.enableFaceDetection = false      // Save ~5-15ms
coordinator.enableFaceRecognition = false    // Save ~15-30ms
coordinator.enablePoseEstimation = true      // Need for bib detection
coordinator.enablePersonDetection = true

let detector = BibNumberDetector()
detector.useStrategy(.fast)                  // Upper chest only

// Process every 2nd or 3rd frame if needed
if frameCount % 2 == 0 {
    let results = try coordinator.analyzeVideoFrame(pixelBuffer)
}
```

### Task 3: Debugging Detection Failures

**Systematic Debugging Approach**:

1. **Enable visualization**:
   ```swift
   let visualizer = ComprehensiveVisualization()
   let annotated = visualizer.visualizeAll(
       image: image,
       people: people,
       poses: poses,
       bibResults: bibResults
   )
   // Save annotated image to inspect
   ```

2. **Check each pipeline stage**:
   ```swift
   // Stage 1: Person detection
   print("People detected: \(people.count)")
   for person in people {
       print("  Confidence: \(person.confidence)")
   }

   // Stage 2: Pose estimation
   print("Poses detected: \(poses.count)")
   for pose in poses {
       print("  Joints: \(pose.joints.count)")
       print("  Has shoulders: \(pose.joints["left_shoulder"] != nil)")
       print("  Has hips: \(pose.joints["left_hip"] != nil)")
   }

   // Stage 3: Torso extraction
   let torsoManager = TorsoRegionManager()
   let regions = torsoManager.extractTorsoRegions(from: poses)
   print("Torso regions: \(regions.count)")
   ```

3. **Lower thresholds progressively**:
   ```swift
   // Try with relaxed settings
   torsoManager.minJointConfidence = 0.2     // From 0.3
   detector.minTextConfidence = 0.3          // From 0.5
   torsoManager.widthExpansionFactor = 1.5   // From 1.2
   ```

4. **Check coordinate conversions**:
   ```swift
   // Verify Vision → Image coordinate conversion
   print("Vision coords: \(visionBox)")
   let imageBox = convertToImageCoordinates(region: visionBox, imageSize: size)
   print("Image coords: \(imageBox)")

   // Sanity checks
   assert(imageBox.minX >= 0 && imageBox.minX <= imageWidth)
   assert(imageBox.minY >= 0 && imageBox.minY <= imageHeight)
   ```

### Task 4: Adding Platform-Specific Code

**Pattern for macOS vs iOS**:

```swift
#if os(macOS)
import AppKit
typealias PlatformImage = NSImage

func convertToCGImage(_ image: NSImage) -> CGImage? {
    return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
}
#else
import UIKit
typealias PlatformImage = UIImage

func convertToCGImage(_ image: UIImage) -> CGImage? {
    return image.cgImage
}
#endif

// Platform-agnostic code
class ImageProcessor {
    func process(_ image: PlatformImage) throws -> Result {
        guard let cgImage = convertToCGImage(image) else {
            throw VisionError.invalidImage
        }
        // Process cgImage...
    }
}
```

### Task 5: Adding New Documentation

**Documentation Files**:

1. **Code documentation** - Use Swift doc comments (`///`)
2. **Usage guides** - Add to existing `.md` files or create new ones
3. **API reference** - Update README.md with new features
4. **Examples** - Add to appropriate `*Examples.swift` file

**Documentation Checklist**:
- [ ] Add Swift doc comments to public APIs
- [ ] Update README.md if adding major feature
- [ ] Create or update relevant `.md` guide
- [ ] Add code examples to `*Examples.swift`
- [ ] Update `CLAUDE.md` (this file) if changing architecture
- [ ] Add tests demonstrating usage

---

## Best Practices for AI Assistants

### Understanding User Intent

When a user asks to work with this codebase:

1. **Clarify the scope**:
   - Is this for detection accuracy? → Focus on OCR optimization, thresholds
   - Is this for performance? → Focus on disabling features, resolution, frame skipping
   - Is this for a specific race type? → Focus on torso zones, detection strategies

2. **Consider the full pipeline**:
   - Don't optimize just OCR - consider the entire chain
   - Person detection must succeed before pose estimation
   - Pose estimation must succeed before torso detection
   - Each stage has its own confidence thresholds

3. **Maintain backward compatibility**:
   - Don't change default values without good reason
   - Provide new methods rather than changing existing ones
   - Document breaking changes clearly

### Code Modification Guidelines

**DO**:
- ✅ Follow existing naming conventions
- ✅ Add tests for new functionality
- ✅ Update documentation when adding features
- ✅ Use the established error handling pattern (`throw VisionError.*`)
- ✅ Maintain coordinate system conversions correctly
- ✅ Provide configuration options rather than hardcoding values
- ✅ Include usage examples in `*Examples.swift` files

**DON'T**:
- ❌ Change the processing pipeline order without careful consideration
- ❌ Remove existing detection strategies (add new ones instead)
- ❌ Hardcode magic numbers (use configurable properties)
- ❌ Skip coordinate system conversions
- ❌ Forget to handle both macOS and iOS (#if os(...))
- ❌ Remove or modify tests without understanding impact
- ❌ Change default confidence thresholds without testing

### Explaining Code to Users

When describing this codebase:

1. **Start with the big picture**:
   - "This is a race bib number detection system built on Apple Vision framework"
   - Mention the 4-stage pipeline (person → pose → face → recognition)

2. **Use the documentation**:
   - Reference specific guide files (`BIB_NUMBER_DETECTION_GUIDE.md`)
   - Point to relevant example code (`OptimizedOCRExamples.swift`)
   - Show flowcharts (`PIPELINE_FLOWCHART.md`)

3. **Provide concrete examples**:
   - Don't just explain concepts - show code snippets
   - Use realistic scenarios (marathon vs triathlon detection)
   - Include expected performance metrics

4. **Highlight key concepts**:
   - Coordinate system differences (Vision vs UIKit)
   - 3-zone torso detection system
   - Smart scaling based on distance
   - Multi-pass OCR strategy

### Debugging with Users

**Systematic approach**:

1. **Gather information**:
   ```
   - What type of race/event?
   - What's the typical distance to subjects?
   - What's the expected bib size/placement?
   - What's the image resolution?
   - What's the current success rate?
   ```

2. **Enable verbose logging**:
   ```swift
   // Suggest adding debug output
   print("People: \(people.count), Poses: \(poses.count)")
   print("Torso regions: \(regions.count)")
   print("OCR results: \(results.count)")
   ```

3. **Use visualization**:
   ```swift
   // Always suggest visualizing the pipeline
   let viz = ComprehensiveVisualization()
   let annotated = viz.visualizeAll(...)
   ```

4. **Adjust systematically**:
   - Try relaxed thresholds first
   - Then try different detection strategies
   - Finally try different preprocessing/scaling options

### Performance Analysis

When optimizing performance:

1. **Measure first**:
   ```swift
   let start = Date()
   let results = try detector.detect(in: image)
   let elapsed = Date().timeIntervalSince(start)
   print("Processing time: \(elapsed * 1000)ms")
   ```

2. **Identify bottlenecks**:
   - Face Recognition: ~15-30ms per face
   - Pose Estimation: ~20-40ms per person
   - Person Detection: ~10-20ms total
   - OCR (5 passes): ~50-200ms per person

3. **Optimize strategically**:
   - Disable unused features first (biggest wins)
   - Reduce resolution if acceptable
   - Use faster detection strategies
   - Process fewer frames (for video)

4. **Document tradeoffs**:
   - "Disabling face recognition saves ~25ms but loses facial landmarks"
   - "Fast detection is 2x faster but may miss 10% of lower-placed bibs"

---

## Platform-Specific Considerations

### macOS vs iOS Differences

| Aspect | macOS | iOS |
|--------|-------|-----|
| **Image Type** | `NSImage` | `UIImage` |
| **Import** | `import AppKit` | `import UIKit` |
| **CGImage conversion** | `image.cgImage(forProposedRect:context:hints:)` | `image.cgImage` |
| **Performance** | Faster on M1/M2 Macs | Varies by device |
| **Neural Engine** | Available on Apple Silicon | Available on A12+ |

### Handling Platform Differences

```swift
// Use conditional compilation
#if os(macOS)
    // macOS-specific code
#else
    // iOS-specific code
#endif

// Or create platform-agnostic wrappers
typealias PlatformImage = PlatformSpecificImageType
```

---

## Git Workflow & Conventions

### Commit Message Pattern

Based on recent commits:

```
{Action} {feature/component description}

Examples:
- "Add comprehensive OCR optimization system for large bib numbers"
- "Implement comprehensive visualization system with readable text rendering"
- "Add comprehensive automated tests for smart scaling system"
```

**Pattern**:
- Start with action verb (Add, Implement, Fix, Update)
- Be descriptive and comprehensive
- Use "comprehensive" when adding complete systems
- Mention the key benefit/purpose

### Branch Strategy

- Work on feature branches: `claude/claude-md-{session-id}`
- Create descriptive branch names for features
- Push to origin with `-u` flag: `git push -u origin branch-name`

### When to Commit

Commit when:
- ✅ Adding a new complete feature
- ✅ Completing a major refactoring
- ✅ Adding comprehensive test coverage
- ✅ Adding/updating documentation
- ✅ Fixing a significant bug

Avoid committing:
- ❌ Incomplete features
- ❌ Code that breaks existing tests
- ❌ Debug/temporary code
- ❌ Configuration files with local paths

---

## Quick Reference

### Essential File Locations

| Need | File |
|------|------|
| Full pipeline overview | `PIPELINE_FLOWCHART.md` |
| Bib detection guide | `BIB_NUMBER_DETECTION_GUIDE.md` |
| OCR optimization | `BIB_OCR_STRATEGY.md` |
| Smart scaling | `SMART_SCALING_GUIDE.md` |
| Usage examples | `*Examples.swift` files |
| Test suite | `VisionFrameworkTests.swift` |
| Test runner | `run_tests.sh` |

### Key Classes & Their Purpose

| Class | Purpose | Location |
|-------|---------|----------|
| `VisionCoordinator` | Unified interface for all Vision features | `VisionCoordinator.swift` |
| `TorsoRegionManager` | 3-zone torso detection | `TorsoRegionDetection.swift` |
| `SmartScalingSystem` | Distance-based image scaling | `SmartScalingSystem.swift` |
| `BibNumberOCROptimizer` | Number-only OCR configuration | `BibNumberOCROptimizer.swift` |
| `MultiPassBibOCR` | 5-pass OCR strategy | `MultiPassBibOCR.swift` |
| `ComprehensiveVisualization` | Complete visualization system | `ComprehensiveVisualization.swift` |

### Common Configuration Values

| Parameter | Default | Range | Purpose |
|-----------|---------|-------|---------|
| `minJointConfidence` | 0.3 | 0.0-1.0 | Minimum pose joint confidence |
| `minTextConfidence` | 0.5 | 0.0-1.0 | Minimum OCR confidence |
| `widthExpansionFactor` | 1.2 | 1.0-2.0 | Torso region width expansion |
| `heightExpansionFactor` | 1.1 | 1.0-2.0 | Torso region height expansion |
| `minimumTextHeight` | 0.2 | 0.0-1.0 | OCR minimum text size |

### Performance Targets

| Scenario | Target Time | Configuration |
|----------|-------------|---------------|
| Real-time video (30fps) | 33ms/frame | Disable face recognition, 720p |
| Batch processing | 100-200ms/image | All features, 1080p |
| Fast bib detection | 50-80ms/person | Upper chest only |
| Comprehensive bib detection | 150-300ms/person | All zones, multi-pass |

---

## Troubleshooting Guide

### Common Issues & Solutions

#### Issue 1: No People Detected

**Symptoms**: `people.count == 0`

**Causes**:
- Image too dark/bright
- People too small in frame
- Confidence threshold too high

**Solutions**:
```swift
// Lower confidence threshold
personDetectionManager.minimumConfidence = 0.3  // From 0.5

// Try upper body mode (more tolerant)
personDetectionManager.detectionMode = .upperBody

// Check image quality
print("Image size: \(image.width) x \(image.height)")
```

#### Issue 2: No Poses Detected

**Symptoms**: `poses.count == 0` but `people.count > 0`

**Causes**:
- Person turned away (back to camera)
- Partial body visible
- Pose confidence too low

**Solutions**:
```swift
// Lower joint confidence
poseEstimationManager.minimumJointConfidence = 0.1  // From 0.3

// Check which joints are detected
for (name, joint) in pose.joints {
    print("\(name): confidence=\(joint.confidence)")
}
```

#### Issue 3: No Torso Regions Extracted

**Symptoms**: `regions.count == 0` but `poses.count > 0`

**Causes**:
- Missing required joints (shoulders or hips)
- Joint confidence below threshold

**Solutions**:
```swift
// Check required joints
let hasShoulders = pose.joints["left_shoulder"] != nil &&
                   pose.joints["right_shoulder"] != nil
let hasHips = pose.joints["left_hip"] != nil &&
              pose.joints["right_hip"] != nil
print("Has shoulders: \(hasShoulders), Has hips: \(hasHips)")

// Lower torso extraction threshold
torsoManager.minJointConfidence = 0.2  // From 0.3
```

#### Issue 4: OCR Not Reading Bib Numbers

**Symptoms**: `bibResults.count == 0` but `regions.count > 0`

**Causes**:
- Text too small
- Poor image quality
- Wrong OCR configuration

**Solutions**:
```swift
// Use multi-pass strategy
let results = try detector.detectBibNumbersMultiStrategy(in: image)

// Try aggressive upscaling
let scaler = SmartScalingSystem()
let scaled = scaler.scaleRegion(region, targetSize: CGSize(width: 400, height: 1000))

// Lower OCR confidence
detector.minTextConfidence = 0.3  // From 0.5

// Enable visualization to inspect regions
let viz = TorsoVisualization()
let annotated = viz.drawAllZones(on: image, pose: pose)
```

#### Issue 5: Poor Performance / Too Slow

**Symptoms**: Processing time > 200ms per image

**Solutions**:
```swift
// Disable face recognition (saves ~15-30ms/face)
coordinator.enableFaceRecognition = false

// Use fast detection strategy (saves ~100ms/person)
detector.useStrategy(.fast)

// Reduce image resolution
let maxDimension: CGFloat = 1080
if max(image.width, image.height) > maxDimension {
    image = resizeImage(image, maxDimension: maxDimension)
}

// For video: process every Nth frame
if frameCount % 3 == 0 {
    // Process this frame
}
```

---

## Version History & Evolution

### Recent Development (Git History)

Based on commit history, the project evolved in these phases:

1. **Foundation** (Initial commit):
   - Core Vision framework implementation
   - Face, pose, person detection

2. **Testing & Documentation**:
   - Comprehensive test suite (49 tests)
   - Pipeline documentation and flowcharts

3. **Bib Detection System**:
   - 3-zone torso detection
   - Basic OCR implementation

4. **Smart Scaling** (4e465fe):
   - Distance-based scaling system
   - 5 distance categories
   - 4 scaling modes

5. **Automated Testing** (231acce):
   - Smart scaling test suite
   - Automated test runner script

6. **Visualization System** (5d3f466):
   - Comprehensive visualization
   - Readable text rendering
   - Multi-layer annotation

7. **OCR Strategy** (cf492fb):
   - Size-adaptive preprocessing
   - Number-only configuration
   - Multi-pass detection

8. **OCR Optimization** (9ecec20 - Latest):
   - Text size classification
   - Intelligent preprocessing
   - Performance improvements (62% faster)

### Current State (Latest Commit)

**Version**: Post-OCR-Optimization
**Last Updated**: Recent (commit 9ecec20)
**Status**: Production-ready with comprehensive testing

**Key Capabilities**:
- 85-98% bib detection accuracy
- Real-time capable (with configuration)
- Multi-platform (iOS + macOS)
- Comprehensive test coverage (49 tests)
- Complete documentation suite

---

## Future Development Considerations

### Potential Enhancements

1. **Multi-bib support**:
   - Handle athletes wearing multiple bibs
   - Front and back number correlation

2. **Video tracking**:
   - Track bib numbers across video frames
   - Temporal filtering for improved accuracy

3. **Additional race types**:
   - Swimming (bibs on swim caps)
   - Skiing (bibs on back)
   - Horse racing (different bib placement)

4. **Machine learning integration**:
   - Custom Core ML models for bib detection
   - Fine-tuned OCR models for race numbers

5. **Cloud processing**:
   - Batch processing of race photos
   - Distributed OCR for large events

### Architecture Extensibility

The current architecture is designed to support:

- **New detection features**: Add managers following existing pattern
- **New OCR strategies**: Extend `MultiPassBibOCR` with new passes
- **New visualization types**: Add to `ComprehensiveVisualization`
- **New race types**: Add detection strategies to `BibNumberDetector`
- **New platforms**: Use `#if os(...)` conditional compilation

---

## Contact & Contribution

### For AI Assistants

When working with this codebase:

1. **Always read this file first** to understand the architecture
2. **Reference the specific guides** for detailed information:
   - `PIPELINE_FLOWCHART.md` - Processing flow
   - `BIB_NUMBER_DETECTION_GUIDE.md` - Bib detection details
   - `BIB_OCR_STRATEGY.md` - OCR optimization
   - `SMART_SCALING_GUIDE.md` - Scaling system

3. **Use the examples** in `*Examples.swift` files as templates

4. **Run tests** after any changes: `./run_tests.sh`

5. **Update documentation** when adding features

### Contributing Guidelines

- Follow existing code style and conventions
- Add tests for new functionality
- Update documentation (code comments + markdown files)
- Use descriptive commit messages
- Consider performance implications
- Maintain backward compatibility

---

## Glossary

**Vision Framework**: Apple's framework for computer vision tasks (face/body detection, OCR, etc.)

**Normalized Coordinates**: Coordinates in 0.0-1.0 range, independent of image size

**Bib Number**: Race participant identification number worn on clothing

**Torso Region**: Area of the body between shoulders and hips where bibs are typically placed

**Joint Confidence**: Probability (0.0-1.0) that a detected body joint is accurate

**OCR (Optical Character Recognition)**: Technology for converting images of text into machine-readable text

**Multi-pass Strategy**: Running OCR multiple times with different settings to improve accuracy

**Smart Scaling**: Automatically adjusting image size based on detected distance to subject

**Neural Engine**: Apple's dedicated hardware for machine learning tasks

**IoU (Intersection over Union)**: Metric for measuring bounding box overlap (used in NMS)

**NMS (Non-Maximum Suppression)**: Technique to remove duplicate detections

---

**Last Updated**: 2025-11 (Post-OCR-Optimization)
**Version**: 1.0
**Maintained By**: AI-assisted development
