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
var floor_max_slope: float = deg_to_rad(60.0):
    set = set_floor_max_slope
var floor_max_cos_theta: float = -1
## Minimum angle to slide along walls when moving
@export_custom(PROPERTY_HINT_RANGE, '0.01,90,0.01,radians_as_degrees')
var wall_slide_angle: float = deg_to_rad(4.0):
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
@export var step_snap_down_max: float = 0.45
## Extra forward distance test for stepping up stairs
@export var step_up_forward_test: float = 0.15
## Minimum forward distance when testing stair steps, can help walking up stairs
## which the character is immediately next to, where initial acceleration may
## not be enough.
@export var step_up_min_forward: float = 0.04
## The angle between the forward motion and the ground contact in which to step
## along the contact normal. Greater angles will test along the direction of
## motion. This allows characters to walk tangent to steps and travel up them.
@export_custom(PROPERTY_HINT_RANGE, '0.01,90,0.01,radians_as_degrees')
var step_up_max_contact_angle: float = deg_to_rad(75.0):
    set = set_up_max_contact_angle
var step_up_max_contact_cos_theta: float = -1
## Extra forward distance to test for sticking to the ground when the character
## has upward velocity
@export var step_snap_down_forward_test: float = 0.15
@export_custom(PROPERTY_HINT_RANGE, '0.01,90,0.01,radians_as_degrees')
var step_snap_down_max_angle: float = deg_to_rad(5.0):
    set = set_snap_down_max_angle
var step_snap_down_max_cos_theta: float = -1

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

## If the camera is currently smoothing
var is_camera_smoothing: bool = false
var camera_smooth_offset: Vector3 = Vector3.ZERO

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

func set_up_max_contact_angle(max_contact_angle: float) -> void:
    step_up_max_contact_angle = max_contact_angle
    step_up_max_contact_cos_theta = cos(max_contact_angle)

func set_snap_down_max_angle(snap_max_angle: float) -> void:
    step_snap_down_max_angle = snap_max_angle
    step_snap_down_max_cos_theta = cos(snap_max_angle)

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

    # Input acceleration
    if not stationary:
        var speed_in_dir: float = velocity.dot(movement_direction)
        if speed_in_dir < top_speed:
            var movement: float = move_acceleration * delta

            # air control
            if not grounded:
                movement *= move_air_control

            velocity += movement_direction * minf(top_speed - speed_in_dir, movement)

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

    # Update velocity from forces
    velocity += friction + drag + gravity_force

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
    var step_accumulation: Vector3
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

            ground_details = make_ground_details(
                normal,
                collisions.get_collision_point(i),
                collisions.get_collider(i)
            )

        if not average_floor_normal.is_zero_approx():
            average_floor_normal = average_floor_normal.normalized()

        if not average_wall_normal.is_zero_approx():
            average_wall_normal = average_wall_normal.normalized()

            # Check if we have any motion left to step with here
            if not stationary:
                var step_start: Vector3 = global_position
                var new_remainder: Vector3 = step_up(remainder, movement_direction, average_wall_normal)
                step_accumulation += (global_position - step_start) - (remainder - new_remainder)
                remainder = new_remainder

        to_move = remainder

        # Slide against up direction for walls
        if not average_wall_normal.is_zero_approx():
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
            # On "flat" ground, do not slide down.
            # Do this by removing downward vertical motion before sliding
            if up_direction.dot(average_floor_normal) >= floor_max_cos_theta:
                var move_dot_up: float = to_move.dot(up_direction)
                if move_dot_up < 0:
                    to_move -= up_direction * move_dot_up

            # From Godot's character body, better slide direction on slopes
            var to_slide: Vector3 = up_direction.cross(to_move).cross(average_floor_normal).normalized()
            to_move = to_slide * to_move.slide(average_floor_normal).length()

    var real_velocity: Vector3 = (global_position - last_position) - step_accumulation

    #if not step_accumulation.is_zero_approx():
        #print('frame ' + str(Engine.get_physics_frames()))
        #print('last = ' + str(last_position))
        #print('new = ' + str(global_position))
        #print('step = ' + str(step_accumulation))
        #print('new velocity = ' + str(real_velocity))
        #print('-------------------')

    # Snap to floor if we just detached from the ground
    if grounded and not ground_details.has_ground():
        var do_forward_test: bool = real_velocity.dot(up_direction) > 0
        var forward_test_direction: Vector3
        if do_forward_test:
            forward_test_direction = real_velocity.slide(up_direction)
            if not forward_test_direction.is_zero_approx():
                forward_test_direction = forward_test_direction.normalized()
        if snap_down(do_forward_test, forward_test_direction):
            pass
            #start_camera_smooth()
        real_velocity = (global_position - last_position) - step_accumulation

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
    if cos_theta - 1.0 > -0.000001:
        return Vector3.ZERO

    var angle: float = acos(cos_theta)

    # More friction in similar directions, reduce slidey feel when
    # strafing perpendicular to direction of motion
    if cos_theta > 0.5:
        cos_theta = angle * (2 / PI)

    var loss: float = (1.0 - cos_theta) * friction

    # Retain some speed when turning
    var keep: float = pow(turn_rate, angle * RAD_15)

    # Allow counter-strafing at "half" the normal rate, reduces jumpy feeling
    if cos_theta <= 0.0:
        keep *= keep

    return -direction * loss + wish_direction * loss * keep


