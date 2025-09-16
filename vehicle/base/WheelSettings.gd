# Ported from Jolt by almic

# Jolt Physics Library (https://github.com/jrouwe/JoltPhysics)
# SPDX-FileCopyrightText: 2021 Jorrit Rouwe
# SPDX-License-Identifier: MIT

## Base class for wheel settings, each VehicleController can implement a derived
## class of this
class_name WheelSettings extends Resource

## Radius of the wheel (m)
@export var radius: float = 0.3

## Width of the wheel (m)
@export var width: float = 0.1

## Attachment point of wheel suspension in local space of the body
@export var position: Vector3 = Vector3.ZERO

## Settings for the suspension spring
@export var spring_settings: SpringSettings = SpringSettings.new(SpringSettings.Mode.FrequencyAndDamping, 1.5, 0.5)


@export_group("Suspension", "suspension")

## How far up the suspension can raise relative to the attachment point (m)
@export var suspension_min_length: float = 0.3

## How far down the suspension can droop relative to the attachment point (m)
@export var suspension_max_length: float = 0.5


## Direction of the suspension in local space of the body, should point down.
@export var suspension_direction: Vector3 = Vector3.DOWN

## The natural length (m) of the suspension spring is defined as
## suspension_max_length + suspension_preload_length. Can be used to preload the
## suspension as the spring is compressed by suspension_preload_length when the
## suspension is in max droop position. Note that this means when the vehicle
## touches the ground there is a discontinuity so it will also make the vehicle
## more bouncy as we're updating with discrete time steps.
##
## PRO-TIP: probably leave this at zero
@export var suspension_preload_length: float = 0.0

## Enables mSuspensionForcePoint, if disabled, the forces are applied at the
## collision contact point. This leads to a more accurate simulation when
## interacting with dynamic objects but makes the vehicle less stable.
## When setting this to true, all forces will be applied to a fixed point
## on the vehicle body.
@export var suspension_enable_force_point: bool = false:
    set(value):
        if value != suspension_enable_force_point:
            suspension_enable_force_point = value
            notify_property_list_changed()

## Where tire forces (suspension and traction) are applied, in local space of the body.
## A good default is the center of the wheel in its neutral pose. See suspension_enable_force_point.
@export var suspension_force_point: Vector3 = Vector3.ZERO


@export_group("Advanced")

## Up direction when the wheel is in the neutral steering position.
## Usually Vehicle.up_local but can be used to give the wheel camber, or for a bike it
## would be -suspension_direction.
@export var up_local: Vector3 = Vector3.UP

## Forward direction when the wheel is in the neutral steering position.
## Usually Vehicle.forward_local but can be used to give the wheel toe, does not need
## to be perpendicular to Wheel.up
@export var forward_local: Vector3 = Vector3.MODEL_FRONT

## Direction of the steering axis in local space of the body, should point up.
## E.g. for a bike would be -suspension_direction, if the suspension is not straight down.
@export var steering_axis: Vector3 = Vector3.UP


func _validate_property(property: Dictionary) -> void:
    if property.name == 'suspension_force_point':
        if suspension_enable_force_point:
            property.usage = PROPERTY_USAGE_DEFAULT
        else:
            property.usage = PROPERTY_USAGE_NO_EDITOR
