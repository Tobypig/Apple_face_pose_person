# Bib Detection System - Integration Guide

Complete guide to integrating the Apple Vision Framework bib detection system into your application.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Architecture Overview](#architecture-overview)
3. [Feature Selection Guide](#feature-selection-guide)
4. [Integration Patterns](#integration-patterns)
5. [Performance Optimization](#performance-optimization)
6. [Error Handling](#error-handling)
7. [Best Practices](#best-practices)
8. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Minimal Integration (5 minutes)

```swift
import Foundation
import CoreGraphics

// 1. Load your image
guard let image = loadYourImage() else { return }

// 2. Detect pose
let poseDetector = PoseEstimator()
guard let pose = poseDetector.detectPose(in: image) else {
    print("No person detected")
    return
}

// 3. Detect bib (using parallel processing for best speed/accuracy)
let result = ParallelZoneProcessor.detect(in: image, pose: pose)

if let bib = result {
    print("Bib number: \(bib.number)")
    print("Confidence: \(bib.confidence)")
}
```

**That's it!** This gives you fast, accurate bib detection with sensible defaults.

---

## Architecture Overview

### Detection Pipeline

```
┌─────────────┐
│   Image     │
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│ Person Detection│  (Optional - validates person present)
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│ Pose Estimation │  (Required - provides torso regions)
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│  Zone Analysis  │  (Confidence weighting - optional optimization)
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│ Bib Detection   │  (Choose method based on needs)
│                 │
│ Options:        │
│ • Parallel      │  ← Recommended (3-4x faster)
│ • Sequential    │
│ • Adaptive      │
│ • Smart         │
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│     Result      │
└─────────────────┘
```

### Core Components

| Component | Purpose | When to Use |
|-----------|---------|-------------|
| **PoseEstimator** | Detect human pose | Always (required) |
| **TorsoRegionManager** | Generate bib search zones | Automatic (built-in) |
| **ParallelZoneProcessor** | Process zones concurrently | Production (recommended) |
| **LanguageHintOCRDetector** | OCR with custom vocabulary | High accuracy needed |
| **TextLocalizedBibDetection** | Fast text localization | Speed critical |
| **ColorEnhancedBibDetection** | Color-based pre-detection | Colored bibs common |
| **AdaptiveTorsoExpander** | Progressive region expansion | Non-standard placement |
| **ConfidenceWeightedBibDetector** | Skip low-confidence zones | Partial occlusion |

---

## Feature Selection Guide

### Choose Your Detection Method

#### 1. **ParallelZoneProcessor** (Recommended for Most Cases)

**Best For:** Production systems, batch processing, real-time requirements

**Pros:**
- 3-4x faster on multi-core devices
- Automatic load balancing
- Excellent accuracy
- Simple API

**Cons:**
- Slightly higher CPU usage
- Not ideal for single-core devices

**Usage:**
```swift
let parallel = ParallelZoneProcessor()
parallel.detectionMethod = .languageHints  // or .textLocalization, .colorEnhanced
parallel.verboseLogging = false

let (result, stats) = parallel.detectInParallel(in: image, pose: pose)
print("Speedup: \(stats.speedupFactor)x")
```

---

#### 2. **SmartConfidenceProcessor** (Best Overall)

**Best For:** When you want automatic optimization

**Pros:**
- Automatically chooses parallel vs sequential
- Confidence-based zone filtering
- Adapts to image quality
- Best speed/accuracy balance

**Cons:**
- Slightly more complex

**Usage:**
```swift
let smartProcessor = SmartConfidenceProcessor()
smartProcessor.minimumZoneConfidence = 0.4
smartProcessor.useParallelForHighConfidence = true

let (result, stats) = smartProcessor.detectSmart(in: image, pose: pose)
```

---

#### 3. **ConfidenceWeightedBibDetector** (Speed Optimized)

**Best For:** Real-time video, partial occlusion

**Pros:**
- 15% faster than standard
- Skips unreliable zones
- Adaptive thresholds
- Good for occluded poses

**Cons:**
- May miss bibs in low-confidence zones

**Usage:**
```swift
let detector = ConfidenceWeightedBibDetector()
detector.minimumZoneConfidence = 0.4
detector.enableFallback = true  // Try low-confidence zones if needed

let (result, stats) = detector.detectWithConfidenceWeighting(in: image, pose: pose)
print("Zones skipped: \(stats.zonesSkipped)")
```

---

#### 4. **AdaptiveTorsoExpander** (Accuracy Optimized)

**Best For:** Non-standard bib placement, difficult images

**Pros:**
- +15-20% detection rate
- Handles unusual placements
- Progressive expansion
- Statistics tracking

**Cons:**
- Slower (processes multiple expansions)
- More CPU intensive

**Usage:**
```swift
let expander = AdaptiveTorsoExpander()
expander.enableColorPreDetection = true
expander.maxExpansionAttempts = 4

let result = expander.detectWithAdaptiveExpansion(in: image, pose: pose)
if result.success {
    print("Found with \(result.strategyUsed.displayName)")
}
```

---

### OCR Method Selection

| Method | Speed | Accuracy | Best For |
|--------|-------|----------|----------|
| **Text Localization** | ⚡⚡⚡⚡⚡ (40-80ms) | ⭐⭐⭐ | Real-time, clear images |
| **Language Hints** | ⚡⚡⚡ (80-120ms) | ⭐⭐⭐⭐⭐ | Blurry, division markers |
| **Color-Enhanced** | ⚡⚡⚡⚡ (50-100ms) | ⭐⭐⭐⭐ | Colored bibs, good lighting |
| **Multi-Scale** | ⚡⚡ (200-400ms) | ⭐⭐⭐⭐⭐ | Varying sizes, distant |
| **Adaptive Expansion** | ⚡⚡ (150-300ms) | ⭐⭐⭐⭐ | Non-standard placement |

**Recommendation:**
- **Production**: Language Hints with Parallel Processing
- **Real-Time**: Text Localization with Confidence Weighting
- **Maximum Accuracy**: Language Hints with Adaptive Expansion
- **Colored Bibs**: Color-Enhanced with Parallel Processing

---

## Integration Patterns

### Pattern 1: Simple Synchronous Detection

**Use Case:** Single image, blocking operation OK

```swift
class SimpleBibDetector {
    func detectBib(in image: CGImage) -> String? {
        // Detect pose
        let poseDetector = PoseEstimator()
        guard let pose = poseDetector.detectPose(in: image) else {
            return nil
        }

        // Detect bib (parallel for speed)
        let result = ParallelZoneProcessor.detect(in: image, pose: pose)
        return result?.number
    }
}
```

---

### Pattern 2: Async Batch Processing

**Use Case:** Process many images without blocking

```swift
class AsyncBatchDetector {
    func processBatch(_ images: [CGImage],
                     completion: @escaping ([String?]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let processor = BatchParallelProcessor()
            processor.maxConcurrentImages = 4

            var results: [String?] = []

            for image in images {
                guard let pose = self.detectPose(in: image) else {
                    results.append(nil)
                    continue
                }

                let result = ParallelZoneProcessor.detect(in: image, pose: pose)
                results.append(result?.number)
            }

            DispatchQueue.main.async {
                completion(results)
            }
        }
    }

    private func detectPose(in image: CGImage) -> PoseEstimationResult? {
        let detector = PoseEstimator()
        return detector.detectPose(in: image)
    }
}
```

---

### Pattern 3: Progressive Fallback Chain

**Use Case:** Try fast methods first, fall back to thorough

```swift
class FallbackDetector {
    func detectWithFallback(in image: CGImage,
                           pose: PoseEstimationResult) -> BibNumberResult? {
        // Try 1: Fast text localization (40-80ms)
        if let result = tryFast(image: image, pose: pose),
           result.confidence >= 0.8 {
            return result  // High confidence, done!
        }

        // Try 2: Language hints (80-120ms)
        if let result = tryBalanced(image: image, pose: pose),
           result.confidence >= 0.7 {
            return result
        }

        // Try 3: Adaptive expansion (150-300ms)
        return tryThorough(image: image, pose: pose)
    }

    private func tryFast(image: CGImage, pose: PoseEstimationResult) -> BibNumberResult? {
        let parallel = ParallelZoneProcessor()
        parallel.detectionMethod = .textLocalization
        parallel.verboseLogging = false
        let (result, _) = parallel.detectInParallel(in: image, pose: pose)
        return result
    }

    private func tryBalanced(image: CGImage, pose: PoseEstimationResult) -> BibNumberResult? {
        let parallel = ParallelZoneProcessor()
        parallel.detectionMethod = .languageHints
        parallel.verboseLogging = false
        let (result, _) = parallel.detectInParallel(in: image, pose: pose)
        return result
    }

    private func tryThorough(image: CGImage, pose: PoseEstimationResult) -> BibNumberResult? {
        let expander = AdaptiveTorsoExpander()
        expander.enableColorPreDetection = true
        let result = expander.detectWithAdaptiveExpansion(in: image, pose: pose)
        return result.bibNumber
    }
}
```

---

### Pattern 4: Real-Time Video Stream

**Use Case:** Process video frames with frame skipping

```swift
class VideoStreamDetector {
    private var frameSkip = 2
    private var frameCount = 0

    func processFrame(_ frame: CGImage) -> String? {
        frameCount += 1

        // Skip frames to maintain framerate
        guard frameCount % frameSkip == 0 else {
            return nil
        }

        // Fast detection (targeting 12-25 FPS)
        guard let pose = detectPoseFast(in: frame) else {
            return nil
        }

        // Use confidence-weighted for speed
        let detector = ConfidenceWeightedBibDetector()
        detector.detectionMethod = .textLocalization
        detector.minimumZoneConfidence = 0.5
        detector.enableFallback = false
        detector.verboseLogging = false

        let (result, _) = detector.detectWithConfidenceWeighting(in: frame, pose: pose)
        return result?.number
    }

    private func detectPoseFast(in image: CGImage) -> PoseEstimationResult? {
        let detector = PoseEstimator()
        return detector.detectPose(in: image)
    }
}
```

---

## Performance Optimization

### Optimization Checklist

#### ✅ Essential Optimizations

1. **Use Parallel Processing**
   ```swift
   // ❌ Sequential (slow)
   for region in regions {
       result = detector.detect(in: image, region: region)
   }

   // ✅ Parallel (3-4x faster)
   let (result, _) = parallelProcessor.detectInParallel(in: image, pose: pose)
   ```

2. **Enable Confidence Weighting**
   ```swift
   // Skip low-confidence zones to save time
   let detector = ConfidenceWeightedBibDetector()
   detector.minimumZoneConfidence = 0.4  // Adjust based on needs
   ```

3. **Cache Vocabulary Generation**
   ```swift
   // ✅ Vocabulary auto-cached after first generation
   let detector = LanguageHintOCRDetector()
   detector.vocabularyPreset = .balanced  // Cached on first use
   ```

#### 🚀 Advanced Optimizations

4. **Smart Early Exit**
   ```swift
   let smartProcessor = SmartParallelProcessor()
   smartProcessor.earlyExitConfidence = 0.85  // Stop when very confident
   ```

5. **Adjust QoS for Use Case**
   ```swift
   let parallel = ParallelZoneProcessor()
   parallel.qos = .userInteractive  // For real-time UI
   // or .userInitiated for background processing
   // or .utility for batch jobs
   ```

6. **Frame Skipping for Video**
   ```swift
   // Process every Nth frame
   guard frameCount % 2 == 0 else { return nil }
   ```

---

### Performance Targets

| Scenario | Target Time | Method |
|----------|-------------|--------|
| Real-time video | 40-80ms | Text Localization + Confidence Weighting |
| Interactive single image | 80-150ms | Parallel + Language Hints |
| Batch processing | 50-100ms/image | Batch Parallel + Smart Confidence |
| Difficult image rescue | 200-500ms | Adaptive Expansion + Multi-Scale |

---

## Error Handling

### Graceful Degradation

```swift
func detectBibWithErrorHandling(image: CGImage) -> Result<String, DetectionError> {
    // Step 1: Pose detection
    guard let pose = detectPose(in: image) else {
        return .failure(.noPoseDetected)
    }

    guard pose.confidence >= 0.3 else {
        return .failure(.lowPoseConfidence(pose.confidence))
    }

    // Step 2: Bib detection with fallback
    if let result = tryFastDetection(image: image, pose: pose) {
        return .success(result.number)
    }

    if let result = trySlowDetection(image: image, pose: pose) {
        return .success(result.number)
    }

    return .failure(.noBibDetected)
}

enum DetectionError: Error {
    case noPoseDetected
    case lowPoseConfidence(Float)
    case noBibDetected
}
```

---

## Best Practices

### ✅ DO

1. **Use parallel processing for production**
   - 3-4x speedup with no accuracy loss
   - Essential for batch processing

2. **Enable confidence weighting for partial occlusion**
   - Saves 15%+ time when some body parts hidden
   - Automatic fallback available

3. **Use language hints for division markers**
   - +10-15% accuracy for A123, B456 formats
   - Essential for races with divisions

4. **Cache pose results when processing same image multiple times**
   - Reuse pose for multiple detection attempts
   - Saves ~30-50ms per attempt

5. **Monitor statistics for optimization**
   - Track success rates by zone
   - Adjust thresholds based on data

### ❌ DON'T

1. **Don't use sequential processing in production**
   - 3-4x slower than parallel
   - Only for debugging

2. **Don't skip warmup for benchmarking**
   - First run includes vocabulary generation
   - Use 3+ warmup runs for accurate metrics

3. **Don't use aggressive expansion for standard placement**
   - Wastes time on extra expansions
   - Use smart/confidence-weighted instead

4. **Don't disable fallback in difficult scenarios**
   - May miss valid detections
   - Only disable for real-time video

5. **Don't ignore confidence scores**
   - Low confidence may indicate false positive
   - Use thresholds (0.5-0.7 typical)

---

## Troubleshooting

### Common Issues

#### Issue: "No pose detected"

**Causes:**
- Person not fully visible
- Low image quality
- Multiple people (picks random)

**Solutions:**
```swift
// 1. Check person detection first
let personDetector = PersonDetector()
let persons = personDetector.detectPersons(in: image)

if persons.isEmpty {
    print("No person in image")
} else if persons.count > 1 {
    print("Multiple people - crop to single person first")
}

// 2. Lower pose confidence threshold (if needed)
// Note: PoseEstimator has internal threshold
```

---

#### Issue: "Detection very slow"

**Causes:**
- Using sequential instead of parallel
- No confidence weighting
- Excessive expansion attempts

**Solutions:**
```swift
// 1. Switch to parallel
let parallel = ParallelZoneProcessor()
let (result, stats) = parallel.detectInParallel(in: image, pose: pose)
print("Speedup: \(stats.speedupFactor)x")

// 2. Enable confidence weighting
let smart = SmartConfidenceProcessor()
smart.minimumZoneConfidence = 0.4

// 3. Reduce expansion attempts
let expander = AdaptiveTorsoExpander()
expander.maxExpansionAttempts = 2  // Default is 4
```

---

#### Issue: "Low accuracy on blurry images"

**Causes:**
- Using fast text localization
- No language hints
- Single scale only

**Solutions:**
```swift
// 1. Use language hints
let detector = LanguageHintOCRDetector()
detector.vocabularyPreset = .balanced

// 2. Try multi-scale
let multiScale = MultiScaleOCRDetector()
multiScale.scales = .balanced  // 4 scales

// 3. Use adaptive expansion
let expander = AdaptiveTorsoExpander()
expander.enableColorPreDetection = true
```

---

#### Issue: "False positives"

**Causes:**
- Too low confidence threshold
- Wrong OCR character set
- No pattern validation

**Solutions:**
```swift
// 1. Increase confidence threshold
if let result = detector.detect(...), result.confidence >= 0.7 {
    // Only accept high-confidence results
}

// 2. Validate pattern
func isValidBibNumber(_ text: String) -> Bool {
    let cleaned = text.trimmingCharacters(in: .whitespaces)

    // Must be 1-6 characters
    guard (1...6).contains(cleaned.count) else { return false }

    // Must contain at least one digit
    guard cleaned.rangeOfCharacter(from: .decimalDigits) != nil else {
        return false
    }

    // Must be alphanumeric
    let allowed = CharacterSet.alphanumerics
    guard cleaned.rangeOfCharacter(from: allowed.inverted) == nil else {
        return false
    }

    return true
}
```

---

## Summary

### Quick Decision Tree

```
Need to detect bib number?
│
├─ Real-time video?
│  └─ Use ConfidenceWeightedBibDetector + TextLocalization (40-80ms)
│
├─ Batch processing?
│  └─ Use ParallelZoneProcessor + LanguageHints (50-100ms/image)
│
├─ Maximum accuracy?
│  └─ Use AdaptiveTorsoExpander + LanguageHints (150-300ms)
│
└─ General use?
   └─ Use SmartConfidenceProcessor (auto-selects best method)
```

### Recommended Production Setup

```swift
// Production-ready detector with optimal settings
class ProductionBibDetector {
    private let smartProcessor = SmartConfidenceProcessor()

    init() {
        smartProcessor.minimumZoneConfidence = 0.4
        smartProcessor.useParallelForHighConfidence = true
    }

    func detect(in image: CGImage) -> BibNumberResult? {
        // Detect pose
        let poseDetector = PoseEstimator()
        guard let pose = poseDetector.detectPose(in: image),
              pose.confidence >= 0.3 else {
            return nil
        }

        // Smart detection
        let (result, stats) = smartProcessor.detectSmart(in: image, pose: pose)

        // Log statistics
        print("Processed \(stats.zonesProcessed) zones in \(String(format: "%.0f", stats.totalTime * 1000))ms")

        return result
    }
}
```

---

## Support

For issues, questions, or contributions:
- Check the examples in `RealWorldUsageGuide.swift`
- Review integration tests in `IntegrationTests.swift`
- Run performance benchmarks in `PerformanceBenchmarks.swift`
- See README.md for feature documentation

---

**Version:** 1.0
**Last Updated:** 2025-01
**Compatibility:** iOS 14.0+, macOS 11.0+
