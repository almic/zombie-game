@tool

class_name Player extends CharacterBody3D

@onready var collider: CollisionShape3D = %collider
@onready var camera_target: Node3D = %CameraTarget
@onready var camera_3d: Camera3D = %Camera3D
@onready var hurtbox: HurtBox = %Hurtbox
@onready var weapon: Weapon = %weapon
@onready var aim_target: RayCast3D = %AimTarget


@export_group("Combat")
@export var health: float = 100

@export_group("Movement")
@export var gravity: float = 9.81
@export var jump_power: float = 5.0
@export var look_speed: float = 0.55

@export_subgroup("Camera", "camera")
@export var camera_smooth_speed: float = 10.0
@export var camera_lag_distance: float = 1.0

@export_subgroup("Moving", "move")
@export var move_acceleration: float = 20.0
@export var move_top_speed: float = 4.8
@export var move_friction: float = 15
@export var move_air_ctl: float = 0.25
@export var move_turn_speed_keep: float = 0.67

@export_subgroup("Stepping", "step")
@export var step_up_max: float = 0.45
@export var step_down_max: float = 0.35

@export_group("Controls")
@export var jump: GUIDEAction
@export var look: GUIDEAction
@export var move: GUIDEAction
@export var fire_primary: GUIDEAction


var is_camera_smoothing: bool = false
var camera_smooth_y: float = 0.0

var is_grounded: bool = true
var was_grounded: bool = true
var just_stepped: bool = false


func _ready() -> void:
    hurtbox.enable()
    hurtbox.on_hit.connect(take_hit)
    aim_target.add_exception(hurtbox)
    aim_target.add_exception(self)

    weapon.set_trigger(fire_primary)

func _process(_delta: float) -> void:
    if Engine.is_editor_hint():
        camera_3d.global_transform = camera_target.global_transform
        return

    rotation_degrees.y -= look.value_axis_2d.x * look_speed
    camera_3d.rotation.y = rotation.y
    camera_3d.rotation_degrees.x = clampf(
        camera_3d.rotation_degrees.x - look.value_axis_2d.y * look_speed,
        -89, 89
    )

func _physics_process(delta: float) -> void:
    if Engine.is_editor_hint():
        return

    was_grounded = is_grounded

    var move_length: float = move.value_axis_3d.length()
    var stationary: bool = is_zero_approx(move_length)

    var move_direction: Vector2
    var move_dot: float = -2 # -2 is a signal value
    var movement: Vector3

    if !stationary:
        var direction: Vector3 = move.value_axis_3d / move_length
        movement = basis * direction
        move_direction = Vector2(movement.x, movement.z) # true direction
        movement *= move_acceleration * delta
    else:
        movement = Vector3.ZERO

    if not is_on_floor():
        is_grounded = false

        # Less control in air (skip if just stepped)
        if not just_stepped:
            movement *= move_air_ctl

        # Gravity
        velocity.y -= gravity * delta
    else:
        is_grounded = true

        # Jumping
        if jump.is_triggered() or jump.is_ongoing():
            velocity.y += jump_power

        # Apply ground friction opposite to direction and movement
        var friction: Vector2 = Vector2(velocity.x, velocity.z)
        if not friction.is_zero_approx():
            if stationary:
                # No movement, full friction
                velocity.x -= velocity.x * move_friction * delta
                velocity.z -= velocity.z * move_friction * delta
            else:
                # Friction opposite to movement
                var speed: float = friction.length()
                var current_direction: Vector2 = friction / speed
                move_dot = clampf(
                    current_direction.dot(move_direction),
                    -1, 1
                )

                if !is_equal_approx(move_dot, 1):
                    # More friction in similar directions, reduce slidey feel when
                    # strafing parallel to main direction
                    var inv_power = move_dot
                    if inv_power > 0:
                        inv_power *= inv_power

                    var friction_accel: float = (1 - inv_power) * move_friction * delta
                    friction *= friction_accel
                    velocity.x -= friction.x
                    velocity.z -= friction.y

                    # Retain some speed when turning
                    var loss: float = speed * friction_accel

                    # Allow counter-strafing at "half" the normal rate, reduce
                    # jumping feel for perfect counter-strafing
                    if inv_power <= 0:
                        loss *= move_turn_speed_keep

                    velocity.x += loss * move_turn_speed_keep * move_direction.x
                    velocity.z += loss * move_turn_speed_keep * move_direction.y

    # Accelerate up to top speed, deccel whichever way
    if !stationary:
        movement.x += velocity.x
        movement.z += velocity.z

        # Enforce maximum additional speed
        movement = movement.limit_length(move_top_speed)

        velocity.x = movement.x
        velocity.z = movement.z

    # Step up on input (stationary), use true displacment (movement * delta)
    var stepped: bool = false
    if (is_grounded or just_stepped) and not stationary:
        stepped = step_up(movement * delta)
        if stepped:
            start_smooth_camera()

    # Update position
    move_and_slide()

    # Step down
    if not (stepped or just_stepped) and was_grounded and not is_grounded and velocity.y <= 0.0:
        if step_down():
            start_smooth_camera()

    # Camera anti-jitter
    smooth_camera(delta)

    just_stepped = stepped

