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
@import UIKit;

// Simulates the physics of motion for an iris which moves within a googly eye. The iris moves
// independently of the motion of the face/eye.
@interface EyePhysics : NSObject

// Generates the next position of the iris based on simulated velocity, eye boundaries, gravity,
// friction, and bounce momentum.
// @param eyeRect the current eye rect in parent view coordinates.
// @param irisRect the last computed iris rect.
- (CGRect)nextIrisRectFrom:(CGRect)eyeRect withIrisRect:(CGRect)irisRect;

@end
