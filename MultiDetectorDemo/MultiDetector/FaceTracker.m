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

#import "FaceTracker.h"

@interface FaceTracker ()

@property(nonatomic, strong) UIView *faceView;
@property(nonatomic, strong) UILabel *idLabel;
@property(nonatomic, strong) NSArray *colors;
@property(nonatomic, assign) NSUInteger colorIndex;

@end

@implementation FaceTracker

- (id)init {
  self = [super init];
  if (self) {
    self.colorIndex = 0;
    self.colors = @[
      [UIColor redColor],
      [UIColor orangeColor],
      [UIColor magentaColor],
      [UIColor brownColor]
    ];
  }
  return self;
}

#pragma mark - GMVOutputTrackerDelegate

- (void)dataOutput:(GMVDataOutput *)dataOutput detectedFeature:(GMVFeature *)feature {
  self.faceView = [[UIView alloc] initWithFrame:CGRectZero];
  self.faceView.backgroundColor = self.colors[self.colorIndex];
  self.faceView.alpha = 0.5;
  self.faceView.layer.cornerRadius = 25.0;
  [self.overlay addSubview:self.faceView];

  self.idLabel = [[UILabel alloc] initWithFrame:CGRectZero];
  self.idLabel.textColor = self.colors[self.colorIndex];
  [self.overlay addSubview:self.idLabel];
}

- (void)dataOutput:(GMVDataOutput *)dataOutput
    updateFocusingFeature:(GMVFaceFeature *)face
             forResultSet:(NSArray<GMVFaceFeature *> *)features {
  self.faceView.hidden = NO;
  CGFloat fx = floor(CGRectGetMinX(face.bounds) * dataOutput.xScale) + dataOutput.offset.x;
  CGFloat fy = floor(CGRectGetMinY(face.bounds) * dataOutput.yScale) + dataOutput.offset.y;
  CGFloat fwidth = floor(CGRectGetWidth(face.bounds) * dataOutput.xScale);
  CGFloat fheight = floor(CGRectGetHeight(face.bounds) * dataOutput.yScale);
  CGRect rect = CGRectMake(fx, fy, fwidth, fheight);
  self.faceView.frame = rect;

  self.idLabel.hidden = NO;
  self.idLabel.text = [NSString stringWithFormat:@"id : %lu", face.trackingID];
  self.idLabel.frame = CGRectMake(fx, fy + fheight, 200, 20);
}

- (void)dataOutput:(GMVDataOutput *)dataOutput
    updateMissingFeatures:(NSArray<GMVFaceFeature *> *)features {
  self.faceView.hidden = YES;
  self.idLabel.hidden = YES;
  self.colorIndex = (self.colorIndex + 1) % [self.colors count];
}

- (void)dataOutputCompletedWithFocusingFeature:(GMVDataOutput *)dataOutput{
  [self.faceView removeFromSuperview];
  [self.idLabel removeFromSuperview];
}

@end
