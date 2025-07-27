@tool
@icon("res://icon/character.svg")

## Character base class, provides utility methods and settings common for
## most characters
class_name CharacterBase
extends CharacterBody3D


const RAD_15: float = 12.0 / PI

# This value is ideal to stop slides on ramps, without sticking into the ground
const ANTI_SLIDE_EPSILON: float = 0.000004

enum GroundState
{
    ## On solid ground that supports the body, such as terrain or a platform. Friction may be applied.
    GROUNDED,
    ## On solid ground that supports the body, but is too steep and should start sliding the player. Friction may be applied.
    GROUNDED_STEEP,
    ## On an object that does not support the body, so gravity should be applied, but is enough to jump and walk on. Friction may be applied.
    NOT_SUPPORTED,
    ## Not on an object that can be walked on or jumped on. Friction should not be applied.
    NOT_GROUNDED
}

enum FluidState
{
    ## In air, so drag may be applied.
    AIR,
    ## In water, or other thick fluid, so motion should be affected.
    LIQUID,
    ## In nothing, like outer space.
    EMPTY
}

class GroundDetails:
    var body: Object = null
    var normal: Vector3 = Vector3.ZERO
    var position: Vector3 = Vector3.ZERO
    var velocity: Vector3 = Vector3.ZERO

    func reset() -> void:
        body = null
        normal = Vector3.ZERO
        position = Vector3.ZERO
        velocity = Vector3.ZERO

    func has_ground() -> bool:
        return body != null

class FluidDetails:
    var area: Area3D = null

    func reset() -> void:
        area = null

    func has_fluid() -> bool:
        return area != null


@export var collider_shape: Shape3D:
    set = set_collider_shape


@export_group("Movement")

@export var gravity: float = 9.81
## Top speed in meters per second
@export var top_speed: float = 4.8
## Instant jupm speed in meters per second
@export var jump_power: float = 5.0
## Maximum walkable slope, will slide along surfaces steeper than this
@export_custom(PROPERTY_HINT_RANGE, '0.01,90,0.01,or_greater,radians_as_degrees')
var floor_max_slope: float = PI / 3:
    set = set_floor_max_slope
var floor_max_cos_theta: float = -1
## Minimum angle to slide along walls when moving
@export_custom(PROPERTY_HINT_RANGE, '0.01,90,0.01,radians_as_degrees')
var wall_slide_angle: float = PI / 45:
    set = set_wall_slide_angle
var wall_slide_cos_theta: float = -1

@export_subgroup("Moving", "move")

## Acceleration in the direction of movement in meters per second^2. Affects
## responsiveness of controls.
@export var move_acceleration: float = 20.0
## Decceleration in meters per second^2. Affects slideyness of controls.
@export var move_friction: float = 15
## Effectiveness of movement in the air, multiplier of acceleration
@export var move_air_control: float = 0.25
## Air resistance, affects max fall speed and decceleration in the air
@export var move_drag: float = 0.5
## How much speed to keep per 15 degrees of turning
@export var move_turn_speed_keep: float = 0.67


@export_subgroup("Stepping", "step")
## Maximum vertical step to take, in meters
@export var step_up_max: float = 0.45
## Maximum falling step to take, in meters; ground snapping
@export var step_down_max: float = 0.45

@export_group("Camera Smoothing", "camera")
## The camera node
@export var camera_node: Camera3D = null
## The target location for the camera
@export var camera_target_node: Node3D = null
@export var camera_smooth_speed: float = 10.0
@export var camera_lag_distance: float = 1.0


@onready var collider: CollisionShape3D = %collider


## Set this before calling `update_movement()`
var movement_direction: Vector3 = Vector3.ZERO

## Computed after calling `travel_character()`
var acceleration: Vector3 = Vector3.ZERO
var last_velocity: Vector3 = Vector3.ZERO

## If the character is jumping
var is_jumping: bool = false
var _wants_jump: bool = false

# Ground stuff
var ground_state: GroundState = GroundState.NOT_GROUNDED
var ground_details: GroundDetails = GroundDetails.new()

# Fluid stuff
var fluid_state: FluidState = FluidState.AIR
var fluid_details: FluidDetails = FluidDetails.new()


func _ready() -> void:
    collider.shape = collider_shape

func set_collider_shape(shape: Shape3D) -> void:
    collider_shape = shape
    if not is_node_ready():
        return
    collider.shape = collider_shape

func set_floor_max_slope(max_slope: float) -> void:
    floor_max_slope = max_slope
    floor_max_cos_theta = cos(floor_max_slope)

func set_wall_slide_angle(slide_angle: float) -> void:
    wall_slide_angle = slide_angle
    wall_slide_cos_theta = cos(wall_slide_angle)

