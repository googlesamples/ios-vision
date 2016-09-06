# iOS Vision API Samples

At this time, these samples demonstrate the vision API for detecting faces.

## A note on CocoaPods

The Google Mobile Vision iOS SDK and related samples are distributed through CocoaPods.
Set up CocoaPods by going to cocoapods.org and following the directions.

## Try the sample apps

After installing CocoaPods, run the command `pod try GoogleMobileVision` from Terminal
to open up any example projects for the library. There are 2 sample apps available:

* FaceDetectorDemo: This demo demonstrates basic face detection and integration with
AVFoundation. The app highlights face, eyes, nose, mouth, cheeks, and ears within detected faces.

* GooglyEyesDemo: This demo demonstrates how to use  the `GoogleMVDataOutput` pod to simplify
integration with the video pipeline. The app draws cartoon eyes on top of detected faces.

If you want to try the samples from the github source code. Do the following:

- Run the command `pod install` from Terminal in the folder that contains the Podfile. This will
  download the required dependencies.
- Launch the [Project Name].xcworkspace. This will open the sample app with xcode.


## Support

For General questions and discussion on StackOverflow:
- Stack Overflow: http://stackoverflow.com/questions/tagged/google-ios-vision

If you've found an error in this sample, please file an issue:
https://github.com/googlesamples/ios-vision/issues

Patches are encouraged, and may be submitted by forking this project and
submitting a pull request through GitHub.

License
-------

Copyright 2016 Google, Inc. All Rights Reserved.

Licensed to the Apache Software Foundation (ASF) under one or more contributor
license agreements.  See the NOTICE file distributed with this work for
additional information regarding copyright ownership.  The ASF licenses this
file to you under the Apache License, Version 2.0 (the "License"); you may not
use this file except in compliance with the License.  You may obtain a copy of
the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
License for the specific language governing permissions and limitations under
the License.

