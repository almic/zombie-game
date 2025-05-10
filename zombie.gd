class_name Zombie extends CharacterBody3D

@onready var navigation: NavigationAgent3D = %NavigationAgent3D
@onready var animation_tree: AnimationTree = %AnimationTree


@export_group("Movement")
@export var gravity: float = 9.81

@export_subgroup("Moving", "move")
@export var move_top_speed: float = 4.7
@export var move_acceleration: float = 18
@export var move_ground_friction: float = 15
@export var move_turn_speed_keep: float = 0.6

@export_subgroup("Turning", "rotate")
## Maximum rotation rate in radians/ second
@export var rotate_top_speed: float = TAU
## Rotation acceleration in radians
@export var rotate_acceleration: float = PI / 8
## Rotation decceleration in radians
@export var rotate_decceleration: float = PI / 4
## Seconds to stop rotation if reaching top speed, rotation may stop
## sooner for shorter turns
@export var rotate_stop_time: float = 2
## How close to target to face them regardless of velocity
@export var rotate_face_target_distance: float = 1

## The sign encodes the direction, - is clockwise, + is counter-clockwise
var _rotation_velocity: float = 0

@export_group("Target Detection", "target")
## How far to be aware of potential targets
@export var target_search_radius: float = 50

## Target groups to search for
@export var target_search_groups: Array[String]
var _active_target: Node3D = null

## Deviation for randomized target updates, important for performance of many agents
## Randomization is always clamped to the relevant update rate
@export var target_update_deviation: float = 0.2

## How long it takes to search for a new target
@export var target_search_rate: float = 3
var _target_search_accumulator: float = randfn(0.0, 0.2)

## How often to update target location, influences rotation
@export var target_update_rate: float = 1
var _target_update_accumulator: float = randfn(0.0, 0.2)

## If a target's updated position deviates this far, recalculate pathing
@export var target_update_distance: float = 0.5

## Switch for simple chase while waiting for pathing update
var _simple_move: bool = false

@export_group("Animation", "anim")

@export var anim_idle: String = "idle"
@export var anim_attack: String = "attack"
@export var anim_run: String = "run"

@export_group("Attacking", "attack")

## How close must the target be in order to attack
@export var attack_range: float = 1.24
## How nearly facing the target in order to attack
@export var attack_facing: float = 0.67

## Locomotion state machine
var locomotion: AnimationNodeStateMachinePlayback

func _ready() -> void:
    locomotion = animation_tree["parameters/Locomotion/playback"]
    navigation.velocity_computed.connect(_on_velocity_computed)

func _process(_delta: float) -> void:
    pass

func _physics_process(delta: float) -> void:
    if NavigationServer3D.map_get_iteration_id(navigation.get_navigation_map()) == 0:
        return

    var new_velocity: Vector3 = velocity

    # Only path on ground
    if not is_on_floor():
        # Gravity
        new_velocity.y -= gravity * delta

        if navigation.avoidance_enabled:
            navigation.velocity = new_velocity
        else:
            _on_velocity_computed(new_velocity)

        # Do not spin in air
        # update_rotation()
        return

    update_target_position(delta)

    if _active_target == null:
        if new_velocity.length_squared() > 0:
            # friction
            new_velocity.x -= new_velocity.x * move_ground_friction * delta
            new_velocity.z -= new_velocity.z * move_ground_friction * delta
            _on_velocity_computed(new_velocity)
        anim_goto(locomotion, anim_idle)
        return

    var move_direction: Vector3

    # dont move if attacking
    if locomotion.get_current_node() == anim_attack:
        move_direction = Vector3.ZERO
    elif _simple_move:
        move_direction = get_simple_move_direction()
    elif not navigation.is_navigation_finished():
        var next_pos: Vector3 = navigation.get_next_path_position()
        move_direction = global_position.direction_to(next_pos)
    else:
        _simple_move = true
        move_direction = get_simple_move_direction()

    if is_zero_approx(move_direction.length_squared()):
        if new_velocity.length_squared() > 0:
            # friction
            new_velocity.x -= new_velocity.x * move_ground_friction * delta
            new_velocity.z -= new_velocity.z * move_ground_friction * delta
            _on_velocity_computed(new_velocity)

        # If attacking, dont rotate and queue back to idle
        if locomotion.get_current_node() == anim_attack:
            anim_goto(locomotion, anim_idle)
        else:
            # Check if me are close enough to attack and facing the right way
            var target_dist_sqr: float = global_position.distance_squared_to(_active_target.global_position)
            var target_facing: float = basis.z.dot(global_position.direction_to(_active_target.global_position))
            if target_dist_sqr <= attack_range ** 2 and target_facing >= attack_facing:
                anim_goto(locomotion, anim_attack)
            else:
                update_rotation(delta)
        return

    # Apply ground friction opposite to movement
    var speed: float = velocity.length_squared()
    if is_zero_approx(speed):
        anim_goto(locomotion, anim_idle)
    else:
        speed = sqrt(speed)

        if speed >= 0.5:
            anim_goto(locomotion, anim_run)
        else:
            # Return to idle when too slow
            anim_goto(locomotion, anim_idle)

        var friction: Vector2 = Vector2(velocity.x, velocity.z)
        var current_direction: Vector2 = friction / speed
        var move_dot = clampf(
            current_direction.dot(
                Vector2(move_direction.x, move_direction.z)
            ),
            -1, 1
        )

        if !is_equal_approx(move_dot, 1):
            # More friction in similar directions, reduce slidey feel when
            # strafing parallel to main direction
            var inv_power = move_dot
            if inv_power > 0:
                inv_power *= inv_power

            var friction_accel: float = (1 - inv_power) * move_ground_friction * delta
            friction *= friction_accel
            new_velocity.x -= friction.x
            new_velocity.z -= friction.y

            # Retain some speed when turning
            var loss: float = speed * friction_accel

            # Allow counter-strafing at "half" the normal rate, reduce
            # jumping feel for perfect counter-strafing
            if inv_power <= 0:
                loss *= move_turn_speed_keep

            new_velocity.x += loss * move_turn_speed_keep * move_direction.x
            new_velocity.z += loss * move_turn_speed_keep * move_direction.z

    # Accelerate up to top speed, deccel whichever way
    var movement: Vector3 = move_direction * move_acceleration * delta
    movement.x += new_velocity.x
    movement.z += new_velocity.z

    # Enforce maximum additional speed
    var len_sqr: float = movement.length_squared()
    if len_sqr > move_top_speed ** 2:
        movement = (movement / sqrt(len_sqr)) * move_top_speed

    new_velocity.x = movement.x
    new_velocity.z = movement.z

    # Must be set otherwise we get garbage velocities in our callback
    navigation.avoidance_enabled = !_simple_move

    if navigation.avoidance_enabled:
        navigation.velocity = new_velocity
    else:
        _on_velocity_computed(new_velocity)

    update_rotation(delta)

