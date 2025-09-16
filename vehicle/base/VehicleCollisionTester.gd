# Ported from Jolt by almic

# Jolt Physics Library (https://github.com/jrouwe/JoltPhysics)
# SPDX-FileCopyrightText: 2021 Jorrit Rouwe
# SPDX-License-Identifier: MIT

## Class that does collision detection between wheels and ground
class_name VehicleCollisionTester


var body_excludes: Array[RID]
var collision_mask: int


func _init(exclude: Array[RID], layer: int) -> void:
    body_excludes = exclude.duplicate()
    collision_mask = layer


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


## Collision tester that tests collision using a raycast
class CastRay extends VehicleCollisionTester:
    var up: Vector3
    var cos_max_slope_angle: float

    ## Constructor
    ##
    ## exclude   - list of RIDs to ignore collision with
    ## layer     - layer to test collision with
    ## up        - World space up vector, used to avoid colliding with vertical walls.
    ## max_slope - Max angle (rad) that is considered for colliding wheels. This
    ##             is to avoid colliding with vertical walls.
    @warning_ignore('shadowed_variable')
    func _init(
            exclude: Array[RID],
            layer: int,
            up: Vector3 = Vector3.UP,
            max_slope: float = deg_to_rad(80.0)
    ) -> void:
        super._init(exclude, layer)

        self.up = up
        cos_max_slope_angle = cos(max_slope)


## Collision tester that tests collision using a sphere cast
class CastSphere extends VehicleCollisionTester:
    var radius: float
    var up: Vector3
    var cos_max_slope_angle: float

    ## Constructor
    ##
    ## exclude   - list of RIDs to ignore collision with
    ## layer     - layer to test collision with
    ## radius    - Radius of sphere
    ## up        - World space up vector, used to avoid colliding with vertical walls.
    ## max_slope - Max angle (rad) that is considered for colliding wheels. This
    ##             is to avoid colliding with vertical walls.
    @warning_ignore('shadowed_variable')
    func _init(
            exclude: Array[RID],
            layer: int,
            radius: float,
            up: Vector3 = Vector3.UP,
            max_slope: float = deg_to_rad(80.0)
    ) -> void:
        super._init(exclude, layer)

        self.radius = radius
        self.up = up
        cos_max_slope_angle = cos(max_slope)


## Collision tester that tests collision using a cylinder shape
class CastCylinder extends VehicleCollisionTester:
    var convex_radius_fraction: float

    ## Constructor
    ##
    ## exclude  - list of RIDs to ignore collision with
    ## layer    - layer to test collision with
    ## fraction - Fraction of half the wheel width (or wheel radius if it is
    ##            smaller) that is used as the convex radius
    func _init(
            exclude: Array[RID],
            layer: int,
            fraction: float = 0.1
    ) -> void:
        super._init(exclude, layer)

        convex_radius_fraction = fraction