func take_hit(_from: Node3D, _to: HurtBox, _hit: Dictionary, damage: float) -> void:
    # take damage
    health -= damage

    if health > 0:
        return

    print("gah... dead!")

func step_up(movement: Vector3) -> bool:
    var rid := get_rid()
    var result := PhysicsTestMotionResult3D.new()
    var params := PhysicsTestMotionParameters3D.new()

    # Move forward to collision
    var test_transform := global_transform
    params.from = test_transform
    params.motion = movement

    # No hit, no step needed
    if not PhysicsServer3D.body_test_motion(rid, params, result):
        return false

    # Save position and remainder
    test_transform = test_transform.translated(result.get_travel())
    var remainder: Vector3 = result.get_remainder()

    # Step up
    params.from = test_transform
    params.motion = up_direction * step_up_max
    PhysicsServer3D.body_test_motion(rid, params, result)
    test_transform = test_transform.translated(result.get_travel())

    # Forward by remainder
    params.from = test_transform
    params.motion = remainder
    PhysicsServer3D.body_test_motion(rid, params, result)
    test_transform = test_transform.translated(result.get_travel())

    # Slide on walls
    if result.get_collision_count() > 0:
        var dir: Vector3 = movement.normalized()
        var wall_normal: Vector3 = result.get_collision_normal()
        var ddm: float = dir.dot(wall_normal) / (wall_normal * wall_normal).length()
        var slide: Vector3 = (dir - ddm * wall_normal).normalized()

        params.from = test_transform
        params.motion = slide * result.get_remainder().length()

        PhysicsServer3D.body_test_motion(rid, params, result)
        test_transform = test_transform.translated(result.get_travel())

    # Back down to surface to ensure safe ground
    params.from = test_transform
    params.motion = -up_direction * step_up_max

    # Must hit ground
    if not PhysicsServer3D.body_test_motion(rid, params, result):
        return false

    # Must move us up at least epsilon amount
    test_transform = test_transform.translated(result.get_travel())
    const MIN_UP: float = 0.0005
    if ((test_transform.origin - global_position) * up_direction).length() < MIN_UP:
        return false

    # New "ground" must be below our max step height, very important test!
    # Otherwise, spheres/ capsules can climb up to `step + (height / 2)`!
    if result.get_collision_point().y - global_position.y - step_up_max > 0.001:
        return false

    # Respect floor_max_angle
    var space := get_world_3d().direct_space_state
    var from := result.get_collision_point() + up_direction * step_up_max * 2.0
    var to := result.get_collision_point() - up_direction * step_up_max * 2.0
    var raycast := space.intersect_ray(PhysicsRayQueryParameters3D.create(
            from,
            to,
            collision_mask,
            [rid]
    ))
    if raycast and up_direction.angle_to(raycast.normal) > floor_max_angle:
        return false

    # Everything passed, shift player up for move_and_slide()
    global_position.y = test_transform.origin.y
    velocity.y = 0

    return true

func step_down() -> bool:
    # Test if there is ground beneath
    var drop: Vector3 = -up_direction * step_down_max
    var space := get_world_3d().direct_space_state
    var raycast := space.intersect_ray(PhysicsRayQueryParameters3D.create(
            global_position,
            global_position + drop,
            collision_mask,
            [get_rid()]
    ))

    if not raycast:
        return false

    var result := PhysicsTestMotionResult3D.new()
    var params := PhysicsTestMotionParameters3D.new()

    params.from = global_transform
    params.motion = drop
    if not PhysicsServer3D.body_test_motion(get_rid(), params, result):
        return false

    global_transform = global_transform.translated(result.get_travel())
    apply_floor_snap()
    is_grounded = true
    return true

func start_smooth_camera() -> void:
    camera_smooth_y = camera_3d.global_position.y - camera_target.global_position.y
    is_camera_smoothing = true

func smooth_camera(delta: float) -> void:
    camera_3d.global_position = camera_target.global_position

    if not is_camera_smoothing:
        return

    # Anti-jitter with lag limit
    camera_smooth_y = clampf(
            lerpf(camera_smooth_y, 0.0, camera_smooth_speed * delta),
            -camera_lag_distance,
            +camera_lag_distance
    )

    if absf(camera_smooth_y) < 0.001:
        camera_smooth_y = 0.0
        is_camera_smoothing = false
        return

    camera_3d.global_position.y += camera_smooth_y
