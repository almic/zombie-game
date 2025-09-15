# Ported from Jolt by almic

# Jolt Physics Library (https://github.com/jrouwe/JoltPhysics)
# SPDX-FileCopyrightText: 2021 Jorrit Rouwe
# SPDX-License-Identifier: MIT

class_name VehicleEngine extends Resource


## Multiply an angular velocity (rad/s) with this value to get rounds per minute (RPM)
const cAngularVelocityToRPM = 60.0 / TAU


## Max amount of torque (Nm) that the engine can deliver
@export_range(0.0, 1000.0, 0.1, 'or_greater', 'suffix:Nm')
var mMaxTorque: float = 500.0

## Min amount of revolutions per minute (rpm) the engine can produce without stalling
@export_range(0.0, 4000.0, 0.1, 'or_greater', 'suffix:rpm')
var mMinRPM: float = 1000.0

## Max amount of revolutions per minute (rpm) the engine can generate
@export_range(0.0, 10000.0, 0.1, 'or_greater', 'suffix:rpm')
var mMaxRPM: float = 6000.0

## Y-axis: Curve that describes a ratio of the max torque the engine can produce (0 = 0, 1 = mMaxTorque).
## X-axis: the fraction of the RPM of the engine (0 = mMinRPM, 1 = mMaxRPM)
@export var mNormalizedTorque: Curve:
    get():
        if not mNormalizedTorque:
            mNormalizedTorque = Curve.new()
            mNormalizedTorque.add_point(Vector2(0.0, 0.8))
            mNormalizedTorque.add_point(Vector2(0.66, 1.0))
            mNormalizedTorque.add_point(Vector2(1.0, 0.8))
        return mNormalizedTorque

## Current rotation speed of engine in rounds per minute
@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_NO_EDITOR)
var mCurrentRPM: float

## Moment of inertia (kg m^2) of the engine
var mInertia: float = 0.5

## Angular damping factor of the wheel: dw/dt = -c * w
var mAngularDamping = 0.2


func _init() -> void:
    mCurrentRPM = mMinRPM


# /// Clamp the RPM between min and max RPM
# inline void ClampRPM() { mCurrentRPM = Clamp(mCurrentRPM, mMinRPM, mMaxRPM); }

# /// Current rotation speed of engine in rounds per minute
# float GetCurrentRPM() const { return mCurrentRPM; }

# /// Update rotation speed of engine in rounds per minute
# void SetCurrentRPM(float inRPM) { mCurrentRPM = inRPM; ClampRPM(); }

## Get current angular velocity of the engine in radians / second
func GetAngularVelocity() -> float:
    return mCurrentRPM / cAngularVelocityToRPM

## Get the amount of torque (N m) that the engine can supply
## @param inAcceleration How much the gas pedal is pressed [0, 1]
func GetTorque(inAcceleration: float) -> float:
    #return inAcceleration * mMaxTorque * mNormalizedTorque.GetValue(mCurrentRPM / mMaxRPM)
    return inAcceleration * mMaxTorque * mNormalizedTorque.sample_baked(mCurrentRPM / mMaxRPM)

## Apply a torque to the engine rotation speed
## @param inTorque Torque in N m
## @param inDeltaTime Delta time in seconds
func ApplyTorque(inTorque: float, inDeltaTime: float) -> void:
    # Accelerate engine using torque
    mCurrentRPM += cAngularVelocityToRPM * inTorque * inDeltaTime / mInertia
    mCurrentRPM = clampf(mCurrentRPM, mMinRPM, mMaxRPM)

## Update the engine RPM for damping
## @param inDeltaTime Delta time in seconds
func ApplyDamping(inDeltaTime: float) -> void:
    # Angular damping: dw/dt = -c * w
    # Solution: w(t) = w(0) * e^(-c * t) or w2 = w1 * e^(-c * dt)
    # Taylor expansion of e^(-c * dt) = 1 - c * dt + ...
    # Since dt is usually in the order of 1/60 and c is a low number too this approximation is good enough
    mCurrentRPM *= maxf(0.0, 1.0 - mAngularDamping * inDeltaTime)
    mCurrentRPM = clampf(mCurrentRPM, mMinRPM, mMaxRPM)

## If the engine is idle we allow the vehicle to sleep
func AllowSleep() -> bool:
    return mCurrentRPM <= 1.01 * mMinRPM

# #ifdef JPH_DEBUG_RENDERER
# // Function that converts RPM to an angle in radians for debugging purposes
# float ConvertRPMToAngle(float inRPM) const { return (-0.75f + 1.5f * inRPM / mMaxRPM) * JPH_PI; }
#
# /// Debug draw a RPM meter
# void DrawRPM(DebugRenderer *inRenderer, RVec3Arg inPosition, Vec3Arg inForward, Vec3Arg inUp, float inSize, float inShiftDownRPM, float inShiftUpRPM) const;
# #endif // JPH_DEBUG_RENDERER