## Tries to step up using the remainder distance, updates the ground details when
## successful, returns the new remainder travel distance
func step_up(remainder: Vector3, step_direction: Vector3, contact_normal: Vector3) -> Vector3:
    var step_forward: Vector3 = remainder.slide(up_direction)
    if step_forward.is_zero_approx():
        step_forward = step_direction * step_up_min_forward
    else:
        var remainder_length: float = remainder.length()
        step_forward = step_forward.normalized() * maxf(step_up_min_forward, remainder_length)

    var step_test: Vector3 = (-contact_normal).slide(up_direction)
    if step_test.is_zero_approx() or step_test.dot(step_direction) < step_up_max_contact_cos_theta:
        #print('testing with forward')
        #print('dot = ' + str(step_test.dot(step_direction)))
        #print('max = ' + str(step_up_max_contact_cos_theta))
        step_test = step_direction
    else:
        #print('testing with contact')
        #print('dot = ' + str(step_test.dot(step_direction)))
        #print('max = ' + str(step_up_max_contact_cos_theta))
        step_test = step_test.normalized()

    step_test *= step_up_forward_test

    var test_motion: PhysicsTestMotionParameters3D = PhysicsTestMotionParameters3D.new()
    var test_result: PhysicsTestMotionResult3D = PhysicsTestMotionResult3D.new()
    var rid: RID = get_rid()
    var up: Vector3 = up_direction * step_up_max

    # Move up
    test_motion.from = global_transform
    test_motion.motion = up
    # TODO: test setting this to zero to save on time/ memory, only needed in
    #       the final motion to get a ground
    test_motion.max_collisions = 4

    if PhysicsServer3D.body_test_motion(rid, test_motion, test_result):
        if test_result.get_travel().length_squared() < 0.000001:
            #print('could not move up')
            return remainder
        up *= test_result.get_collision_safe_fraction()

    # Move forward
    test_motion.from = test_motion.from.translated(up)
    test_motion.motion = step_forward

    if PhysicsServer3D.body_test_motion(rid, test_motion, test_result):
        if test_result.get_travel().length_squared() < 0.000001:
            #print('could not move forward')
            return remainder
        step_forward *= test_result.get_collision_safe_fraction()

    # Move down, need a floor
    test_motion.from = test_motion.from.translated(step_forward)
    test_motion.motion = -up

    if PhysicsServer3D.body_test_motion(rid, test_motion, test_result):
        # If we don't hit early enough, cancel the step
        if test_result.get_remainder().length_squared() < 0.000001:
            #print('not high enough to step')
            return remainder
    else:
        #print('missed the floor')
        return remainder


    var average_normal: Vector3
    var last_normal: Vector3

    var average_contact: Vector3

    var best_ground_dot: float = -INF
    var new_ground: GroundDetails

    for i in range(test_result.get_collision_count()):
        average_contact += test_result.get_collision_point(i)

        var normal: Vector3 = test_result.get_collision_normal(i)
        if normal.is_equal_approx(last_normal):
            continue

        average_normal += normal
        last_normal = normal

        var dot: float = normal.dot(up_direction)
        if not dot > best_ground_dot:
            continue

        new_ground = make_ground_details(
            normal,
            test_result.get_collision_point(i),
            test_result.get_collider(i)
        )

    # Contact point must be within step up max distance
    average_contact /= test_result.get_collision_count()
    average_contact -= test_motion.from.translated(-up).origin

    if average_contact.dot(up_direction) > step_up_max + 0.001:
        #print('greater than max step ' + str(average_contact.dot(up_direction)))
        #print('contact = ' + str(average_contact))
        #print('from = ' + str(test_motion.from.translated(-up).origin))
        return remainder

    # If the floor is too steep, try with the test forward
    average_normal = average_normal.normalized()
    if average_normal.dot(up_direction) < floor_max_cos_theta:

        # No extra test, no step
        if step_test.is_zero_approx():
            #print('steep floor, no extra testing')
            return remainder

        # Move forward with the test
        test_motion.from = global_transform.translated(up)
        test_motion.motion = step_test

        if PhysicsServer3D.body_test_motion(rid, test_motion, test_result):
            if test_result.get_travel().length_squared() < 0.000001:
                #print('steep floor, could not move forward')
                return remainder
            step_test *= test_result.get_collision_safe_fraction()

        # Move down, need a floor
        test_motion.from = test_motion.from.translated(step_test)
        test_motion.motion = -up

        if PhysicsServer3D.body_test_motion(rid, test_motion, test_result):
            # If we don't hit early enough, cancel the step
            if test_result.get_remainder().length_squared() < 0.000001:
                #print('steep floor, not enough of a step')
                return remainder
        else:
            #print('steep floor, missed floor')
            return remainder

        average_normal = Vector3.ZERO
        last_normal = Vector3.ZERO
        average_contact = Vector3.ZERO
        best_ground_dot = -INF
        for i in range(test_result.get_collision_count()):
            average_contact += test_result.get_collision_point(i)

            var normal: Vector3 = test_result.get_collision_normal(i)
            if normal.is_equal_approx(last_normal):
                continue

            average_normal += normal
            last_normal = normal

            var dot: float = normal.dot(up_direction)
            if not dot > best_ground_dot:
                continue

            new_ground = make_ground_details(
                normal,
                test_result.get_collision_point(i),
                test_result.get_collider(i)
            )

        # Contact point must be within step up max distance
        average_contact /= test_result.get_collision_count()
        average_contact -= test_motion.from.translated(-up).origin

        if average_contact.dot(up_direction) > step_up_max + 0.001:
            #print('steep floor, greater than max step ' + str(average_contact.dot(up_direction)))
            return remainder

        average_normal = average_normal.normalized()
        if average_normal.dot(up_direction) < floor_max_cos_theta:
            # Use a raycast instead to
            # Test fails too, give up
            #print('steep floor, steep test')
            #print('hit normal = ' + str(average_normal))
            return remainder

        # Set for the remainder update
        step_forward = step_test

    # Step passed, update position, remainder, and ground
    up *= test_result.get_collision_safe_fraction()
    ground_details = new_ground
    global_transform = test_motion.from.translated(-up)

    if not remainder.is_zero_approx():
        var remainder_length: float = remainder.length()
        remainder *= maxf(0.0, remainder_length - step_forward.length()) / remainder_length

    #print('stepped up!')

    return remainder


