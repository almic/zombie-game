@tool
@icon("res://icon/weapon_trigger.svg")

## Single fire trigger method, fires only once per action and must wait for
## the cycle time before it can be triggered again. Activates the particle
## and sound on each fire.
class_name TriggerSingleFire extends TriggerResource

## Weapon cycle time, minimum time between consecutive fires
@export var cycle_time: float

## If the trigger may be held to automatically fire, or if it must be
## released to fire again. This should not be used to create rapid firing
## weapons as it triggers particles and sound on each trigger.
@export var automatic_fire: bool

# For weapon cycling
var _weapon_cycle: float = 0
var _weapon_triggered: bool = false

func update(action: GUIDEAction, base: WeaponNode, delta: float) -> void:
    if action.is_completed():
        _weapon_triggered = false

    if _weapon_cycle > 0:
        _weapon_cycle -= delta
        if _weapon_cycle > 0:
            return

    # wait for trigger to release for non-automatic
    if not automatic_fire and _weapon_triggered:
        return

    if action.is_triggered():
        _weapon_cycle = cycle_time
        _weapon_triggered = true
    else:
        return

    _trigger(base, true)

func _trigger(base: WeaponNode, _activate: bool) -> void:
    var space: PhysicsDirectSpaceState3D = base.get_world_3d().direct_space_state
    var transform: Transform3D = base.weapon_tranform()
    var from: Vector3 = transform.origin
    var to: Vector3 = transform.origin - transform.basis.z * base.weapon_type.max_range
    var query := PhysicsRayQueryParameters3D.create(from, to, base.weapon_type.hit_mask)

    query.collide_with_areas = true
    query.collide_with_bodies = false

    var hit := space.intersect_ray(query)
    # DrawLine3d.DrawLine(from, to, Color(0.9, 0.15, 0.15), 5)

    base.play_weapon_effects()

    if not hit:
        return

    if hit.collider is HurtBox:
        var from_node: Node3D = base
        if base.controller:
            from_node = base.controller
        hit.collider.do_hit(from_node, hit, base.weapon_type.damage)