## Call when you wish for the character to do a jump. If the character is not
## grounded, this does nothing.
func do_jump() -> void:
    _wants_jump = true

## If the character is currently grounded
func is_grounded() -> bool:
    return ground_state == GroundState.GROUNDED or ground_state == GroundState.GROUNDED_STEEP

## Using the current movement direction and velocity, move the character body,
## stepping and sliding as needed. This will also compute an acceleration that
## can be used with animations.
func update_movement(delta: float) -> void:

    # Zero velocity when near zero
    if velocity.is_zero_approx():
        velocity = Vector3.ZERO

    # Prepare variables
    var stationary: bool = movement_direction.is_zero_approx()
    var grounded: bool = is_grounded()
    var direction: Vector3 = velocity.normalized()

    # Forces
    # Drag
    var drag: Vector3 = compute_drag(move_drag, velocity, _get_density(), _get_area())
    drag *= delta

    # Friction
    var friction: Vector3
    if grounded and ground_details.has_ground():
        var ground_dot_up: float = up_direction.dot(ground_details.normal)
        if ground_dot_up > 0:
            var slide: Vector3 = (up_direction * ground_dot_up).normalized()
            var ground_velocity: Vector3 = (velocity - ground_details.velocity).slide(slide)
            var speed: float = ground_velocity.length()
            if not is_zero_approx(speed):
                var ground_direction: Vector3 = ground_velocity / speed
                if stationary:
                    friction = -ground_direction * move_friction
                else:
                    friction = compute_friction(move_friction, ground_direction, movement_direction, move_turn_speed_keep)
                friction *= speed * delta
    # Gravity
    var gravity_force: Vector3 = gravity * -up_direction
    gravity_force *= delta

    # Input acceleration
    var movement: Vector3
    if not stationary:
        movement = movement_direction * move_acceleration * delta

        # air control
        if not grounded:
            movement *= move_air_control

    # Update velocity
    # Forces
    velocity += friction + drag + gravity_force
    # Input
    velocity = combine_velocity_limited(velocity, movement, top_speed)

    # Jumping
    if grounded:
        if _wants_jump and not is_jumping:
            velocity += up_direction * jump_power
            is_jumping = true
            grounded = false
        else:
            is_jumping = false
    _wants_jump = false

    var last_position: Vector3 = global_position
    var rid: RID = get_rid()

    ground_details.reset()
    var best_ground_dot: float = -INF

    var move: PhysicsTestMotionParameters3D = PhysicsTestMotionParameters3D.new()
    var to_move: Vector3 = velocity * delta
    for step in range(4):
        if to_move.is_zero_approx():
            break

        move.from = global_transform
        move.motion = to_move
        move.max_collisions = 4
        move.recovery_as_collision = true

        var collisions: PhysicsTestMotionResult3D = PhysicsTestMotionResult3D.new()
        var collided: bool = PhysicsServer3D.body_test_motion(rid, move, collisions)
        if _handle_movement_collisions(collided, collisions):
            break

        var travel: Vector3 = collisions.get_travel()

        if not collided:
            global_position += travel
            break

        var remainder: Vector3 = collisions.get_remainder()

        # Project travel onto move direction, prevent recovery from creating
        # unwanted sliding on slopes. Do not apply when recovery was too great
        var move_dot_travel: float = to_move.dot(travel)
        var move_dir: Vector3 = to_move.normalized()
        var recovery: Vector3 = travel - move_dir * move_dot_travel
        if recovery.length_squared() <= ANTI_SLIDE_EPSILON:
            travel = move_dir * to_move.dot(travel)
            remainder = to_move - travel

        global_position += travel

        # Detect best floor, average normals for sliding
        var average_floor_normal: Vector3
        var average_wall_normal: Vector3
        var last_normal: Vector3
        for i in range(collisions.get_collision_count()):
            var normal: Vector3 = collisions.get_collision_normal(i)

            # Handle multiple collisions reported from face/ edge collisions
            if normal.is_equal_approx(last_normal):
                continue
            last_normal = normal

            var dot: float = normal.dot(up_direction)

            # Gather average slide direction
            if dot < floor_max_cos_theta:
                average_wall_normal += normal
            else:
                average_floor_normal += normal

            # Gather best ground normal, most aligned with up direction (and positive)
            if not dot > 0 or not (dot - best_ground_dot > 0.01):
                continue
            best_ground_dot = dot

            apply_ground_details(
                normal,
                collisions.get_collision_point(i),
                collisions.get_collider(i)
            )

        if best_ground_dot < floor_max_cos_theta:
            # TODO: attempt to step up on steep collisions using ray casts
            pass

        to_move = remainder

        # Slide against up direction for walls
        if not average_wall_normal.is_zero_approx():
            average_wall_normal = average_wall_normal.normalized()
            var lateral: Vector3 = to_move.slide(up_direction)
            var vertical: Vector3 = up_direction * up_direction.dot(to_move)

            # Respect minimum wall slide angle, removes wall direction from lateral
            var move_dot_wall: float = lateral.normalized().dot(-average_wall_normal)
            if wall_slide_angle < 0.001 or move_dot_wall <= wall_slide_cos_theta:
                lateral = lateral.slide(-average_wall_normal)
            else:
                # undo slide from collision test
                global_position -= travel.slide(up_direction).slide(-average_wall_normal)
                lateral = Vector3.ZERO

            to_move = vertical + lateral

        # Slide along/ with floors
        if not average_floor_normal.is_zero_approx():
            average_floor_normal = average_floor_normal.normalized()

            # On "flat" ground, do not slide down.
            # Do this by removing downward vertical motion before sliding
            if up_direction.dot(average_floor_normal) >= floor_max_cos_theta:
                var move_dot_up: float = to_move.dot(up_direction)
                if move_dot_up < 0:
                    to_move -= up_direction * move_dot_up

            # From Godot's character body, better slide direction on slopes
            var to_slide: Vector3 = up_direction.cross(to_move).cross(average_floor_normal).normalized()
            to_move = to_slide * to_move.slide(average_floor_normal).length()

    var real_velocity: Vector3 = global_position - last_position

    # Snap to floor if we were grounded, no longer are, and did not move up
    if grounded and not ground_details.has_ground() and not real_velocity.dot(up_direction) > 0:
        snap_down()
        real_velocity = global_position - last_position

    # Update ground state
    if ground_details.has_ground():
        if best_ground_dot < floor_max_cos_theta:
            ground_state = GroundState.GROUNDED_STEEP
        else:
            ground_state = GroundState.GROUNDED
    else:
        ground_state = GroundState.NOT_GROUNDED

    #if snapped:
    #print(ground_state)

    # Compute true acceleration and velocity
    acceleration = real_velocity - last_velocity
    last_velocity = real_velocity
    velocity = real_velocity / delta

    if camera_node:
        smooth_camera(delta)