func snap_down(do_forward_test: bool, forward: Vector3) -> bool:
    var drop: Vector3 = -up_direction * step_snap_down_max
    var extra_test: Vector3 = -up_direction * 0.1
    var space := get_world_3d().direct_space_state
    var raycast := space.intersect_ray(PhysicsRayQueryParameters3D.create(
            global_position,
            global_position + drop + extra_test,
            collision_mask,
            [get_rid()]
    ))

    if not raycast:
        #print('could not find current ground')
        #print('frame ' + str(Engine.get_physics_frames()))
        #print('from = ' + str(global_position))
        #print('to = ' + str(global_position + drop))
        #print('----------------')
        return false

    if up_direction.dot(raycast.normal) < floor_max_cos_theta:
        #print('current floor too steep')
        return false

    if do_forward_test:
        var ground_normal = raycast.normal
        forward *= step_snap_down_forward_test
        forward += global_position
        raycast = space.intersect_ray(PhysicsRayQueryParameters3D.create(
                forward,
                forward + drop,
                collision_mask,
                [get_rid()]
        ))

        if not raycast:
            #print('forward test failed to hit')
            return false

        if ground_normal.dot(raycast.normal) <= step_snap_down_max_cos_theta:
            #print('angle between surfaces is too great')
            return false

    var result := PhysicsTestMotionResult3D.new()
    var params := PhysicsTestMotionParameters3D.new()

    params.from = global_transform
    params.motion = drop
    if not PhysicsServer3D.body_test_motion(get_rid(), params, result):
        #print('failed to hit ground')
        return false

    if result.get_travel().length_squared() < 0.000001:
        #print('too little down to snap')
        return false

    ground_details = make_ground_details(
        result.get_collision_normal(0),
        result.get_collision_point(0),
        result.get_collider(0)
    )

    drop *= result.get_collision_safe_fraction()
    global_transform = global_transform.translated(drop)

    #print('snapped down!')

    return true


static func make_ground_details(normal: Vector3, contact_point: Vector3, body: Object) -> GroundDetails:
    var ground_details: GroundDetails = GroundDetails.new()

    ground_details.normal = normal
    ground_details.position = contact_point
    ground_details.body = body
    if ground_details.body is PhysicsBody3D:
        var phys_body: PhysicsBody3D = ground_details.body as PhysicsBody3D
        ground_details.velocity = (
                PhysicsServer3D.body_get_direct_state(phys_body.get_rid())
                .get_velocity_at_local_position(ground_details.position - phys_body.global_position)
        )

    return ground_details

func start_camera_smooth() -> void:
    camera_smooth_offset = camera_node.global_position - camera_target_node.global_position
    is_camera_smoothing = true

func smooth_camera(delta: float) -> void:
    camera_node.global_position = camera_target_node.global_position
    if true or not is_camera_smoothing:
        return

    camera_smooth_offset = camera_smooth_offset.lerp(Vector3.ZERO, camera_smooth_speed * delta)

    if camera_smooth_offset.length_squared() < 0.000001:
        camera_smooth_offset = Vector3.ZERO
        is_camera_smoothing = false
        return

    camera_smooth_offset = camera_smooth_offset.clampf(-camera_lag_distance, camera_lag_distance)

    camera_node.global_position += up_direction * camera_smooth_offset.dot(up_direction)


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
