# Ported from Jolt by almic

# Jolt Physics Library (https://github.com/jrouwe/JoltPhysics)
# SPDX-FileCopyrightText: 2021 Jorrit Rouwe
# SPDX-License-Identifier: MIT

## Class that does collision detection between wheels and ground
class_name VehicleCollisionTester


## Do a collision test with the world
##
## vehicle         - The vehicle constraint
## wheel_index     - Index of the wheel that we're testing collision for
## origin          - Origin for the test, corresponds to the world space
##                   position for the suspension attachment point
## direction       - Direction for the test (unit vector, world space)
## vehicle_body_id - This body should be filtered out during collision detection
##                   to avoid self collisions
## wheel           - wheel to perform collision with, must update wheel when colliding
##
## return true when collision found, false if not
@warning_ignore('unused_parameter')
func Collide(
        vehicle: VehicleBase,
        wheel_index: int,
        origin: Vector3,
        direction: Vector3,
        vehicle_body_id: RID,
        wheel: Wheel
) -> bool:
    return false

## Do a cheap contact properties prediction based on the contact properties from
## the last collision test (provided as input parameters)
##
## vehicle         - The vehicle constraint
## wheel_index     - Index of the wheel that we're testing collision for
## origin          - Origin for the test, corresponds to the world space
##                   position for the suspension attachment point
## direction       - Direction for the test (unit vector, world space)
## vehicle_body_id - This body should be filtered out during collision detection
##                   to avoid self collisions
## wheel           - wheel to perform collision with, must update wheel when colliding
@warning_ignore('unused_parameter')
func PredictContactProperties(
        vehicle: VehicleBase,
        wheel_index: int,
        origin: Vector3,
        direction: Vector3,
        vehicle_body_id: RID,
        wheel: Wheel
) -> void:
    pass



class CastRay extends VehicleCollisionTester:
    func _init() -> void:
        pass
