## Implements a trigger method for weapons, controlling how a weapon activates.
class_name TriggerMechanism extends Resource


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

## Toggled by update_input and tick to prevent missed input.
var _has_ticked: bool = false


## Handles weapon cycle
func tick(delta: float) -> void:
    _has_ticked = true

    if _weapon_cycle > 0.0:
        _weapon_cycle -= delta

func start_cycle() -> void:
    _weapon_cycle = cycle_time

func is_cycled() -> bool:
    return not _weapon_cycle > 0.0

## Called once per frame, implement per trigger type.
@warning_ignore('unused_parameter')
func update_trigger(triggered: bool) -> void:
    pass

## Handles actual weapon trigger, implement per trigger type.
func should_trigger() -> bool:
    return false
