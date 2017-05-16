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

#import "DrawingUtility.h"

@implementation DrawingUtility

+ (void)addRectangle:(CGRect)rect
              toView:(UIView *)view
           withColor:(UIColor *)color {
  UIView *newView = [[UIView alloc] initWithFrame:rect];
  newView.layer.cornerRadius = 10;
  newView.alpha = 0.3;
  newView.backgroundColor = color;
  [view addSubview:newView];
}

+ (void)addShape:(NSArray *)points
          toView:(UIView *)view
       withColor:(UIColor *)color {
  UIBezierPath *path = [[UIBezierPath alloc] init];
  for (int i = 0; i < points.count; i++) {
    CGPoint point = [points[i] CGPointValue];

    if (i == 0) {
      [path moveToPoint:point];
    } else {
      [path addLineToPoint:point];
    }

    if (i == [points count] - 1)  {
      [path closePath];
    }
  }

  CAShapeLayer *shapeLayer = [CAShapeLayer layer];
  shapeLayer.path = path.CGPath;
  shapeLayer.fillColor = color.CGColor;

  CGRect rect = CGRectMake(0, 0, view.frame.size.width, view.frame.size.height);
  UIView *newView = [[UIView alloc] initWithFrame:rect];
  newView.alpha = 0.3;
  [newView.layer addSublayer:shapeLayer];
  newView.backgroundColor = [UIColor clearColor];
  [view addSubview:newView];
}

@end
