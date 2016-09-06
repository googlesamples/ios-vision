/*
 Copyright 2015-present Google Inc. All Rights Reserved.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
*/


@import AVFoundation;
@import GoogleMobileVision;

#import "CameraViewController.h"
#import "DrawingUtility.h"

@interface CameraViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>
// UI elements.
@property(nonatomic, weak) IBOutlet UIView *placeHolder;
@property(nonatomic, weak) IBOutlet UIView *overlayView;
@property(nonatomic, weak) IBOutlet UISwitch *cameraSwitch;

// Video objects.
@property(nonatomic, strong) AVCaptureSession *session;
@property(nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
@property(nonatomic, strong) dispatch_queue_t videoDataOutputQueue;
@property(nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property(nonatomic, assign) UIDeviceOrientation lastKnownDeviceOrientation;

// Detector.
@property(nonatomic, strong) GMVDetector *faceDetector;

@end

@implementation CameraViewController

- (id)initWithCoder:(NSCoder *)aDecoder {
  self = [super initWithCoder:aDecoder];
  if (self) {
    self.videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue",
        DISPATCH_QUEUE_SERIAL);
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  // Set up default camera settings.
  self.session = [[AVCaptureSession alloc] init];
  self.session.sessionPreset = AVCaptureSessionPresetMedium;
  self.cameraSwitch.on = YES;
  [self updateCameraSelection];

  // Setup video processing pipeline.
  [self setupVideoProcessing];

  // Setup camera preview.
  [self setupCameraPreview];

  // Initialize the face detector.
  NSDictionary *options = @{
    GMVDetectorFaceMinSize : @(0.3),
    GMVDetectorFaceTrackingEnabled : @(YES),
    GMVDetectorFaceLandmarkType : @(GMVDetectorFaceLandmarkAll)
  };
  self.faceDetector = [GMVDetector detectorOfType:GMVDetectorTypeFace options:options];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];

  self.previewLayer.frame = self.view.layer.bounds;
  self.previewLayer.position = CGPointMake(CGRectGetMidX(self.previewLayer.frame),
                                           CGRectGetMidY(self.previewLayer.frame));
}

- (void)viewDidUnload {
  [self cleanupCaptureSession];
  [super viewDidUnload];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  [self.session startRunning];
}

- (void)viewDidDisappear:(BOOL)animated {
  [super viewDidDisappear:animated];
  [self.session stopRunning];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                         duration:(NSTimeInterval)duration {
  // Camera rotation needs to be manually set when rotation changes.
  if (self.previewLayer) {
    if (toInterfaceOrientation == UIInterfaceOrientationPortrait) {
      self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    } else if (toInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) {
      self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
    } else if (toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) {
      self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
    } else if (toInterfaceOrientation == UIInterfaceOrientationLandscapeRight) {
      self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
    }
  }
}

#pragma mark - AVCaptureVideoPreviewLayer Helper method

- (CGRect)scaledRect:(CGRect)rect
              xScale:(CGFloat)xscale
              yScale:(CGFloat)yscale
              offset:(CGPoint)offset {
  CGRect resultRect = CGRectMake(rect.origin.x * xscale,
                                 rect.origin.y * yscale,
                                 rect.size.width * xscale,
                                 rect.size.height * yscale);
  resultRect = CGRectOffset(resultRect, offset.x, offset.y);
  return resultRect;
}

- (CGPoint)scaledPoint:(CGPoint)point
                xScale:(CGFloat)xscale
                yScale:(CGFloat)yscale
                offset:(CGPoint)offset {
  CGPoint resultPoint = CGPointMake(point.x * xscale + offset.x, point.y * yscale + offset.y);
  return resultPoint;
}

- (void)setLastKnownDeviceOrientation:(UIDeviceOrientation)orientation {
  if (orientation != UIDeviceOrientationUnknown &&
      orientation != UIDeviceOrientationFaceUp &&
      orientation != UIDeviceOrientationFaceDown) {
    _lastKnownDeviceOrientation = orientation;
  }
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput
    didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
           fromConnection:(AVCaptureConnection *)connection {

  UIImage *image = [GMVUtility sampleBufferTo32RGBA:sampleBuffer];
  AVCaptureDevicePosition devicePosition = self.cameraSwitch.isOn ? AVCaptureDevicePositionFront :
      AVCaptureDevicePositionBack;

  // Establish the image orientation.
  UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
  GMVImageOrientation orientation = [GMVUtility
      imageOrientationFromOrientation:deviceOrientation
            withCaptureDevicePosition:devicePosition
             defaultDeviceOrientation:self.lastKnownDeviceOrientation];
  NSDictionary *options = @{
    GMVDetectorImageOrientation : @(orientation)
  };
  // Detect features using GMVDetector.
  NSArray<GMVFaceFeature *> *faces = [self.faceDetector featuresInImage:image options:options];
  NSLog(@"Detected %lu face(s).", (unsigned long)[faces count]);

  // The video frames captured by the camera are a different size than the video preview.
  // Calculates the scale factors and offset to properly display the features.
  CMFormatDescriptionRef fdesc = CMSampleBufferGetFormatDescription(sampleBuffer);
  CGRect clap = CMVideoFormatDescriptionGetCleanAperture(fdesc, false);
  CGSize parentFrameSize = self.previewLayer.frame.size;

  // Assume AVLayerVideoGravityResizeAspect
  CGFloat cameraRatio = clap.size.height / clap.size.width;
  CGFloat viewRatio = parentFrameSize.width / parentFrameSize.height;
  CGFloat xScale = 1;
  CGFloat yScale = 1;
  CGRect videoBox = CGRectZero;
  if (viewRatio > cameraRatio) {
    videoBox.size.width = parentFrameSize.height * clap.size.width / clap.size.height;
    videoBox.size.height = parentFrameSize.height;
    videoBox.origin.x = (parentFrameSize.width - videoBox.size.width) / 2;
    videoBox.origin.y = (videoBox.size.height - parentFrameSize.height) / 2;

    xScale = videoBox.size.width / clap.size.width;
    yScale = videoBox.size.height / clap.size.height;
  } else {
    videoBox.size.width = parentFrameSize.width;
    videoBox.size.height = clap.size.width * (parentFrameSize.width / clap.size.height);
    videoBox.origin.x = (videoBox.size.width - parentFrameSize.width) / 2;
    videoBox.origin.y = (parentFrameSize.height - videoBox.size.height) / 2;

    xScale = videoBox.size.width / clap.size.height;
    yScale = videoBox.size.height / clap.size.width;
  }

  dispatch_sync(dispatch_get_main_queue(), ^{
    // Remove previously added feature views.
    for (UIView *featureView in self.overlayView.subviews) {
      [featureView removeFromSuperview];
    }

    // Display detected features in overlay.
    for (GMVFaceFeature *face in faces) {
      CGRect faceRect = [self scaledRect:face.bounds
                                  xScale:xScale
                                  yScale:yScale
                                  offset:videoBox.origin];
      [DrawingUtility addRectangle:faceRect
                     toView:self.overlayView
                  withColor:[UIColor redColor]];

       // Mouth
       if (face.hasBottomMouthPosition) {
         CGPoint point = [self scaledPoint:face.bottomMouthPosition
                                    xScale:xScale
                                    yScale:yScale
                                    offset:videoBox.origin];
         [DrawingUtility addCircleAtPoint:point
                            toView:self.overlayView
                         withColor:[UIColor greenColor]
                        withRadius:5];
       }
       if (face.hasMouthPosition) {
         CGPoint point = [self scaledPoint:face.mouthPosition
                                    xScale:xScale
                                    yScale:yScale
                                    offset:videoBox.origin];
         [DrawingUtility addCircleAtPoint:point
                            toView:self.overlayView
                         withColor:[UIColor greenColor]
                        withRadius:10];
       }
       if (face.hasRightMouthPosition) {
         CGPoint point = [self scaledPoint:face.rightMouthPosition
                                    xScale:xScale
                                    yScale:yScale
                                    offset:videoBox.origin];
         [DrawingUtility addCircleAtPoint:point
                            toView:self.overlayView
                         withColor:[UIColor greenColor]
                        withRadius:5];
       }
       if (face.hasLeftMouthPosition) {
         CGPoint point = [self scaledPoint:face.leftMouthPosition
                                    xScale:xScale
                                    yScale:yScale
                                    offset:videoBox.origin];
         [DrawingUtility addCircleAtPoint:point
                                   toView:self.overlayView
                                withColor:[UIColor greenColor]
                               withRadius:5];
       }

       // Nose
       if (face.hasNoseBasePosition) {
         CGPoint point = [self scaledPoint:face.noseBasePosition
                                    xScale:xScale
                                    yScale:yScale
                                    offset:videoBox.origin];
         [DrawingUtility addCircleAtPoint:point
                                   toView:self.overlayView
                                withColor:[UIColor darkGrayColor]
                               withRadius:10];
       }

      // Eyes
      if (face.hasLeftEyePosition) {
        CGPoint point = [self scaledPoint:face.leftEyePosition
                                   xScale:xScale
                                   yScale:yScale
                                   offset:videoBox.origin];
        [DrawingUtility addCircleAtPoint:point
                                  toView:self.overlayView
                               withColor:[UIColor blueColor]
                              withRadius:10];
      }
      if (face.hasRightEyePosition) {
        CGPoint point = [self scaledPoint:face.rightEyePosition
                                   xScale:xScale
                                   yScale:yScale
                                   offset:videoBox.origin];
        [DrawingUtility addCircleAtPoint:point
                           toView:self.overlayView
                        withColor:[UIColor blueColor]
                       withRadius:10];
      }

      // Ears
      if (face.hasLeftEarPosition) {
        CGPoint point = [self scaledPoint:face.leftEarPosition
                                   xScale:xScale
                                   yScale:yScale
                                   offset:videoBox.origin];
        [DrawingUtility addCircleAtPoint:point
                                  toView:self.overlayView
                               withColor:[UIColor purpleColor]
                              withRadius:10];
      }
      if (face.hasRightEarPosition) {
        CGPoint point = [self scaledPoint:face.rightEarPosition
                                   xScale:xScale
                                   yScale:yScale
                                   offset:videoBox.origin];
        [DrawingUtility addCircleAtPoint:point
                                  toView:self.overlayView
                               withColor:[UIColor purpleColor]
                              withRadius:10];
      }

      // Cheeks
      if (face.hasLeftCheekPosition) {
        CGPoint point = [self scaledPoint:face.leftCheekPosition
                                   xScale:xScale
                                   yScale:yScale
                                   offset:videoBox.origin];
        [DrawingUtility addCircleAtPoint:point
                                  toView:self.overlayView
                               withColor:[UIColor magentaColor]
                              withRadius:10];
      }
      if (face.hasRightCheekPosition) {
        CGPoint point = [self scaledPoint:face.rightCheekPosition
                                   xScale:xScale
                                   yScale:yScale
                                   offset:videoBox.origin];
        [DrawingUtility addCircleAtPoint:point
                                  toView:self.overlayView
                               withColor:[UIColor magentaColor]
                              withRadius:10];
      }

      // Tracking Id.
      if (face.hasTrackingID) {
        CGPoint point = [self scaledPoint:face.bounds.origin
                                   xScale:xScale
                                   yScale:yScale
                                   offset:videoBox.origin];
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(point.x, point.y, 100, 20)];
        label.text = [NSString stringWithFormat:@"id: %lu", (unsigned long)face.trackingID];
        [self.overlayView addSubview:label];
      }
    }
  });
}

#pragma mark - Camera setup

- (void)cleanupVideoProcessing {
  if (self.videoDataOutput) {
    [self.session removeOutput:self.videoDataOutput];
  }
  self.videoDataOutput = nil;
}

- (void)cleanupCaptureSession {
  [self.session stopRunning];
  [self cleanupVideoProcessing];
  self.session = nil;
  [self.previewLayer removeFromSuperlayer];
}

- (void)setupVideoProcessing {
  self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
  NSDictionary *rgbOutputSettings = @{
      (__bridge NSString*)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)
  };
  [self.videoDataOutput setVideoSettings:rgbOutputSettings];

  if (![self.session canAddOutput:self.videoDataOutput]) {
    [self cleanupVideoProcessing];
    NSLog(@"Failed to setup video output");
    return;
  }
  [self.videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
  [self.videoDataOutput setSampleBufferDelegate:self queue:self.videoDataOutputQueue];
  [self.session addOutput:self.videoDataOutput];
}

- (void)setupCameraPreview {
  self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
  [self.previewLayer setBackgroundColor:[[UIColor whiteColor] CGColor]];
  [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
  CALayer *rootLayer = [self.placeHolder layer];
  [rootLayer setMasksToBounds:YES];
  [self.previewLayer setFrame:[rootLayer bounds]];
  [rootLayer addSublayer:self.previewLayer];
}

- (void)updateCameraSelection {
  [self.session beginConfiguration];

  // Remove old inputs
  NSArray *oldInputs = [self.session inputs];
  for (AVCaptureInput *oldInput in oldInputs) {
    [self.session removeInput:oldInput];
  }

  AVCaptureDevicePosition desiredPosition = self.cameraSwitch.isOn ?
      AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;
  AVCaptureDeviceInput *input = [self cameraForPosition:desiredPosition];
  if (!input) {
    // Failed, restore old inputs
    for (AVCaptureInput *oldInput in oldInputs) {
      [self.session addInput:oldInput];
    }
  } else {
    // Succeeded, set input and update connection states
    [self.session addInput:input];
  }
  [self.session commitConfiguration];
}

- (AVCaptureDeviceInput *)cameraForPosition:(AVCaptureDevicePosition)desiredPosition {
  for (AVCaptureDevice *device in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
    if ([device position] == desiredPosition) {
      NSError *error = nil;
      AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device
                                                                          error:&error];
      if ([self.session canAddInput:input]) {
        return input;
      }
    }
  }
  return nil;
}

- (IBAction)cameraDeviceChanged:(id)sender {
  [self updateCameraSelection];
}

@end
