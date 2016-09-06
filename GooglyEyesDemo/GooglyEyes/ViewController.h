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

// Main view conroller for Googly Eyes, an app that uses the camera to track faces and
// superimpose Googly Eyes animated graphics over the eyes.
//
// The app supports both a front facing mode and a rear facing mode, which demonstrate different
// API functionality trade-offs:
//
// Front facing mode uses the device's front facing camera to track one user, in a "selfie" fashion.
// The settings for the face detector and its associated processing pipeline are set to optimize for
// the single face case, where the face is relatively large.  These factors allow the face detector
// to be faster and more responsive to quick motion.
//
// Rear facing mode uses the device's rear facing camera to track any number of faces.  The settings
// for the face detector and its associated processing pipeline support finding multiple faces, and
// attempt to find smaller faces in comparison to the front facing mode.  But since this requires
// more scanning at finer levels of detail, rear facing mode may not be as responsive as front
// facing mode.
@interface ViewController : UIViewController

@end

