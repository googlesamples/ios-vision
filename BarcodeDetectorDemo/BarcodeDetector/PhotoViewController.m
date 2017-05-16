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

@import GoogleMobileVision;

#import "DrawingUtility.h"
#import "PhotoViewController.h"

@interface PhotoViewController ()

@property(nonatomic, weak) IBOutlet UIView *overlayView;
@property(nonatomic, weak) IBOutlet UIImageView *imageView;

@property(nonatomic, strong) GMVDetector *barcodeDetector;

@end

@implementation PhotoViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  NSDictionary *options = @{
    GMVDetectorBarcodeFormats : @(GMVDetectorBarcodeFormatQRCode | GMVDetectorBarcodeFormatAztec)
  };

  // Initialize a barcode detector.
  self.barcodeDetector = [GMVDetector detectorOfType:GMVDetectorTypeBarcode options:options];
}

- (IBAction)detectBarcodeButtonTapped:(id)sender {
  for (UIView *annotationView in [self.overlayView subviews]) {
    [annotationView removeFromSuperview];
  }

  NSArray<GMVBarcodeFeature *> *barcodes =
      [self.barcodeDetector featuresInImage:self.imageView.image options:nil];

  CGAffineTransform translate = CGAffineTransformTranslate(CGAffineTransformIdentity,
      (self.view.frame.size.width - self.imageView.image.size.width) / 2,
      (self.view.frame.size.height - self.imageView.image.size.height) / 2);

  for (GMVBarcodeFeature *barcode in barcodes) {
    CGRect rect = barcode.bounds;
    [DrawingUtility addRectangle:CGRectApplyAffineTransform(rect, translate)
                          toView:self.overlayView
                       withColor:[UIColor purpleColor]];
  }
}

@end