static func compute_drag(drag: float, velocity: Vector3, density: float, area: float) -> Vector3:
    #return 0.5 * drag * density * area * -velocity * velocity.abs()
    return Vector3.ZERO

static func compute_friction(friction: float, direction: Vector3, wish_direction: Vector3, turn_rate: float = 0.67) -> Vector3:
    var cos_theta: float = clampf(direction.dot(wish_direction), -1.0, 1.0)

    # No friction if wish direction and movement match
    if cos_theta - 1.0 > 0.0001:
        return Vector3.ZERO

    var angle: float = cos(cos_theta)

    # More friction in similar directions, reduce slidey feel when
    # strafing perpendicular to direction of motion
    if cos_theta > 0.0:
        cos_theta *= cos_theta

    var loss: float = (1.0 - cos_theta) * friction

    # Retain some speed when turning
    var keep: float = pow(turn_rate, angle * RAD_15)

    # Allow counter-strafing at "half" the normal rate, reduces jumpy feeling
    if cos_theta <= 0.0:
        keep *= keep

    return -direction * loss + wish_direction * loss * keep

## Adds two velocities while respecting and additive limit on speed
static func combine_velocity_limited(velocity: Vector3, to_add: Vector3, limit: float) -> Vector3:
    # Only limit if adding
    if to_add.is_zero_approx():
        return velocity

    var result: Vector3 = velocity + to_add

    # Zero/ negative limit means no limit
    if limit < 0.001:
        return result

    # TODO: some sign is wrong here, directional air control is wobbly
    if result.length_squared() > limit * limit:
        # additive bounds for result
        var bounds: Vector3 = to_add.normalized() * limit
        for i in range(3):
            if abs(result[i]) > abs(velocity[i]):
                result[i] = signf(result[i]) * minf(abs(bounds[i]), abs(result[i]))

    return result

func step_up() -> void:
    pass
    # Basically, if our last collision left some remainder, see if we can use
    # the remainder to step up onto an elevated surface. Only apply if the
    # remainder is a significant portion of the total movement.

    #var last_collision := get_last_slide_collision()
    #if not last_collision:
        #return
#
    #var remainder: Vector3 = last_collision.get_remainder()
    #if remainder.is_zero_approx():
        #return
