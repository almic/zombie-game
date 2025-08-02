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


var _hitbox_timer: float


func update_input(_base: WeaponNode, action: GUIDEAction) -> void:
    _weapon_triggered = action.is_triggered()


func _update_trigger(base: WeaponNode, delta: float) -> void:
    if _weapon_triggered and is_cycled() and base.hitbox:
        _hitbox_timer = delay + duration
        base.play_weapon_effects()
        start_cycle()

    _update_hitbox(base, delta)


func _update_hitbox(base: WeaponNode, delta: float) -> void:
    if not base.hitbox:
        return

    if _hitbox_timer > 0.0:
        _hitbox_timer -= delta

    if base.hitbox.is_enabled():
        if _hitbox_timer <= 0.0:
            base.hitbox.disable()
    elif _hitbox_timer > 0.0 and _hitbox_timer <= duration:
        base.hitbox.damage = base.weapon_type.damage
        base.hitbox.collision_mask = base.weapon_type.hit_mask
        base.hitbox.enable()
