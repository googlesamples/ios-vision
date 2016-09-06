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
@import GoogleMVDataOutput;

#import "ViewController.h"
#import "FaceTracker.h"

@interface ViewController ()<GMVMultiDataOutputDelegate, FaceTrackerDatasource>

@property(nonatomic, weak) IBOutlet UIView *placeHolder;
@property(nonatomic, weak) IBOutlet UIView *overlay;

@property(nonatomic, weak) IBOutlet UISwitch *cameraSwitch;
@property(nonatomic, strong) AVCaptureSession *session;
@property(nonatomic, strong) GMVDataOutput *dataOutput;
@property(nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

@end

@implementation ViewController

#pragma mark - Life cycle methods

- (void)viewDidLoad {
  [super viewDidLoad];

  // Set up default camera settings.
  self.session = [[AVCaptureSession alloc] init];
  self.session.sessionPreset = AVCaptureSessionPresetMedium;
  self.cameraSwitch.on = YES;
  [self updateCameraSelection];

  // Set up processing pipeline.
  [self setupGMVDataOutput];

  // Set up camera preview.
  [self setupCameraPreview];
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
  self.dataOutput.previewFrameSize = self.previewLayer.frame.size;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
  return UIInterfaceOrientationMaskAll;
}

#pragma mark - GMV Pipeline Setup

- (void)setupGMVDataOutput {
  NSDictionary *options = @{
    GMVDetectorFaceTrackingEnabled : @(YES),
    GMVDetectorFaceMode : @(GMVDetectorFaceFastMode),
    GMVDetectorFaceLandmarkType : @(GMVDetectorFaceLandmarkAll),
    GMVDetectorFaceClassificationType : @(GMVDetectorFaceClassificationAll),
    GMVDetectorFaceMinSize : @(self.cameraSwitch.isOn ? 0.35 : 0.15)
  };
  GMVDetector *detector = [GMVDetector detectorOfType:GMVDetectorTypeFace options:options];

  if (self.cameraSwitch.isOn) {
    self.dataOutput = [[GMVLargestFaceFocusingDataOutput alloc] initWithDetector:detector];
    FaceTracker *tracker = [[FaceTracker alloc] init];
    tracker.delegate = self;
    ((GMVLargestFaceFocusingDataOutput *)self.dataOutput).trackerDelegate = tracker;
  } else {
    self.dataOutput = [[GMVMultiDataOutput alloc] initWithDetector:detector];
    ((GMVMultiDataOutput *)self.dataOutput).multiDataDelegate = self;
  }

  if (![self.session canAddOutput:self.dataOutput]) {
    [self cleanupGMVDataOutput];
    NSLog(@"Failed to setup video output");
    return;
  }
  [self.session addOutput:self.dataOutput];
}

- (void)cleanupGMVDataOutput {
  if (self.dataOutput) {
    [self.session removeOutput:self.dataOutput];
  }
  [self.dataOutput cleanup];
  self.dataOutput = nil;
}

- (IBAction)switchCamera:(UISwitch *)switchControl {
  [self updateCameraSelection];

  [self cleanupGMVDataOutput];
  [self setupGMVDataOutput];
}

#pragma mark - FaceTrackerDatasource

- (UIView *)overlayView {
  return self.overlay;
}

- (CGFloat)xScale {
  return self.dataOutput.xScale;
}

- (CGFloat)yScale {
  return self.dataOutput.yScale;
}

- (CGPoint)offset {
  return self.dataOutput.offset;
}


#pragma mark - GMVMultiDataOutputDelegate

- (id<GMVOutputTrackerDelegate>)dataOutput:(GMVDataOutput *)dataOutput
                         trackerForFeature:(GMVFeature *)feature {
  FaceTracker *tracker = [[FaceTracker alloc] init];
  tracker.delegate = self;
  return tracker;
}

#pragma mark - Camera setup

- (void)cleanupCaptureSession {
  [self.session stopRunning];
  [self cleanupGMVDataOutput];
  self.session = nil;
  [self.previewLayer removeFromSuperlayer];
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

  AVCaptureDevicePosition desiredPosition = self.cameraSwitch.isOn?
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
  BOOL hadError = NO;
  for (AVCaptureDevice *device in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
    if ([device position] == desiredPosition) {
      NSError *error = nil;
      AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device
                                                                          error:&error];
      if (error) {
        hadError = YES;
        NSLog(@"Could not initialize for AVMediaTypeVideo for device %@", device);
      } else if ([self.session canAddInput:input]) {
        return input;
      }
    }
  }
  if (!hadError) {
    NSLog(@"No camera found for requested orientation");
  }
  return nil;
}

@end
