# Ported from Jolt by almic

# Jolt Physics Library (https://github.com/jrouwe/JoltPhysics)
# SPDX-FileCopyrightText: 2021 Jorrit Rouwe
# SPDX-License-Identifier: MIT

## Constraint that simulates a vehicle
##
## When the vehicle drives over very light objects (rubble) you may see the car body dip down. This is a known issue and is an artifact of the iterative solver that Jolt is using.
## Basically if a light object is sandwiched between two heavy objects (the static floor and the car body), the light object is not able to transfer enough force from the ground to
## the car body to keep the car body up. You can see this effect in the HeavyOnLightTest sample, the boxes on the right have a lot of penetration because they're on top of light objects.
##
## There are a couple of ways to improve this:
##
## 1. You can increase the number of velocity steps (global settings PhysicsSettings::mNumVelocitySteps or if you only want to increase it on
##    the vehicle you can use VehicleConstraintSettings::mNumVelocityStepsOverride). E.g. going from 10 to 30 steps in the HeavyOnLightTest sample makes the penetration a lot less.
##    The number of position steps can also be increased (the first prevents the body from going down, the second corrects it if the problem did
##    occur which inevitably happens due to numerical drift). This solution costs CPU cycles.
##
## 2. You can reduce the mass difference between the vehicle body and the rubble on the floor (by making the rubble heavier or the car lighter).
##
## 3. You could filter out collisions between the vehicle collision test and the rubble completely. This would make the wheels ignore the rubble but would cause the vehicle to drive
## through it as if nothing happened. You could create fake wheels (keyframed bodies) that move along with the vehicle and that only collide with rubble (and not the vehicle or the ground).
## This would cause the vehicle to push away the rubble without the rubble being able to affect the vehicle (unless it hits the main body of course).
##
## Note that when driving over rubble, you may see the wheel jump up and down quite quickly because one frame a collision is found and the next frame not.
## To alleviate this, it may be needed to smooth the motion of the visual mesh for the wheel.
@tool
class_name VehicleBase extends RigidBody3D


## If the gravity is currently overridden
var mIsGravityOverridden: bool = false

## Gravity override value, replaces PhysicsSystem::GetGravity() when mIsGravityOverridden is true
var mGravityOverride: Vector3 = Vector3.ZERO

## Local space forward vector for the vehicle
var mForward: Vector3

## Local space up vector for the vehicle
var mUp: Vector3

## Vector indicating the world space up direction (used to limit vehicle pitch/roll)
var mWorldUp: Vector3

## Wheel states of the vehicle
var mWheels: Array[Wheel]

## Anti rollbars of the vehicle
var mAntiRollBars: Array[AntiRollBar]

## Controls the acceleration / deceleration of the vehicle
var mController: VehicleController

## If this constraint is active
var mIsActive: bool = false

## Number of simulation steps between wheel collision tests when the vehicle is active
var mNumStepsBetweenCollisionTestActive: int = 1

## Number of simulation steps between wheel collision tests when the vehicle is inactive
var mNumStepsBetweenCollisionTestInactive: int = 1

## Current step number, used to determine when to test a wheel
var mCurrentStep: int = 0


# Prevent vehicle from toppling over

## Cos of the max pitch/roll angle
var mCosMaxPitchRollAngle: float

## Cos of the current pitch/roll angle
var mCosPitchRollAngle: float

## Current axis along which to apply torque to prevent the car from toppling over
var mPitchRollRotationAxis: Vector3 = Vector3.UP

 ## Constraint part that prevents the car from toppling over
var mPitchRollPart: AngleConstraintPart


# Callbacks

@warning_ignore('unused_parameter')
func _combine_friction(
        inWheelIndex: int,
        ioLongitudinalFriction: float,
        ioLateralFriction: float,
        inBody2: PhysicsBody3D,
        inSubShapeID2: int
) -> Vector2:
    var body_friction: float = PhysicsServer3D.body_get_param(inBody2.get_rid(), PhysicsServer3D.BODY_PARAM_FRICTION)

    ioLongitudinalFriction = sqrt(ioLongitudinalFriction * body_friction);
    ioLateralFriction = sqrt(ioLateralFriction * body_friction);
    return Vector2(ioLongitudinalFriction, ioLateralFriction)

@warning_ignore('unused_parameter')
func _pre_step_callback(vehicle: VehicleBase) -> void:
    pass

@warning_ignore('unused_parameter')
func _post_collide_callback(vehicle: VehicleBase) -> void:
    pass

@warning_ignore('unused_parameter')
func _post_step_callback(vehicle: VehicleBase) -> void:
    pass
