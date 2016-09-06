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

@import GoogleMobileVision;

#import "PhotoViewController.h"
#import "DrawingUtility.h"

@interface PhotoViewController ()

// UI views.
@property(nonatomic, weak) IBOutlet UIImageView *faceImageView;
@property(nonatomic, weak) IBOutlet UIView *overlayView;

// Face detector.
@property(nonatomic, strong) GMVDetector *faceDetector;

@end

@implementation PhotoViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  // Instantiate a face detector that searches for all landmarks and classifications.
  NSDictionary *options = @{
    GMVDetectorFaceLandmarkType : @(GMVDetectorFaceLandmarkAll),
    GMVDetectorFaceClassificationType : @(GMVDetectorFaceClassificationAll),
    GMVDetectorFaceMinSize : @(0.3),
    GMVDetectorFaceTrackingEnabled : @(NO)
  };
  self.faceDetector = [GMVDetector detectorOfType:GMVDetectorTypeFace options:options];
}

- (IBAction)faceRecognitionClicked:(id)sender {
  for (UIView *annotationView in [self.overlayView subviews]) {
    [annotationView removeFromSuperview];
  }

  // Invoke features detection.
  NSArray<GMVFaceFeature *> *faces = [self.faceDetector featuresInImage:self.faceImageView.image
                                                                options:nil];

  // Compute image offset.
  CGAffineTransform translate = CGAffineTransformTranslate(CGAffineTransformIdentity,
      (self.view.frame.size.width - self.faceImageView.image.size.width) / 2,
      (self.view.frame.size.height - self.faceImageView.image.size.height) / 2);

  // Add annotation view for each detected face.
  for (GMVFaceFeature *face in faces) {
    // Face
    CGRect rect = face.bounds;
    [DrawingUtility addRectangle:CGRectApplyAffineTransform(rect, translate)
                          toView:self.overlayView
                       withColor:[UIColor redColor]];

    // Mouth
    if (face.hasBottomMouthPosition) {
      CGPoint point = CGPointApplyAffineTransform(face.bottomMouthPosition, translate);
      [DrawingUtility addCircleAtPoint:point
                                toView:self.overlayView
                             withColor:[UIColor greenColor]
                            withRadius:2];
    }
    if (face.hasMouthPosition) {
      [DrawingUtility addCircleAtPoint:CGPointApplyAffineTransform(face.mouthPosition, translate)
                                toView:self.overlayView
                             withColor:[UIColor greenColor]
                            withRadius:2];
    }
    if (face.hasRightMouthPosition) {
      CGPoint point = CGPointApplyAffineTransform(face.rightMouthPosition, translate);
      [DrawingUtility addCircleAtPoint:point
                                toView:self.overlayView
                             withColor:[UIColor greenColor]
                            withRadius:2];
    }
    if (face.hasLeftMouthPosition) {
      CGPoint point = CGPointApplyAffineTransform(face.leftMouthPosition, translate);
      [DrawingUtility addCircleAtPoint:point
                                toView:self.overlayView
                             withColor:[UIColor greenColor]
                            withRadius:2];
    }

    // Nose
    if (face.hasNoseBasePosition) {
      [DrawingUtility addCircleAtPoint:CGPointApplyAffineTransform(face.noseBasePosition, translate)
                                toView:self.overlayView
                             withColor:[UIColor darkGrayColor]
                            withRadius:4];
    }

    // Eyes
    if (face.hasLeftEyePosition) {
      [DrawingUtility addCircleAtPoint:CGPointApplyAffineTransform(face.leftEyePosition, translate)
                                toView:self.overlayView
                             withColor:[UIColor blueColor]
                            withRadius:4];
    }
    if (face.hasRightEyePosition) {
      [DrawingUtility addCircleAtPoint:CGPointApplyAffineTransform(face.rightEyePosition, translate)
                                toView:self.overlayView
                             withColor:[UIColor blueColor]
                            withRadius:4];
    }

    // Ears
    if (face.hasLeftEarPosition) {
      [DrawingUtility addCircleAtPoint:CGPointApplyAffineTransform(face.leftEarPosition, translate)
                                toView:self.overlayView
                             withColor:[UIColor purpleColor]
                            withRadius:4];
    }
    if (face.hasRightEarPosition) {
      [DrawingUtility addCircleAtPoint:CGPointApplyAffineTransform(face.rightEarPosition, translate)
                                toView:self.overlayView
                             withColor:[UIColor purpleColor]
                            withRadius:4];
    }

    // Cheeks
    if (face.hasLeftCheekPosition) {
      CGPoint point = CGPointApplyAffineTransform(face.leftCheekPosition, translate);
      [DrawingUtility addCircleAtPoint:point
                                toView:self.overlayView
                             withColor:[UIColor magentaColor]
                            withRadius:4];
    }
    if (face.hasRightCheekPosition) {
      CGPoint point = CGPointApplyAffineTransform(face.rightCheekPosition, translate);
      [DrawingUtility addCircleAtPoint:point
                                toView:self.overlayView
                             withColor:[UIColor magentaColor]
                            withRadius:4];
    }

    // Smiling
    if (face.hasSmilingProbability && face.smilingProbability > 0.4) {
      NSString *text = [NSString stringWithFormat:@"smiling %0.2f", face.smilingProbability];
      CGRect rect = CGRectMake(CGRectGetMinX(face.bounds),
                               CGRectGetMaxY(face.bounds) + 10,
                               self.overlayView.frame.size.width,
                               30);
      rect = CGRectApplyAffineTransform(rect, translate);
      [DrawingUtility addTextLabel:text
                            atRect:rect
                            toView:self.overlayView
                         withColor:[UIColor greenColor]];

    }
  }

}

@end