func _on_velocity_computed(safe_velocity: Vector3) -> void:
    velocity = safe_velocity
    move_and_slide()

func on_attack_start() -> void:
    pass

func on_attack_end() -> void:
    pass

func update_rotation(delta: float) -> void:
    var direction: Vector3 = Vector3(velocity.x, 0, velocity.z)
    var stationary: float = direction.length_squared() < 0.5

    # When (nearly) stationary, or close to target, try to face the target
    if stationary or (_active_target and \
         global_position.distance_squared_to(
        _active_target.global_position) <= rotate_face_target_distance ** 2
    ):
        if not _active_target:
            return

        direction = Vector3(
                global_position.x,
                0,
                global_position.z
            ).direction_to(Vector3(
                _active_target.global_position.x,
                0,
                _active_target.global_position.z
            ))
    else:
        direction = direction.normalized()

    # Nearly facing the right direction
    if is_equal_approx(basis.z.dot(direction), 1):
        if is_zero_approx(_rotation_velocity):
            return

        _rotation_velocity = 0
        rotate_y(direction.signed_angle_to(basis.z, -Vector3.UP))
        return

    # Turn to face current direction of motion
    var rads_to_go: float = direction.signed_angle_to(basis.z, -Vector3.UP)
    var acceleration: float = 0
    if is_zero_approx(_rotation_velocity):
        # Simply accelerate
        acceleration = rotate_acceleration
    elif not is_equal_approx(signf(rads_to_go), signf(_rotation_velocity)):
        # Turning the wrong way, use decceleration speed
        acceleration = rotate_decceleration
    else:
        # 1. Can we start deccelerating now and still reach the target, and
        # 2. if we did, will we reach it in no more than "stop" seconds?
        var time: float = absf(_rotation_velocity) / rotate_decceleration
        var time_needed: float = 2 * rads_to_go / _rotation_velocity * delta

        if time >= time_needed and time_needed <= rotate_stop_time:
            # start slowing down
            acceleration = -rotate_decceleration
        else:
            acceleration = rotate_acceleration

    # Accelerate to top speed
    _rotation_velocity = clampf(
        _rotation_velocity + acceleration * delta * signf(rads_to_go),
        -rotate_top_speed, rotate_top_speed
    )

    rotate_y(_rotation_velocity)

func get_simple_move_direction() -> Vector3:
    var dist: float = global_position.distance_squared_to(_active_target.global_position)
    var desired_squared: float = navigation.target_desired_distance ** 2
    if dist > desired_squared:
        return global_position.direction_to(_active_target.global_position)
    return Vector3.ZERO

func update_target_position(delta: float) -> void:
    if _active_target != null:
        # check to update target position
        if _target_update_accumulator < target_update_rate:
            _target_update_accumulator += delta
            return

        var deviation: float = _active_target.global_position.distance_squared_to(
            navigation.target_position
        )

        if deviation > target_update_distance:
            navigation.target_position = _active_target.global_position
            _simple_move = false

        _target_update_accumulator = randomize_accumulator(
            target_update_rate
        ) + delta

        return

    if _target_search_accumulator > target_search_rate:
        # reset accumulator
        _target_search_accumulator = randomize_accumulator(target_search_rate)

        # we assume there are few enough potential targets that iterating
        # them all is okay
        var targets: Array[Node3D] = []
        var scene_tree: SceneTree = get_tree()
        for group in target_search_groups:
            var nodes: Array[Node] = scene_tree.get_nodes_in_group(group)
            for node in nodes:
                if node is not Node3D:
                    continue

                if node not in targets:
                    targets.append(node)

        # make closest option the target
        var closest: Node3D = null
        var closest_dist: float = INF
        for target in targets:
            var dist: float = global_position.distance_squared_to(
                target.global_position
            )

            if dist < closest_dist:
                closest = target
                closest_dist = dist

        if closest != null:
            _active_target = closest
            navigation.target_position = _active_target.global_position
            _simple_move = false
            return

    _target_search_accumulator += delta

func randomize_accumulator(range_max: float) -> float:
    return clamp(
        randfn(0.0, target_update_deviation),
        -range_max, range_max
    )

func anim_goto(
        state_machine: AnimationNodeStateMachinePlayback,
        state: String,
        reset: bool = false
) -> void:
    if not reset and state_machine.get_current_node() == state:
        return

    state_machine.travel(state, reset)
