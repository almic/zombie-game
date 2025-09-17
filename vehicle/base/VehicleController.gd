# Ported from Jolt by almic

# Jolt Physics Library (https://github.com/jrouwe/JoltPhysics)
# SPDX-FileCopyrightText: 2021 Jorrit Rouwe
# SPDX-License-Identifier: MIT

## Runtime data for interface that controls acceleration / deceleration of the vehicle
class_name VehicleController extends Resource


## The vehicle constraint we belong to
@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_NO_EDITOR)
var mConstraint: VehicleBase


func _init(vehicle: VehicleBase) -> void:
    mConstraint = vehicle

## Create a new instance of wheel
@warning_ignore('unused_parameter')
func ConstructWheel(wheel_settings: WheelSettings) -> Wheel:
    return null

## If the vehicle is allowed to go to sleep
func AllowSleep() -> bool:
    return true

## Called before the wheel probes have been done
@warning_ignore('unused_parameter')
func PreCollide(inDeltaTime: float, space: PhysicsDirectSpaceState3D) -> void:
    pass

## Called after the wheel probes have been done
@warning_ignore('unused_parameter')
func PostCollide(inDeltaTime: float, space: PhysicsDirectSpaceState3D) -> void:
    pass

## Solve longitudinal and lateral constraint parts for all of the wheels
@warning_ignore('unused_parameter')
func SolveLongitudinalAndLateralConstraints(inDeltaTime: float) -> bool:
    return false

# #ifdef JPH_DEBUG_RENDERER
# // Drawing interface
# virtual void Draw(DebugRenderer *inRenderer) const = 0;
# #endif // JPH_DEBUG_RENDERER
