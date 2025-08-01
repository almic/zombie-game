@tool
@icon("res://icon/weapon_trigger.svg")

## Melee trigger, toggles a hitbox which can trigger hurtboxes.
class_name MeleeTrigger extends TriggerResource


## After triggering, how long to delay before enabling the hitbox.
@export var delay: float = 0.0

## How long the hitbox stays enabled. Use zero to remain enabled as long as the
## trigger is active.
@export_range(0.0, 2.0, 0.001, 'or_greater')
var duration: float = 1.0

## Weapon cycle time, minimum time between consecutive triggers
@export var cycle_time: float = 1.0


var _hitbox_timer: float
var _weapon_cycle: float = 0


func update(action: GUIDEAction, base: WeaponNode, delta: float) -> void:
    if _weapon_cycle > 0.0:
        _weapon_cycle -= delta
        _hitbox_timer -= delta
        _update_hitbox(base)
        if _weapon_cycle > 0.0:
            return

    if action.is_triggered() or action.is_ongoing():
        _trigger(base, true)


func _trigger(base: WeaponNode, activate: bool) -> void:
    if not base.hitbox:
        return

    if activate:
        _hitbox_timer = delay + duration
        _weapon_cycle = cycle_time
        base.play_weapon_effects()
    else:
        _hitbox_timer = 0.0
        _weapon_cycle = 0.0

    _update_hitbox(base)


func _update_hitbox(base: WeaponNode) -> void:
    if not base.hitbox:
        return

    if base.hitbox.is_enabled():
        if _hitbox_timer <= 0.0:
            base.hitbox.disable()
    elif _hitbox_timer > 0.0 and _hitbox_timer <= duration:
        base.hitbox.damage = base.weapon_type.damage
        base.hitbox.collision_mask = base.weapon_type.hit_mask
        base.hitbox.enable()
