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

#import "EyePhysics.h"

CGFloat const kFriction = 2.2;
CGFloat const kGravity = 10;
CGFloat const kBounceMultiplier = 20;
CGFloat const kZeroTolerance = 0.001;
CGFloat const kIrisRatio = 0.45;

@interface EyePhysics()

@property(nonatomic, strong) NSDate *lastUpdated;
@property(nonatomic, assign) CGFloat xVelocity;
@property(nonatomic, assign) CGFloat yVelocity;
@property(nonatomic, assign) NSUInteger consecutiveBounces;

@end

@implementation EyePhysics

- (instancetype)init {
  self = [super init];
  if (self) {
    self.lastUpdated = [NSDate date];
  }
  return self;
}

// Generate the next position of the iris based on simulated velocity, eye boundaries, gravity,
// friction, and bounce momentum. This is independent from face/eye motion.
- (CGRect)nextIrisRectFrom:(CGRect)eyeRect withIrisRect:(CGRect)irisRect {

  NSDate *now = [NSDate date];
  NSTimeInterval elapsed = [now timeIntervalSinceDate:self.lastUpdated];
  self.lastUpdated = now;
  CGFloat irisRadius = eyeRect.size.width * kIrisRatio / 2;

  if (CGRectIsNull(irisRect) || CGRectIsEmpty(irisRect) || CGRectIsInfinite(irisRect)) {
    // Initialize eyeball at the top of the eye.
    irisRect = CGRectMake(CGRectGetMidX(eyeRect) - irisRadius,
                          eyeRect.origin.y,
                          irisRadius * 2,
                          irisRadius * 2);
  }

  if (![self isStopped:eyeRect irisRect:irisRect]) {
    // Only apply gravity when the iris is not stopped at the bottom of the eye.
    self.yVelocity += kGravity * elapsed;
  }

  // Apply friction in the opposite direction of motion, so that the iris slows in the absence
  // of other head motion.
  self.xVelocity = [self applyFriction:self.xVelocity simulationRate:elapsed];
  self.yVelocity = [self applyFriction:self.yVelocity simulationRate:elapsed];

  // Update iris rect based on velocity.
  CGFloat irisX = irisRect.origin.x + (self.xVelocity * irisRadius * elapsed);
  CGFloat irisY = irisRect.origin.y + (self.yVelocity * irisRadius * elapsed);

  CGRect nextIris = CGRectMake(irisX, irisY, irisRect.size.width, irisRect.size.height);
  nextIris = [self makeIris:nextIris inEyeBounds:eyeRect simulationRate:elapsed];

  return nextIris;
}

// The iris is stopped if it is at the bottom of the eye and its velocity is zero.
- (BOOL)isStopped:(CGRect)eyeRect irisRect:(CGRect)irisRect {
  if (CGRectContainsRect(eyeRect, irisRect)) {
    return false;
  }
  CGFloat offsetY = CGRectGetMaxY(irisRect) - CGRectGetMaxY(eyeRect);
  CGFloat maxDistance = (eyeRect.size.height - irisRect.size.height) / 2;
  if (offsetY < maxDistance) {
    return false;
  }
  return [self isZero:self.xVelocity] && [self isZero:self.yVelocity];
}

- (BOOL)isZero:(CGFloat)number {
  return isnan(number) || (number < kZeroTolerance && number > -kZeroTolerance);
}

// Friction slows velocity in the opposite direction of motion, until zero velocity is reached.
- (CGFloat)applyFriction:(CGFloat)velocity simulationRate:(NSTimeInterval)elapsed {
  if ([self isZero:velocity]) {
    velocity = 0;
  } else if (velocity > 0) {
    velocity = fmaxf(0, velocity - kFriction * elapsed);
  } else {
    velocity = fminf(0, velocity + kFriction * elapsed);
  }
  return velocity;
}

// Correct the iris position to be in-bounds within the eye, if it is now out of bounds.  Being
// out of bounds could have been due to a sudden movement of the head and/or camera, or the
// result of just bouncing/rolling around.
// In addition, modify the velocity to cause a bounce in the opposite direction.
- (CGRect)makeIris:(CGRect)nextIrisRect
       inEyeBounds:(CGRect)eyeRect
    simulationRate:(NSTimeInterval)elapsed {

  if (CGRectContainsRect(eyeRect, nextIrisRect)) {
    self.consecutiveBounces = 0;
    return nextIrisRect;
  }

  // Accumulate a consecutive bounce count to aid for velocity calculation.
  self.consecutiveBounces++;

  // Move the iris back to where it would have been when it would have contacted the side of
  // the eye.
  CGPoint newOrigin = nextIrisRect.origin;
  CGRect intersectRect = CGRectIntersection(eyeRect, nextIrisRect);
  if (!CGRectIsNull(intersectRect)) {
    // Handle overlapping case.
    newOrigin.x += (intersectRect.origin.x <= nextIrisRect.origin.x ? -1 : 1) *
        (nextIrisRect.size.width - intersectRect.size.width);
    newOrigin.y += (intersectRect.origin.y > eyeRect.origin.y ? -1 : 1) *
        (nextIrisRect.size.height - intersectRect.size.height);
  } else {
    // Handle not overlapping case.
    if (nextIrisRect.origin.x < eyeRect.origin.x) {
      // Iris to the left of the eye.
      newOrigin.x = eyeRect.origin.x;
    } else {
      // Iris to the right of the eye.
      newOrigin.x = eyeRect.origin.x + eyeRect.size.width - nextIrisRect.size.width;
    }
    if (nextIrisRect.origin.y < eyeRect.origin.y) {
      // Iris to the top of the eye.
      newOrigin.y = eyeRect.origin.y;
    } else {
      // Iris to the bottom of the eye.
      newOrigin.y = eyeRect.origin.y + eyeRect.size.height - nextIrisRect.size.height;
    }
  }

  // Update the velocity direction and magnitude to cause a bounce.
  CGFloat dx = newOrigin.x - nextIrisRect.origin.x;
  self.xVelocity = [self applyBounce:self.xVelocity
                     distanceOutBound:dx
                       simulationRate:elapsed
                             irisRect:nextIrisRect] / self.consecutiveBounces;
  CGFloat dy = newOrigin.y - nextIrisRect.origin.y;
  self.yVelocity = [self applyBounce:self.yVelocity
                    distanceOutBound:dy
                      simulationRate:elapsed
                            irisRect:nextIrisRect] / self.consecutiveBounces;
  return CGRectMake(newOrigin.x, newOrigin.y, nextIrisRect.size.width, nextIrisRect.size.height);
}

- (CGFloat)applyBounce:(CGFloat)velocity
      distanceOutBound:(CGFloat)distance
        simulationRate:(NSTimeInterval)elapsed
              irisRect:(CGRect)irisRect {
  if ([self isZero:distance]) {
    return velocity;
  }
  velocity *= -1;

  CGFloat bounce = kBounceMultiplier * fabs(distance / irisRect.size.width / 2);
  if (velocity > 0) {
    velocity += bounce * elapsed;
  } else {
    velocity -= bounce * elapsed;
  }
  return velocity;
}

@end
