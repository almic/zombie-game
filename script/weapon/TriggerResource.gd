## Implements a trigger method for weapons, controlling how a weapon activates,
## how it spaws particles, and how it hits targets.
class_name TriggerResource extends Resource


## Weapon cycle time, minimum time between consecutive triggers
@export var cycle_time: float = 1.0

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

## Toggled by update_input and tick to prevent missed input
@warning_ignore('unused_private_class_variable')
var _has_ticked: bool = false

## Called once per frame, implement per trigger type. Returns true if the weapon
## should be triggered.
@warning_ignore('unused_parameter')
func update_input(base: WeaponNode, action: GUIDEAction) -> void:
    pass

## Handles actual weapon trigger.
func tick(base: WeaponNode, delta: float) -> void:
    _has_ticked = true

    if _weapon_cycle > 0.0:
        _weapon_cycle -= delta

    _update_trigger(base, delta)

func start_cycle() -> void:
    _weapon_cycle = cycle_time

func is_cycled() -> bool:
    return not _weapon_cycle > 0.0


## Handles actual weapon trigger, implement per trigger type.
@warning_ignore('unused_parameter')
func _update_trigger(base: WeaponNode, delta: float) -> void:
    pass
