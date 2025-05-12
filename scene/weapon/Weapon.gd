@tool
class_name Weapon extends Node3D

@onready var mesh: MeshInstance3D = %mesh


@export var weapon_type: WeaponResource
@export var target: RayCast3D
@export var target_update_speed: float = 15
@export var target_update_rate: int = 3

# For moving weapon to face target
var _weapon_target_from: Quaternion
var _weapon_target_to: Quaternion
var _weapon_target_tick: int = 0
var _weapon_target_amount: float = 0

# For weapon cycling
var _weapon_cycle: float = 0
var _weapon_triggered: bool = false

func _ready() -> void:
    mesh.mesh = weapon_type.mesh
    position = weapon_type.offset

func _process(delta: float) -> void:
    if Engine.is_editor_hint():
        if weapon_type:
            mesh.mesh = weapon_type.mesh
            position = weapon_type.offset
        return

    if _weapon_target_to.is_equal_approx(mesh.global_basis.get_rotation_quaternion()):
        return

    _weapon_target_amount += target_update_speed * delta
    mesh.global_basis = Basis(
        _weapon_target_from.slerp(_weapon_target_to, _weapon_target_amount)
    )

func _physics_process(delta: float) -> void:
    if Engine.is_editor_hint():
        return

    if _weapon_cycle > 0:
        _weapon_cycle -= delta

    _weapon_target_tick += 1
    if _weapon_target_tick < target_update_rate:
        return
    _weapon_target_tick = 0

    if target.is_colliding():
        # DrawLine3d.DrawLine(mesh.global_position, target.get_collision_point(), Color(0.2, 0.25, 0.8), 1)
        _weapon_target_to = Quaternion(
            Basis.looking_at(
                mesh.global_position.direction_to(
                    target.get_collision_point()
                ), target.basis.y
            )
        )
    else:
        # Aim forward
        _weapon_target_to = target.global_basis.get_rotation_quaternion()

    _weapon_target_from = mesh.global_basis.get_rotation_quaternion()
    _weapon_target_amount = 0

func trigger(action: GUIDEAction) -> void:

    if action.is_completed():
        _weapon_triggered = false

    if _weapon_cycle > 0:
        return

    # wait for trigger to release
    if not weapon_type.automatic and _weapon_triggered:
        return

    if action.is_triggered():
        _weapon_cycle = weapon_type.cycle_time
        _weapon_triggered = true
    else:
        return

    var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
    var from: Vector3 = mesh.global_position
    var to: Vector3 = mesh.global_position - mesh.global_basis.z * weapon_type.max_range
    var query := PhysicsRayQueryParameters3D.create(from, to, weapon_type.raycast_mask)

    query.collide_with_areas = true
    query.collide_with_bodies = false

    var hit := space.intersect_ray(query)
    DrawLine3d.DrawLine(from, to, Color(0.9, 0.15, 0.15), 5)
    if not hit:
        return

    if hit.collider is HurtBox:
        hit.collider.do_hit(self, weapon_type.damage)
