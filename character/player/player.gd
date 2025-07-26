@tool

class_name Player extends CharacterBase

@onready var camera_target: Node3D = %CameraTarget
@onready var camera_3d: Camera3D = %Camera3D
@onready var hurtbox: HurtBox = %Hurtbox
@onready var weapon: Weapon = %weapon
@onready var aim_target: RayCast3D = %AimTarget


@export_group("Combat")
@export var health: float = 100

@export_group("Movement")
@export var look_speed: float = 0.55

@export_group("Controls")
@export var jump: GUIDEAction
@export var look: GUIDEAction
@export var move: GUIDEAction
@export var fire_primary: GUIDEAction


var is_camera_smoothing: bool = false
var camera_smooth_y: float = 0.0


func _ready() -> void:
    if not Engine.is_editor_hint():
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

    var move_length: float = move.value_axis_3d.length()

    if is_zero_approx(move_length):
        movement_direction = Vector3.ZERO
    else:
        movement_direction = basis * move.value_axis_3d.normalized()

    if jump.is_triggered() or jump.is_ongoing():
        do_jump()

    update_movement(delta)

func take_hit(_from: Node3D, _to: HurtBox, _hit: Dictionary, damage: float) -> void:
    # take damage
    health -= damage

    if health > 0:
        return

    print("gah... dead!")

func step_up_old(movement: Vector3) -> bool:
    #var rid := get_rid()
    #var result := PhysicsTestMotionResult3D.new()
    #var params := PhysicsTestMotionParameters3D.new()
#
    ## Move forward to collision
    #var test_transform := global_transform
    #params.from = test_transform
    #params.motion = movement
#
    ## No hit, no step needed
    #if not PhysicsServer3D.body_test_motion(rid, params, result):
        #return false
#
    ## Save position and remainder
    #test_transform = test_transform.translated(result.get_travel())
    #var remainder: Vector3 = result.get_remainder()
#
    ## Step up
    #params.from = test_transform
    #params.motion = up_direction * step_up_max
    #PhysicsServer3D.body_test_motion(rid, params, result)
    #test_transform = test_transform.translated(result.get_travel())
#
    ## Forward by remainder
    #params.from = test_transform
    #params.motion = remainder
    #PhysicsServer3D.body_test_motion(rid, params, result)
    #test_transform = test_transform.translated(result.get_travel())
#
    ## Slide on walls
    #if result.get_collision_count() > 0:
        #var dir: Vector3 = movement.normalized()
        #var wall_normal: Vector3 = result.get_collision_normal()
        #var ddm: float = dir.dot(wall_normal) / (wall_normal * wall_normal).length()
        #var slide: Vector3 = (dir - ddm * wall_normal).normalized()
#
        #params.from = test_transform
        #params.motion = slide * result.get_remainder().length()
#
        #PhysicsServer3D.body_test_motion(rid, params, result)
        #test_transform = test_transform.translated(result.get_travel())
#
    ## Back down to surface to ensure safe ground
    #params.from = test_transform
    #params.motion = -up_direction * step_up_max
#
    ## Must hit ground
    #if not PhysicsServer3D.body_test_motion(rid, params, result):
        #return false
#
    ## Must move us up at least epsilon amount
    #test_transform = test_transform.translated(result.get_travel())
    #const MIN_UP: float = 0.0005
    #if ((test_transform.origin - global_position) * up_direction).length() < MIN_UP:
        #return false
#
    ## New "ground" must be below our max step height, very important test!
    ## Otherwise, spheres/ capsules can climb up to `step + (height / 2)`!
    #if result.get_collision_point().y - global_position.y - step_up_max > 0.001:
        #return false
#
    ## Respect floor_max_angle
    #var space := get_world_3d().direct_space_state
    #var from := result.get_collision_point() + up_direction * step_up_max * 2.0
    #var to := result.get_collision_point() - up_direction * step_up_max * 2.0
    #var raycast := space.intersect_ray(PhysicsRayQueryParameters3D.create(
            #from,
            #to,
            #collision_mask,
            #[rid]
    #))
    #if raycast and up_direction.angle_to(raycast.normal) > floor_max_angle:
        #return false
#
    ## Everything passed, shift player up for move_and_slide()
    #global_position.y = test_transform.origin.y
    #velocity.y = 0

    return true

func step_down() -> bool:
    # Test if there is ground beneath
    #var drop: Vector3 = -up_direction * step_down_max
    #var space := get_world_3d().direct_space_state
    #var raycast := space.intersect_ray(PhysicsRayQueryParameters3D.create(
            #global_position,
            #global_position + drop,
            #collision_mask,
            #[get_rid()]
    #))
#
    #if not raycast:
        #return false
#
    #var result := PhysicsTestMotionResult3D.new()
    #var params := PhysicsTestMotionParameters3D.new()
#
    #params.from = global_transform
    #params.motion = drop
    #if not PhysicsServer3D.body_test_motion(get_rid(), params, result):
        #return false
#
    #global_transform = global_transform.translated(result.get_travel())
    #apply_floor_snap()
    #is_grounded = true
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
