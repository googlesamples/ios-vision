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

#import "BarcodeTracker.h"

@interface BarcodeTracker ()

@property(nonatomic, strong) UIView *barcodeView;
@property(nonatomic, strong) UILabel *valueLabel;
@property(nonatomic, strong) NSArray<UIColor *> *colors;
@property(nonatomic, assign) NSUInteger colorIndex;

@end

@implementation BarcodeTracker

- (id)init {
  self = [super init];
  if (self) {
    self.colorIndex = 0;
    self.colors = @[
      [UIColor blueColor],
      [UIColor cyanColor],
      [UIColor greenColor],
      [UIColor purpleColor]
    ];
  }
  return self;
}

#pragma mark - GMVOutputTrackerDelegate

- (void)dataOutput:(GMVDataOutput *)dataOutput detectedFeature:(GMVFeature *)feature {
  self.barcodeView = [[UIView alloc] initWithFrame:CGRectZero];
  self.barcodeView.backgroundColor = self.colors[self.colorIndex];
  self.barcodeView.alpha = 0.5;
  [self.overlay addSubview:self.barcodeView];

  self.valueLabel = [[UILabel alloc] initWithFrame:CGRectZero];
  self.valueLabel.textColor = self.colors[self.colorIndex];
  [self.overlay addSubview:self.valueLabel];
}

- (void)dataOutput:(GMVDataOutput *)dataOutput
    updateFocusingFeature:(GMVBarcodeFeature *)barcode
      forResultSet:(NSArray<GMVBarcodeFeature *> *)features {
  self.barcodeView.hidden = NO;
  CGRect rect = CGRectMake(floor(barcode.bounds.origin.x * dataOutput.xScale) + dataOutput.offset.x,
                           floor(barcode.bounds.origin.y * dataOutput.yScale) + dataOutput.offset.y,
                           floor(barcode.bounds.size.width * dataOutput.xScale),
                           floor(barcode.bounds.size.height * dataOutput.yScale));
  self.barcodeView.frame = rect;

  self.valueLabel.hidden = NO;
  self.valueLabel.text = barcode.rawValue;
  self.valueLabel.frame = CGRectMake(rect.origin.x, rect.origin.y + rect.size.height, 200, 20);
}

- (void)dataOutput:(GMVDataOutput *)dataOutput
    updateMissingFeatures:(NSArray<GMVFaceFeature *> *)features {
  self.barcodeView.hidden = YES;
  self.valueLabel.hidden = YES;
  self.colorIndex = (self.colorIndex + 1) % self.colors.count;
}

- (void)dataOutputCompletedWithFocusingFeature:(GMVDataOutput *)dataOutput{
  [self.barcodeView removeFromSuperview];
  [self.valueLabel removeFromSuperview];
}

@end
