# Apple Vision Framework - Face, Pose & Person Detection

A comprehensive implementation using Apple's Vision framework for:
- **Face Detection** - Detect faces in images and video
- **Face Recognition** - Recognize facial features and landmarks
- **Pose Estimation** - Detect human body poses with key points
- **Person Detection** - Detect people in images and video

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

## Requirements

- iOS 14.0+ / macOS 11.0+
- Swift 5.0+
- Vision framework
- CoreML (optional for enhanced features)

## Usage

See the example implementations in:
- `FaceDetection.swift` - Face detection implementation
- `FaceRecognition.swift` - Face landmarks and recognition
- `PoseEstimation.swift` - Human pose estimation
- `PersonDetection.swift` - Person/human detection
- `VisionCoordinator.swift` - Integrated coordinator
- `Example.swift` - Usage examples

## Implementation Notes

All implementations use Apple's Vision framework which provides:
- High performance on Apple Silicon
- Privacy-focused on-device processing
- Integration with Core ML for custom models
- Optimized for real-time video processing

## License

MIT License
