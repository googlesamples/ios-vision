/*
 Copyright 2017 Google Inc.

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
@import GoogleMVDataOutput;

#import "ViewController.h"

#import "BarcodeTracker.h"
#import "FaceTracker.h"

@interface ViewController ()<GMVMultiDetectorDataOutputDelegate>

@property(nonatomic, weak) IBOutlet UIView *preview;
@property(nonatomic, weak) IBOutlet UIView *overlay;

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
  NSDictionary *faceOptions = @{
    GMVDetectorFaceTrackingEnabled : @(YES),
    GMVDetectorFaceMinSize : @(0.15)
  };
  GMVDetector *faceDetector = [GMVDetector detectorOfType:GMVDetectorTypeFace options:faceOptions];
  GMVDetector *barcodeDetector = [GMVDetector detectorOfType:GMVDetectorTypeBarcode options:nil];
  NSArray *detectors = @[faceDetector, barcodeDetector];
  self.dataOutput = [[GMVMultiDetectorDataOutput alloc] initWithDetectors:detectors];
  ((GMVMultiDetectorDataOutput *)self.dataOutput).multiDetectorDataDelegate = self;

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

#pragma mark - FaceTrackerDelegate

- (UIView *)overlayView {
  return self.overlay;
}

#pragma mark - GMVMultiDetectorDataOutputDelegate

- (id<GMVOutputTrackerDelegate>)dataOutput:(GMVDataOutput *)dataOutput
                              fromDetector:(GMVDetector *)detector
                         trackerForFeature:(GMVFeature *)feature {
  if ([feature.type isEqualToString:GMVFeatureTypeFace]) {
    FaceTracker *tracker = [[FaceTracker alloc] init];
    tracker.overlay = self.view;
    return tracker;
  } else if ([feature.type isEqualToString:GMVFeatureTypeBarcode]) {
    BarcodeTracker *tracker = [[BarcodeTracker alloc] init];
    tracker.overlay = self.view;
    return tracker;
  }
  return nil;
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
  CALayer *rootLayer = [self.preview layer];
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

  AVCaptureDeviceInput *input = [self cameraForPosition:AVCaptureDevicePositionBack];
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
      if (error) {
        NSLog(@"Could not initialize for AVMediaTypeVideo for device %@", device);
      } else if ([self.session canAddInput:input]) {
        return input;
      }
    }
  }
  return nil;
}

@end
