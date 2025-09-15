# Ported from Jolt by almic

# Jolt Physics Library (https://github.com/jrouwe/JoltPhysics)
# SPDX-FileCopyrightText: 2021 Jorrit Rouwe
# SPDX-License-Identifier: MIT

class_name VehicleDifferential extends Resource


## Index (in mWheels) that represents the left wheel of this differential (can be -1 to indicate no wheel)
@export var mLeftWheel: int = -1

## Index (in mWheels) that represents the right wheel of this differential (can be -1 to indicate no wheel)
@export var mRightWheel: int = -1

## Ratio between rotation speed of gear box and wheels
@export var mDifferentialRatio: float = 3.42

## Defines how the engine torque is split across the left and right wheel (0 = left, 0.5 = center, 1 = right)
@export var mLeftRightSplit: float = 0.5

## Ratio max / min wheel speed. When this ratio is exceeded, all torque gets
## distributed to the slowest moving wheel. This allows implementing a limited
## slip differential. Set to INF for an open differential.
## Value should be > 1.
@export var mLimitedSlipRatio: float = 1.4

## How much of the engines torque is applied to this differential (0 = none, 1 = full),
## make sure the sum of all differentials is 1.
@export var mEngineTorqueRatio: float = 1.0

## Calculate the torque ratio between left and right wheel
## @param inLeftAngularVelocity Angular velocity of left wheel (rad / s)
## @param inRightAngularVelocity Angular velocity of right wheel (rad / s)
## @param outLeftTorqueFraction Fraction of torque that should go to the left wheel
## @param outRightTorqueFraction Fraction of torque that should go to the right wheel
func CalculateTorqueRatio(
        inLeftAngularVelocity: float,
        inRightAngularVelocity: float
) -> Vector2:
    # Start with the default torque ratio
    var outLeftTorqueFraction: float = 1.0 - mLeftRightSplit
    var outRightTorqueFraction: float = mLeftRightSplit

    if not is_inf(mLimitedSlipRatio):
        assert(mLimitedSlipRatio > 1.0)

        # This is a limited slip differential, adjust torque ratios according to wheel speeds
        var omega_l: float = maxf(1.0e-3, absf(inLeftAngularVelocity)) # prevent div by zero by setting a minimum velocity and ignoring that the wheels may be rotating in different directions
        var omega_r: float = maxf(1.0e-3, absf(inRightAngularVelocity))
        var omega_min: float = minf(omega_l, omega_r)
        var omega_max: float = maxf(omega_l, omega_r)

        # Map into a value that is 0 when the wheels are turning at an equal rate and 1 when the wheels are turning at mLimitedSlipRotationRatio
        var alpha: float = minf((omega_max / omega_min - 1.0) / (mLimitedSlipRatio - 1.0), 1.0)
        assert(alpha >= 0.0)
        var one_min_alpha: float = 1.0 - alpha

        if (omega_l < omega_r):
            # Redirect more power to the left wheel
            outLeftTorqueFraction = outLeftTorqueFraction * one_min_alpha + alpha
            outRightTorqueFraction = outRightTorqueFraction * one_min_alpha
        else:
            # Redirect more power to the right wheel
            outLeftTorqueFraction = outLeftTorqueFraction * one_min_alpha
            outRightTorqueFraction = outRightTorqueFraction * one_min_alpha + alpha

    # Assert the values add up to 1
    assert(absf(outLeftTorqueFraction + outRightTorqueFraction - 1.0) < 1.0e-6)
    return Vector2(outLeftTorqueFraction, outRightTorqueFraction)
