## Implements a trigger method for weapons, controlling how a weapon activates.
class_name TriggerMechanism extends Resource


## Weapon cycle time, minimum time between consecutive triggers
@export var cycle_time: float = 1.0

## If this mechanism uses hitboxes instead of projectiles
@export var is_melee: bool = false

## For weapon cycling
@warning_ignore('unused_private_class_variable')
var _weapon_cycle: float = 0

## For weapon activation
@warning_ignore('unused_private_class_variable')
var _weapon_triggered: bool = false:
    set(value):
        if not value:
            if _has_ticked:
                _weapon_triggered = false
        else:
            _weapon_triggered = true
            _has_ticked = false

## Toggled by update_input and tick to prevent missed input.
var _has_ticked: bool = false


## Handles actual weapon trigger.
func tick(base: WeaponNode, delta: float) -> bool:
    _has_ticked = true

    if _weapon_cycle > 0.0:
        _weapon_cycle -= delta

    var result: bool = _should_trigger()

    if is_melee:
        _update_melee(base, delta)

    return result

func start_cycle() -> void:
    _weapon_cycle = cycle_time

func is_cycled() -> bool:
    return not _weapon_cycle > 0.0


## Called once per frame, implement per trigger type.
@warning_ignore('unused_parameter')
func update_input(action: GUIDEAction) -> void:
    pass

## Handles actual weapon trigger, implement per trigger type.
func _should_trigger() -> bool:
    return false

## Handles melee weapon trigger, implement per trigger type.
@warning_ignore('unused_parameter')
func _update_melee(base: WeaponNode, delta: float) -> void:
    pass
