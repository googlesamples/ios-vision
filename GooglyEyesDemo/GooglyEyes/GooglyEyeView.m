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

@import QuartzCore;

#import "GooglyEyeView.h"
#import "EyePhysics.h"

@interface GooglyEyeView ()

@property(nonatomic, strong) EyePhysics *physics;
@property(nonatomic, assign) CGRect irisRect;

@end

@implementation GooglyEyeView

- (instancetype)init {
  self = [super init];
  if (self) {
    self.physics = [[EyePhysics alloc] init];
    self.irisRect = CGRectZero;
    self.opaque = NO;
    self.backgroundColor = [UIColor whiteColor];
    self.layer.borderColor = [UIColor blackColor].CGColor;
    self.layer.borderWidth = 4;
    self.layer.masksToBounds = YES;
  }
  return self;
}

- (void)updateEyeRect:(CGRect)eyeRect {
  self.frame = eyeRect;
  self.layer.cornerRadius = self.frame.size.height / 2;
  [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
  self.irisRect = [self.physics nextIrisRectFrom:self.frame withIrisRect:self.irisRect];
  CGRect iris = [self.superview convertRect:self.irisRect toView:self];
  [[UIColor blackColor] setFill];
  UIBezierPath *irisPath = [UIBezierPath bezierPathWithOvalInRect:iris];
  [irisPath fill];
}

@end
