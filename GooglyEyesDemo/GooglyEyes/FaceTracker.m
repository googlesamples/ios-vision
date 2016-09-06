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

#import "FaceTracker.h"
#import "GooglyEyeView.h"

@interface FaceTracker()

@property(nonatomic, strong) GooglyEyeView *leftEyeView;
@property(nonatomic, strong) GooglyEyeView *rightEyeView;
@property(nonatomic, assign) CGPoint lastLeftEyePosition;
@property(nonatomic, assign) CGPoint lastRightEyePosition;

@end

@implementation FaceTracker

#pragma mark - GMVOutputTrackerDelegate

- (void)dataOutput:(GMVDataOutput *)dataOutput detectedFeature:(GMVFeature *)feature {
  self.leftEyeView = [[GooglyEyeView alloc] init];
  self.rightEyeView = [[GooglyEyeView alloc] init];
  [[self.delegate overlayView] addSubview:self.leftEyeView];
  [[self.delegate overlayView] addSubview:self.rightEyeView];
}

- (void)dataOutput:(GMVDataOutput *)dataOutput
  updateFocusingFeature:(GMVFaceFeature *)face
           forResultSet:(NSArray<GMVFaceFeature *> *)features {
  self.leftEyeView.hidden = NO;
  self.rightEyeView.hidden = NO;

  // Update left eye rect.
  CGPoint newLeftEyePosition = face.hasLeftEyePosition ? face.leftEyePosition : CGPointZero;
  CGRect leftEyeRect = [self eyeRect:self.lastLeftEyePosition
                      newEyePosition:newLeftEyePosition
                            faceRect:face.bounds];
  [self.leftEyeView updateEyeRect:leftEyeRect];

  // Update right eye rect.
  CGPoint newRightEyePosition = face.hasRightEyePosition ? face.rightEyePosition : CGPointZero;
  CGRect rightEyeRect = [self eyeRect:self.lastRightEyePosition
                       newEyePosition:newRightEyePosition
                             faceRect:face.bounds];
  [self.rightEyeView updateEyeRect:rightEyeRect];

  // Remeber last known eyes positions.
  [self updateLastFaceFeature:face];
}

- (void)dataOutput:(GMVDataOutput *)dataOutput
  updateMissingFeatures:(NSArray<GMVFaceFeature *> *)features {
  self.leftEyeView.hidden = YES;
  self.rightEyeView.hidden = YES;
}

- (void)dataOutputCompletedWithFocusingFeature:(GMVDataOutput *)dataOutput{
  [self.leftEyeView removeFromSuperview];
  [self.rightEyeView removeFromSuperview];
}

#pragma mark - Helper methods

- (CGRect)scaledRect:(CGRect)rect
              xScale:(CGFloat)xscale
              yScale:(CGFloat)yscale
              offset:(CGPoint)offset {

  CGRect resultRect = CGRectMake(floor(rect.origin.x * xscale),
                                 floor(rect.origin.y * yscale),
                                 floor(rect.size.width * xscale),
                                 floor(rect.size.height * yscale));
  resultRect = CGRectOffset(resultRect, offset.x, offset.y);
  return resultRect;
}

- (CGRect)eyeRect:(CGPoint)lastEyePosition
   newEyePosition:(CGPoint)newEyePosition
         faceRect:(CGRect)faceRect {
  CGPoint eye = lastEyePosition;
  if (!CGPointEqualToPoint(newEyePosition, CGPointZero)) {
    eye = newEyePosition;
  }

  CGFloat faceToEyeRatio = 4.0;
  CGFloat width = faceRect.size.width / faceToEyeRatio;
  CGRect rect = CGRectMake(eye.x - width / 2,
                           eye.y - width / 2,
                           width,
                           width);
  rect = [self scaledRect:rect
                   xScale:[self.delegate xScale]
                   yScale:[self.delegate yScale]
                   offset:[self.delegate offset]];
  return rect;
}

- (void)updateLastFaceFeature:(GMVFaceFeature *)feature {
  if (feature.hasLeftEyePosition) {
    self.lastLeftEyePosition = feature.leftEyePosition;
  }
  if (feature.hasRightEyePosition) {
    self.lastRightEyePosition = feature.rightEyePosition;
  }
}

@end
