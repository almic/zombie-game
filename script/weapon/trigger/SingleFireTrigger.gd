@tool
@icon("res://icon/weapon_trigger.svg")

## Single fire trigger method, fires only once per action and must wait for
## the cycle time before it can be triggered again. Activates the particle
## and sound on each fire.
class_name SingleFireTrigger extends TriggerResource


## If the trigger may be held to automatically fire, or if it must be
## released to fire again. This should not be used to create rapid firing
## weapons as it triggers particles and sound on each trigger.
@export var automatic_fire: bool

var _released: bool = false

func update_input(_base: WeaponNode, action: GUIDEAction) -> void:
    if action.is_completed():
        _released = true
        _weapon_triggered = false

    # wait for trigger to release for non-automatic
    if _weapon_triggered and not automatic_fire:
        return

    if action.is_triggered():
        _weapon_triggered = true


func _update_trigger(base: WeaponNode, delta: float) -> void:
    if not _weapon_triggered or not is_cycled():
        return

    if not automatic_fire and not _released:
        return

    base.play_weapon_effects()
    start_cycle()
    _released = false

    _do_raycasts(base)

func _do_raycasts(base: WeaponNode) -> void:
    var space: PhysicsDirectSpaceState3D = base.get_world_3d().direct_space_state
    var transform: Transform3D = base.weapon_tranform()
    var from: Vector3 = transform.origin
    var to: Vector3 = transform.origin - transform.basis.z * base.weapon_type.max_range
    var query := PhysicsRayQueryParameters3D.create(from, to, base.weapon_type.hit_mask)

    query.collide_with_areas = true
    query.collide_with_bodies = false

    var hit := space.intersect_ray(query)
    # DrawLine3d.DrawLine(from, to, Color(0.9, 0.15, 0.15), 5)

    if not hit:
        return

    if hit.collider is HurtBox:
        var from_node: Node3D = base
        if base.controller:
            from_node = base.controller
        hit['from'] = from
        hit.collider.do_hit(from_node, hit, base.weapon_type.damage)
