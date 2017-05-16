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

@import Foundation;
@import GoogleMVDataOutput;

// The data source provides the FaceTracker object with the information it needs to display
// superimposed googly eyes.
@protocol FaceTrackerDatasource<NSObject>

// Display scaling offset.
- (CGFloat)xScale;
- (CGFloat)yScale;
- (CGPoint)offset;

// View to display googly eyes.
- (UIView *)overlayView;

@end

// Manages GooglyEyeViews. This class implements GMVOutputTrackerDelegate to receive
// face and landmarks tracking notifications. It updates the GooglyEyeViews' positions and
// sizes accordingly.
@interface FaceTracker : NSObject<GMVOutputTrackerDelegate>

@property(nonatomic, weak) id<FaceTrackerDatasource> delegate;

@end
