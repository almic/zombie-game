# Ported from Jolt by almic

# Jolt Physics Library (https://github.com/jrouwe/JoltPhysics)
# SPDX-FileCopyrightText: 2021 Jorrit Rouwe
# SPDX-License-Identifier: MIT

## Base class for runtime data for a wheel, each VehicleController can implement
## a derived class of this
class_name Wheel extends Resource


## Rotation around the suspension direction, positive is to the left.
@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_NO_EDITOR)
var steering_angle: float = 0.0

## Rotation speed of wheel, positive when the wheels cause the vehicle to move forwards (rad/s)
@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_NO_EDITOR)
var angular_speed: float = 0.0

## Current rotation of the wheel (rad, [0, 2 pi])
@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_NO_EDITOR)
var angle: float = 0.0


# ##########################
#      Internal Vars
# ##########################

## Configuration settings for this wheel
var mSettings: WheelSettings

## Body for ground
var _contact_body: Object

## Body ID for ground
@warning_ignore('unused_private_class_variable')
var _contact_body_id: RID

## Shape index for ground
@warning_ignore('unused_private_class_variable')
var _contact_shape_idx: int

## Current length of the suspension
@warning_ignore('unused_private_class_variable')
var _suspension_length: float

## Position of the contact point between wheel and ground
@warning_ignore('unused_private_class_variable')
var _contact_point: Vector3

## Velocity of the contact point, in world m/s
@warning_ignore('unused_private_class_variable')
var _contact_point_velocity: Vector3

## Normal of the contact point between wheel and ground
@warning_ignore('unused_private_class_variable')
var _contact_normal: Vector3

## Vector perpendicular to normal in the forward direction
var _contact_longitudinal: Vector3

## Vector perpendicular to normal and longitudinal direction in the right direction
var _contact_lateral: Vector3

## Constant for the contact plane of the axle, defined as ContactNormal.
## (WorldSpaceSuspensionPoint + SuspensionLength * WorldSpaceSuspensionDirection)
@warning_ignore('unused_private_class_variable')
var _axle_plane_constant: float

## Amount of impulse applied to the suspension from the anti-rollbars
@warning_ignore('unused_private_class_variable')
var _anti_roll_bar_impulse: float

## Controls movement up/down along the contact normal
@warning_ignore('unused_private_class_variable')
var _suspension_part: AxisConstraintPart

## Adds a hard limit when reaching the minimal suspension length
@warning_ignore('unused_private_class_variable')
var _suspension_max_up_part: AxisConstraintPart

## Controls movement forward/backward
var _longitudinal_part: AxisConstraintPart

## Controls movement sideways (slip)
var _lateral_part: AxisConstraintPart


func _init(wheel_setting: WheelSettings) -> void:
    mSettings = wheel_setting


## Internal function that should only be called by the controller.
## Used to apply impulses in the forward direction of the vehicle.
func SolveLongitudinalConstraintPart(vehicle: VehicleBase, impulse_min: float, impulse_max: float) -> bool:
    return _longitudinal_part.SolveVelocityConstraint(
            vehicle,
            _contact_body,
            -_contact_longitudinal,
            impulse_min,
            impulse_max
    )

## Internal function that should only be called by the controller.
## Used to apply impulses in the sideways direction of the vehicle.
func SolveLateralConstraintPart(vehicle: VehicleBase, impulse_min: float, impulse_max: float) -> bool:
    return _lateral_part.SolveVelocityConstraint(
            vehicle,
            _contact_body,
            -_contact_lateral,
            impulse_min,
            impulse_max
    )