#
    #var final_transform: Transform3D = global_transform

    # It is likely that move_and_slide() pushed us sideways, so if we had any
    # final motion, undo it. Otherwise, steps will be "slippery af"
    # This test prevents us from undoing the initial motion if the collision
    # did not result in sliding, such as when going straight into steps.
    #if not last_collision.get_travel().is_equal_approx(get_last_motion()):
        #final_transform = final_transform.translated(-get_last_motion())

    # Test if we can "land" on an elevated platform using the remainder
    #var result := PhysicsTestMotionResult3D.new()
    #var params := PhysicsTestMotionParameters3D.new()
    #var step_motion: Vector3 = up_direction * step_up_max
#
    #var remainder_length: float = remainder.length()
    #if remainder_length < 0.05:
        #remainder = (remainder / remainder_length) * 0.05
    #var test_transform: Transform3D = final_transform.translated(remainder)
    #test_transform = test_transform.translated(step_motion)
#
    #params.from = test_transform
    #params.motion = -step_motion

    # No hit, no step
    #if not PhysicsServer3D.body_test_motion(get_rid(), params, result):
        #return

    # If there was less than 0.05 movement, consider it a failure.
    # This catches steps that would put us inside walls.
    #if result.get_travel().length_squared() <= 0.0025:
        #return

    # Don't handle tiny steps that move_and_slide() can already handle
    # Also, ensure the point of collision is not greater than the step height.
    # This prevents round bodies from climbing extreme steps
    #var up_distance: float = result.get_collision_point().y - global_position.y
    #if up_distance < 0.05 or up_distance - step_up_max > 0.0:
        #return

    # Respect floor_max_angle by testing the collision normal
    # If the angle is too much, test with a raycast. Needed for round bodies.
    #if not up_direction.angle_to(result.get_collision_normal()) <= floor_max_angle:
        # Move test point against the normal so it isn't testing on the edge
        #var test_point: Vector3 = result.get_collision_point()
        #test_point -= result.get_collision_normal() * 0.02
        #var test_range: Vector3 = up_direction * 0.5
        #var raycast := get_world_3d().direct_space_state.intersect_ray(
                #PhysicsRayQueryParameters3D.create(
                    #test_point + test_range,
                    #test_point - test_range,
                    #collision_mask,
                    #[get_rid()]
                #)
        #)
        #if not raycast or up_direction.angle_to(raycast.normal) > floor_max_angle:
            #return

    # Passing, move player to new position
    #global_transform = test_transform.translated(result.get_travel())
    #apply_floor_snap()
    #is_grounded = true
    #is_stepping_up = true
    #print("step up!")


func snap_down() -> void:
    var drop: Vector3 = -up_direction * step_down_max
    var space := get_world_3d().direct_space_state
    var raycast := space.intersect_ray(PhysicsRayQueryParameters3D.create(
            global_position,
            global_position + drop,
            collision_mask,
            [get_rid()]
    ))

    if not raycast:
        return

    if up_direction.dot(raycast.normal) < floor_max_cos_theta:
        return

    var result := PhysicsTestMotionResult3D.new()
    var params := PhysicsTestMotionParameters3D.new()

    params.from = global_transform
    params.motion = drop
    if not PhysicsServer3D.body_test_motion(get_rid(), params, result):
        return

    if result.get_travel().length_squared() < ANTI_SLIDE_EPSILON:
        return

    apply_ground_details(
        result.get_collision_normal(0),
        result.get_collision_point(0),
        result.get_collider(0)
    )

    drop = -up_direction * up_direction.dot(-result.get_travel())
    global_transform = global_transform.translated(drop)


func apply_ground_details(normal: Vector3, contact_point: Vector3, body: Object):
    ground_details.normal = normal
    ground_details.position = contact_point
    ground_details.body = body
    if ground_details.body is PhysicsBody3D:
        var phys_body: PhysicsBody3D = ground_details.body as PhysicsBody3D
        ground_details.velocity = (
                PhysicsServer3D.body_get_direct_state(phys_body.get_rid())
                .get_velocity_at_local_position(ground_details.position - phys_body.global_position)
        )
    else:
        ground_details.velocity = Vector3.ZERO


func smooth_camera(delta: float) -> void:
    camera_node.global_position = camera_target_node.global_position


## Override to return a fluid density from the current fluid state/ details
func _get_density() -> float:
    if fluid_state == FluidState.AIR:
        return 1.21  # air at ~20C
    elif fluid_state == FluidState.LIQUID:
        return 998.2 # water at ~20C
    else:
        return 0.0   # space

## Override to return a surface area used in drag calculations
func _get_area() -> float:
    return 0.25

## Override to add custom collision handling logic during movement update. Return `true` to mark the
## collisions as handled and stop movement iteration.
func _handle_movement_collisions(collided: bool, collisions: PhysicsTestMotionResult3D) -> bool:
    return false
