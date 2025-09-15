# Ported from Jolt by almic

# Jolt Physics Library (https://github.com/jrouwe/JoltPhysics)
# SPDX-FileCopyrightText: 2021 Jorrit Rouwe
# SPDX-License-Identifier: MIT

class_name VehicleTransmission extends Node

## How gears are shifted
enum TransmissionMode
{
    ## Automatically shift gear up and down
    Auto = 0,

    ## Manual gear shift (call SetTransmissionInput)
    Manual = 1,
}

## How to switch gears
@export var mMode: TransmissionMode = TransmissionMode.Auto

## Ratio in rotation rate between engine and gear box, first element is 1st gear, 2nd element 2nd gear etc.
@export var mGearRatios: PackedFloat32Array = [ 2.66, 1.78, 1.3, 1.0, 0.74 ]

## Ratio in rotation rate between engine and gear box when driving in reverse
@export var mReverseGearRatios: PackedFloat32Array = [ -2.90 ]

## How long it takes to switch gears (s), only used in auto mode
@export var mSwitchTime: float = 0.5

## How long it takes to release the clutch (go to full friction), only used in auto mode
@export var mClutchReleaseTime: float = 0.3

## How long to wait after releasing the clutch before another switch is attempted (s), only used in auto mode
@export var mSwitchLatency = 0.5

## If RPM of engine is bigger then this we will shift a gear up, only used in auto mode
@export var mShiftUpRPM = 4000.0

## If RPM of engine is smaller then this we will shift a gear down, only used in auto mode
@export var mShiftDownRPM: float = 2000.0

## Strength of the clutch when fully engaged. Total torque a clutch applies is:
## Torque = ClutchStrength * (Velocity Engine - Avg Velocity Wheels At Clutch) (units: k m^2 s^-1)
@export var mClutchStrength: float = 10.0


## Current gear, -1 = reverse, 0 = neutral, 1 = 1st gear etc.
@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_NO_EDITOR)
var mCurrentGear: int = 0

## Value between 0 and 1 indicating how much friction the clutch gives.
## 0 = no friction, 1 = full friction
@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_NO_EDITOR)
var mClutchFriction: float = 1.0

## When switching gears this will be > 0 and will cause the engine to not
## provide any torque to the wheels for a short time.
## Used for automatic gear switching only.
@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_NO_EDITOR)
var mGearSwitchTimeLeft: float = 0.0

## After switching gears this will be > 0 and will cause the clutch friction to go from 0 to 1.
## Used for automatic gear switching only
@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_NO_EDITOR)
var mClutchReleaseTimeLeft: float = 0.0

## After releasing the clutch this will be > 0 and will prevent another gear switch
## Used for automatic gear switching only.
@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_NO_EDITOR)
var mGearSwitchLatencyTimeLeft: float = 0.0



## Set input from driver regarding the transmission.
## Only relevant when transmission is set to manual mode.
## @param inCurrentGear Current gear, -1 = reverse, 0 = neutral, 1 = 1st gear etc.
## @param inClutchFriction Value between 0 and 1 indicating how much friction
##                         the clutch gives (0 = no friction, 1 = full friction)
func Set(inCurrentGear: int, inClutchFriction: float) -> void:
    mCurrentGear = inCurrentGear
    mClutchFriction = inClutchFriction

## Update the current gear and clutch friction if the transmission is in auto mode
## @param inDeltaTime Time step delta time in s
## @param inCurrentRPM Current RPM for engine
## @param inForwardInput Hint if the user wants to drive forward (> 0) or backwards (< 0)
## @param inCanShiftUp Indicates if we want to allow the transmission to shift up (e.g. pass false if wheels are slipping)
func Update(
        inDeltaTime: float,
        inCurrentRPM: float,
        inForwardInput: float,
        inCanShiftUp: bool
) -> void:
    # Update current gear and calculate clutch friction
    if mMode != TransmissionMode.Auto:
        return

    # Switch gears based on rpm
    var old_gear: int = mCurrentGear
    if (mCurrentGear == 0 # In neutral
        || inForwardInput * float(mCurrentGear) < 0.0): # Changing between forward / reverse
        # Switch to first gear or reverse depending on input
        # mCurrentGear = inForwardInput > 0.0 ? 1 : (inForwardInput < 0.0 ? -1 : 0)
        if inForwardInput > 0.0:
            mCurrentGear = 1
        elif inForwardInput < 0.0:
            mCurrentGear = -1
        else:
            mCurrentGear = 0
    elif mGearSwitchLatencyTimeLeft == 0.0: # If not in the timout after switching gears
        if inCanShiftUp && inCurrentRPM > mShiftUpRPM:
            if mCurrentGear < 0:
                # Shift up, reverse
                if mCurrentGear > -mReverseGearRatios.size():
                    mCurrentGear -= 1
            else:
                # Shift up, forward
                if mCurrentGear < mGearRatios.size():
                    mCurrentGear += 1
        elif inCurrentRPM < mShiftDownRPM:
            if mCurrentGear < 0:
                # Shift down, reverse
                # int max_gear = inForwardInput != 0.0f? -1 : 0;
                var max_gear: int
                if inForwardInput != 0.0:
                    max_gear = -1
                else:
                    max_gear = 0

                if mCurrentGear < max_gear:
                    mCurrentGear += 1
            else:
                # Shift down, forward
                # int min_gear = inForwardInput != 0.0f? 1 : 0;
                var min_gear: int
                if inForwardInput != 0.0:
                    min_gear = 1
                else:
                    min_gear = 0

                if mCurrentGear > min_gear:
                    mCurrentGear -= 1

    if old_gear != mCurrentGear:
        # We've shifted gear, start switch countdown
        # mGearSwitchTimeLeft = old_gear != 0? mSwitchTime : 0.0f;
        if old_gear != 0:
            mGearSwitchTimeLeft = mSwitchTime
        else:
            mGearSwitchTimeLeft = 0.0

        mClutchReleaseTimeLeft = mClutchReleaseTime;
        mGearSwitchLatencyTimeLeft = mSwitchLatency;
        mClutchFriction = 0.0

    elif mGearSwitchTimeLeft > 0.0:
        # If still switching gears, count down
        mGearSwitchTimeLeft = maxf(0.0, mGearSwitchTimeLeft - inDeltaTime)
        mClutchFriction = 0.0
    elif mClutchReleaseTimeLeft > 0.0:
        # After switching the gears we slowly release the clutch
        mClutchReleaseTimeLeft = maxf(0.0, mClutchReleaseTimeLeft - inDeltaTime)
        mClutchFriction = 1.0 - mClutchReleaseTimeLeft / mClutchReleaseTime
    else:
        # Clutch has full friction
        mClutchFriction = 1.0

        # Count down switch latency
        mGearSwitchLatencyTimeLeft = maxf(0.0, mGearSwitchLatencyTimeLeft - inDeltaTime)

## If the auto box is currently switching gears
func IsSwitchingGear() -> bool:
    return mGearSwitchTimeLeft > 0.0

## Return the transmission ratio based on the current gear
## (ratio between engine and differential)
func GetCurrentRatio() -> float:
    if mCurrentGear < 0:
        return mReverseGearRatios[-mCurrentGear - 1]
    elif mCurrentGear == 0:
        return 0.0
    else:
        return mGearRatios[mCurrentGear - 1]

## Only allow sleeping when the transmission is idle
func AllowSleep() -> bool:
    return (
                mGearSwitchTimeLeft <= 0.0
            and mClutchReleaseTimeLeft <= 0.0
            and mGearSwitchLatencyTimeLeft <= 0.0
    )
