# Ported from Jolt by almic

# Jolt Physics Library (https://github.com/jrouwe/JoltPhysics)
# SPDX-FileCopyrightText: 2021 Jorrit Rouwe
# SPDX-License-Identifier: MIT

class_name VehicleBaseSettings extends Resource


## Defines how the vehicle can accelerate / decelerate
@export var mController: VehicleControllerSettings

## List of wheels and their properties
@export var mWheels: Array[WheelSettings] = []

## List of anti rollbars and their properties
@export var mAntiRollBars: Array[AntiRollBar] = []

## Vector indicating the up direction of the vehicle (in local space to the body)
@export var mUp: Vector3 = Vector3.UP

## Vector indicating forward direction of the vehicle (in local space to the body)
@export var mForward: Vector3 = Vector3.MODEL_FRONT

##Defines the maximum pitch/roll angle (rad), can be used to avoid the car from
## getting upside down. The vehicle up direction will stay within a cone
## centered around the up axis with half top angle mMaxPitchRollAngle, set to PI
## to turn off.
@export var mMaxPitchRollAngle: float = PI
