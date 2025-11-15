# Apple Vision Framework - Face, Pose & Person Detection

A comprehensive implementation using Apple's Vision framework for:
- **Face Detection** - Detect faces in images and video
- **Face Recognition** - Recognize facial features and landmarks
- **Pose Estimation** - Detect human body poses with key points
- **Person Detection** - Detect people in images and video
- **Bib Number Detection** - Detect and read race bib numbers (NEW!)

## Features

### Face Detection
- Detects face bounding boxes
- Provides face quality metrics
- Supports multiple faces in single frame
- Real-time processing capability

### Face Recognition
- 76 facial landmarks detection
- Face contours (eyes, nose, lips, etc.)
- Face capture quality assessment
- Yaw, pitch, roll angle detection

### Pose Estimation
- Full body pose with 19 key points
- Joint positions and confidence scores
- Support for multiple people
- Real-time pose tracking

### Person Detection
- Human body detection
- Upper body detection option
- Bounding box coordinates
- Confidence scores

### Bib Number Detection
- **Torso region detection** with 3 zones (upper chest, mid torso, lower torso)
- **Race bib number OCR** using Vision text recognition
- **Multi-strategy detection** for different bib placements
- **Support for various race types** (marathon, triathlon, cycling, trail)
- Real-world scenario handling (bibs placed at different heights)
- **Smart scaling system** for optimal OCR at any distance
  - Automatic distance detection (very close → very far)
  - Intelligent upscaling for far subjects (up to 6x)
  - Image enhancement (sharpening, contrast)
  - 4 scaling modes: aspect fit, aspect fill, scale to fill, intelligent

### Comprehensive Visualization (NEW!)
- **Person bounding boxes** with customizable colors and line widths
- **Pose skeleton rendering** with joints (19 points) and bone connections
- **Torso region visualization** with zone-specific styling
- **Bib number highlighting** with prominent display
- **Readable text rendering** with:
  - Semi-transparent background boxes
  - Text outlines for maximum contrast (3-4px)
  - Customizable font size and weight
  - Background padding for clarity
- **Layered rendering system** (person boxes → torso → pose → bib numbers)
- **9 comprehensive examples** covering all use cases
- Platform-optimized text rendering (macOS/iOS)

## Requirements

- iOS 14.0+ / macOS 11.0+
- Swift 5.0+
- Vision framework
- CoreML (optional for enhanced features)

## Usage

See the example implementations in:

**Core Detection:**
- `FaceDetection.swift` - Face detection implementation
- `FaceRecognition.swift` - Face landmarks and recognition
- `PoseEstimation.swift` - Human pose estimation
- `PersonDetection.swift` - Person/human detection
- `VisionCoordinator.swift` - Integrated coordinator

**Bib Number Detection:**
- `TorsoRegionDetection.swift` - Torso region & bib zone detection
- `BibNumberDetectionExample.swift` - Complete bib detection examples (with smart scaling)
- `TorsoVisualization.swift` - Visualization utilities
- `SmartScalingSystem.swift` - Smart scaling for OCR optimization
- `SmartScalingExamples.swift` - Smart scaling usage examples
- `BIB_NUMBER_DETECTION_GUIDE.md` - Comprehensive guide with diagrams
- `SMART_SCALING_GUIDE.md` - Smart scaling system documentation

**Comprehensive Visualization (NEW!):**
- `ComprehensiveVisualization.swift` - Complete visualization system with readable text rendering
- `VisualizationExamples.swift` - 9 visualization usage examples
  - Person bounding boxes (customizable colors & line widths)
  - Pose skeletons (joints & bones with confidence scores)
  - Torso regions (multiple zone visualization)
  - Bib number highlighting
  - Layered visualization rendering
  - Readable text with background boxes & outlines for maximum contrast

**Examples & Testing:**
- `Example.swift` - Basic usage examples
- `VisionFrameworkTests.swift` - Comprehensive test suite (49 tests)
- `run_tests.sh` - Automated test runner

**Documentation:**
- `PIPELINE_FLOWCHART.md` - Complete processing pipeline explanation
- `BIB_NUMBER_DETECTION_GUIDE.md` - Bib detection guide with real-world scenarios

## Implementation Notes

All implementations use Apple's Vision framework which provides:
- High performance on Apple Silicon
- Privacy-focused on-device processing
- Integration with Core ML for custom models
- Optimized for real-time video processing

## License

MIT License
