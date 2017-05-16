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
@import GoogleMobileVision;

#import "CameraViewController.h"
#import "DrawingUtility.h"


@interface CameraViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>

@property(nonatomic, weak) IBOutlet UIView *placeHolderView;
@property(nonatomic, weak) IBOutlet UIView *overlayView;

@property(nonatomic, strong) AVCaptureSession *session;
@property(nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
@property(nonatomic, strong) dispatch_queue_t videoDataOutputQueue;
@property(nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property(nonatomic, assign) UIDeviceOrientation lastKnownDeviceOrientation;

@property(nonatomic, strong) GMVDetector *barcodeDetector;

@end

@implementation CameraViewController

- (id)initWithCoder:(NSCoder *)aDecoder {
  self = [super initWithCoder:aDecoder];
  if (self) {
    _videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue",
        DISPATCH_QUEUE_SERIAL);
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  // Set up default camera settings.
  self.session = [[AVCaptureSession alloc] init];
  self.session.sessionPreset = AVCaptureSessionPresetMedium;
  [self updateCameraSelection];

  // Set up video processing pipeline.
  [self setUpVideoProcessing];

  // Set up camera preview.
  [self setUpCameraPreview];

  // Initialize barcode detector.
  self.barcodeDetector = [GMVDetector detectorOfType:GMVDetectorTypeBarcode options:nil];
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

- (CGRect)scaleRect:(CGRect)rect
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

- (CGPoint)scalePoint:(CGPoint)point
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

- (void)computeCameraDisplayFrameScaleProperties:(CMSampleBufferRef)sampleBuffer
                                previewFrameSize:(CGSize)previewFrameSize
                                          yScale:(CGFloat *)previewYScale
                                          xScale:(CGFloat *)previewXScale
                                          offset:(CGPoint *)previewOffset {
  // The video frames captured by the camera have different size than video preview.
  // Calculates the scale factors and offset to properly display the features.
  CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
  CGRect cleanAperture = CMVideoFormatDescriptionGetCleanAperture(formatDescription, false);
  CGSize parentFrameSize;
  if (CGSizeEqualToSize(previewFrameSize, CGSizeZero)) {
    parentFrameSize = [[UIScreen mainScreen] bounds].size;
  } else {
    parentFrameSize = previewFrameSize;
  }

  // Assumes AVLayerVideoGravityResizeAspect
  CGFloat cameraRatio = cleanAperture.size.height / cleanAperture.size.width;
  CGFloat viewRatio = parentFrameSize.width / parentFrameSize.height;
  CGFloat xScale = 1;
  CGFloat yScale = 1;
  CGRect videoBox = CGRectZero;
  if (viewRatio > cameraRatio) {
    videoBox.size.width = parentFrameSize.height * cleanAperture.size.width /
        cleanAperture.size.height;
    videoBox.size.height = parentFrameSize.height;
    videoBox.origin.x = (parentFrameSize.width - videoBox.size.width) / 2;
    videoBox.origin.y = (videoBox.size.height - parentFrameSize.height) / 2;

    xScale = videoBox.size.width / cleanAperture.size.width;
    yScale = videoBox.size.height / cleanAperture.size.height;
  } else {
    videoBox.size.width = parentFrameSize.width;
    videoBox.size.height = cleanAperture.size.width *
        (parentFrameSize.width / cleanAperture.size.height);
    videoBox.origin.x = (videoBox.size.width - parentFrameSize.width) / 2;
    videoBox.origin.y = (parentFrameSize.height - videoBox.size.height) / 2;

    xScale = videoBox.size.width / cleanAperture.size.height;
    yScale = videoBox.size.height / cleanAperture.size.width;
  }
  *previewYScale = yScale;
  *previewXScale = xScale;
  *previewOffset = videoBox.origin;
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput
    didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {

  UIImage *image = [GMVUtility sampleBufferTo32RGBA:sampleBuffer];
  AVCaptureDevicePosition devicePosition = AVCaptureDevicePositionBack;

  // Establish the image orientation and detect features using GMVDetector.
  UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
  GMVImageOrientation orientation = [GMVUtility
      imageOrientationFromOrientation:deviceOrientation
            withCaptureDevicePosition:devicePosition
             defaultDeviceOrientation:self.lastKnownDeviceOrientation];
  NSDictionary *options = @{
    GMVDetectorImageOrientation : @(orientation)
  };

  NSArray<GMVBarcodeFeature *> *barcodes = [self.barcodeDetector featuresInImage:image
                                                                         options:options];
  NSLog(@"Detected %lu barcodes.", (unsigned long)barcodes.count);

  // The video frames captured by the camera are a different size than the video preview.
  // Calculates the scale factors and offset to properly display the features.
  CGFloat yScale = 1;
  CGFloat xScale = 1;
  CGPoint offset = CGPointZero;

  [self computeCameraDisplayFrameScaleProperties:sampleBuffer
                                previewFrameSize:self.previewLayer.frame.size
                                          yScale:&yScale
                                          xScale:&xScale
                                          offset:&offset];

  dispatch_sync(dispatch_get_main_queue(), ^{
    // Remove previously added feature
    for (UIView *featureview in self.overlayView.subviews) {
      [featureview removeFromSuperview];
    }

    // Display detected features in overlay.
    for (GMVBarcodeFeature *barcode in barcodes) {
      CGPoint p0 = [self scalePoint:barcode.cornerPoints[0].CGPointValue
                             xScale:xScale
                             yScale:yScale
                             offset:offset];
      CGPoint p1 = [self scalePoint:barcode.cornerPoints[1].CGPointValue
                             xScale:xScale
                             yScale:yScale
                             offset:offset];
      CGPoint p2 = [self scalePoint:barcode.cornerPoints[2].CGPointValue
                             xScale:xScale
                             yScale:yScale
                             offset:offset];
      CGPoint p3 = [self scalePoint:barcode.cornerPoints[3].CGPointValue
                             xScale:xScale
                             yScale:yScale
                             offset:offset];
      NSArray *points = @[[NSValue valueWithCGPoint:p0], [NSValue valueWithCGPoint:p1],
                          [NSValue valueWithCGPoint:p2], [NSValue valueWithCGPoint:p3]];
      [DrawingUtility addShape:points toView:self.overlayView withColor:[UIColor purpleColor]];

      CGRect textRect = CGRectMake(p0.x, p3.y, barcode.bounds.size.width, 50);
      UILabel *label = [[UILabel alloc] initWithFrame:textRect];
      label.text = barcode.rawValue;
      [self.overlayView addSubview:label];
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

- (void)setUpVideoProcessing {
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

- (void)setUpCameraPreview {
  self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
  [self.previewLayer setBackgroundColor:[UIColor whiteColor].CGColor];
  [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
  CALayer *rootLayer = self.placeHolderView.layer;
  rootLayer.masksToBounds = YES;
  [self.previewLayer setFrame:rootLayer.bounds];
  [rootLayer addSublayer:self.previewLayer];
}

- (void)updateCameraSelection {
  [self.session beginConfiguration];

  // Remove old inputs
  NSArray *oldInputs = [self.session inputs];
  for (AVCaptureInput *oldInput in oldInputs) {
    [self.session removeInput:oldInput];
  }

  AVCaptureDevicePosition desiredPosition = AVCaptureDevicePositionBack;
  AVCaptureDeviceInput *input = [self captureDeviceInputForPosition:desiredPosition];
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

- (AVCaptureDeviceInput *)captureDeviceInputForPosition:(AVCaptureDevicePosition)desiredPosition {
  for (AVCaptureDevice *device in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
    if (device.position == desiredPosition) {
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
