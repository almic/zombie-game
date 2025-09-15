## Wheel which is attached to a vehicle body.
## Ported from Jolt physics engine.

class_name Wheel extends Resource

# ##########################
#      Public exports
# ##########################

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


# ##########################
#        Public Vars
# ##########################

## Rotation around the suspension direction, positive is to the left.
var steering_angle: float = 0.0

## Rotation speed of wheel, positive when the wheels cause the vehicle to move forwards (rad/s)
var angular_speed: float = 0.0

## Current rotation of the wheel (rad, [0, 2 pi])
var angle: float = 0.0


# ##########################
#      Internal Vars
# ##########################

## Body for ground
var _contact_body: Object

## Body ID for ground
var _contact_body_id: RID

## Shape index for ground
var _contact_shape_idx: int

## Current length of the suspension
var _suspension_length: float

## Position of the contact point between wheel and ground
var _contact_point: Vector3

## Velocity of the contact point, in world m/s
var _contact_point_velocity: Vector3

## Normal of the contact point between wheel and ground
var _contact_normal: Vector3

## Vector perpendicular to normal in the forward direction
var _contact_longitudinal: Vector3

## Vector perpendicular to normal and longitudinal direction in the right direction
var _contact_lateral: Vector3

## Constant for the contact plane of the axle, defined as ContactNormal.
## (WorldSpaceSuspensionPoint + SuspensionLength * WorldSpaceSuspensionDirection)
var _axle_plane_constant: float

## Amount of impulse applied to the suspension from the anti-rollbars
var _anti_roll_bar_impulse: float

## Controls movement up/down along the contact normal
var _suspension_part: AxisConstraintPart

## Adds a hard limit when reaching the minimal suspension length
var _suspension_max_up_part: AxisConstraintPart

## Controls movement forward/backward
var _longitudinal_part: AxisConstraintPart

## Controls movement sideways (slip)
var _lateral_part: AxisConstraintPart


func _validate_property(property: Dictionary) -> void:
    if property.name == 'suspension_force_point':
        if suspension_enable_force_point:
            property.usage = PROPERTY_USAGE_DEFAULT
        else:
            property.usage = PROPERTY_USAGE_NO_EDITOR

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
