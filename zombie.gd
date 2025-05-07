class_name Zombie extends CharacterBody3D

@onready var navigation: NavigationAgent3D = %NavigationAgent3D


@export_category("Movement")
@export var gravity: float = 9.81
@export var move_accel: float = 18
@export var move_top_speed: float = 4.7
@export var move_friction: float = 15
@export var move_turn_speed_keep: float = 0.6

@export_group("Target Detection", "target")
## How far to be aware of potential targets
@export var target_search_radius: float = 50

## Target groups to search for
@export var target_search_groups: Array[String]
var _active_target: Node3D = null

## Deviation for randomized target updates, important for performance of many agents
## Randomization is always clamped to the relevant update rate
@export var update_deviation: float = 0.2

## How long it takes to search for a new target
@export var target_search_rate: float = 5
var _target_search_accumulator: float = randfn(0.0, 0.2)

## How often to update target location
@export var target_update_rate: float = 1
var _target_update_accumulator: float = randfn(0.0, 0.2)

## If a target's updated position deviates this far, recalculate pathing
@export var target_update_distance: float = 0.25

## Switch for simple chase while waiting for pathing update
var _simple_move: bool = false


func _ready() -> void:
    navigation.velocity_computed.connect(_on_velocity_computed)
    
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
        return
        
    update_target_position(delta)
    
    if _active_target == null:
        return
        
    var move_direction: Vector3 = Vector3.ZERO

    # stick with simple move first
    if _simple_move:
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
            new_velocity.x -= new_velocity.x * move_friction * delta
            new_velocity.z -= new_velocity.z * move_friction * delta
            _on_velocity_computed(new_velocity)
        return
    
    # Apply ground friction opposite to movement
    var speed: float = velocity.length_squared()
    if speed > 0:
        speed = sqrt(speed)
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
                
            var friction_accel: float = (1 - inv_power) * move_friction * delta
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
    var movement: Vector3 = move_direction * move_accel * delta
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
    
func _on_velocity_computed(safe_velocity: Vector3) -> void:
    velocity = safe_velocity
    move_and_slide()

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
        randfn(0.0, update_deviation),
        -range_max, range_max
    )
