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

#import "DrawingUtility.h"

@implementation DrawingUtility

+ (void)addCircleAtPoint:(CGPoint)point
                  toView:(UIView *)view
               withColor:(UIColor *)color
              withRadius:(NSInteger)width {
  CGRect circleRect = CGRectMake(point.x - width / 2, point.y - width / 2, width, width);
  UIView *circleView = [[UIView alloc] initWithFrame:circleRect];
  circleView.layer.cornerRadius = width / 2;
  circleView.alpha = 0.7;
  circleView.backgroundColor = color;
  [view addSubview:circleView];
}

+ (void)addRectangle:(CGRect)rect
              toView:(UIView *)view
           withColor:(UIColor *)color {
  UIView *newView = [[UIView alloc] initWithFrame:rect];
  newView.layer.cornerRadius = 10;
  newView.alpha = 0.3;
  newView.backgroundColor = color;
  [view addSubview:newView];
}

+ (void)addTextLabel:(NSString *)text
              atRect:(CGRect)rect
              toView:(UIView *)view
           withColor:(UIColor *)color {
  UILabel *label = [[UILabel alloc] initWithFrame:rect];
  [label setTextColor:color];
  label.text = text;
  [view addSubview:label];
}

@end
