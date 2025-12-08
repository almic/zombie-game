## Implements a trigger method for weapons, controlling how a weapon activates.
class_name TriggerMechanism extends Resource


## Initial delay, in milliseconds, when actuated before a projectile fires
@export_range(0, 100.0, 0.1, 'or_greater', 'suffix:ms')
var fire_delay: float = 0

## Weapon cycle time, in milliseconds, minimum time between consecutive triggers.
## Set to zero to disable weapon cycling. This means the weapon must be manually
## cycled via animations.
@export_range(0, 500.0, 0.1, 'or_greater', 'suffix:ms')
var cycle_time: float = 0


var _delay_timer: float = 0
var _cycle_timer: float = 0


## For weapon activation
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

## Set when fire delay elapses, or after calling actuate() with no delay
var _fire_this_tick: bool = false

## Set when cycle time elapses
var _cycle_this_tick: bool = false


## Handles weapon cycle, returns leftover delta time that should be passed
## back to the mechanism for additional updates.
func tick(triggered: bool, delta: float) -> float:
    _has_ticked = true
    _fire_this_tick = false
    _cycle_this_tick = false
    var used: bool = false

    if _delay_timer > 0.0:
        used = true
        if delta >= _delay_timer:
            delta -= _delay_timer
            _delay_timer = 0.0
            _fire_this_tick = true
        else:
            _delay_timer -= delta
            delta = 0.0

    if _cycle_timer > 0.0 and delta > 0.0:
        used = true
        if delta >= _cycle_timer:
            delta -= _cycle_timer
            _cycle_timer = 0.0
            _cycle_this_tick = true
        else:
            _cycle_timer -= delta
            delta = 0.0

    if not used:
        delta = 0.0

    update_trigger(triggered)
    return delta

## The mechanism has been actuated and will soon fire a round
func actuated() -> void:
    if fire_delay == 0.0:
        _fire_this_tick = true
    else:
        _delay_timer = fire_delay / 1000.0
    if cycle_time != 0.0:
        _cycle_timer = cycle_time / 1000.0

## If the mechanism should fire on this tick
func fire_this_tick() -> bool:
    return _fire_this_tick

## If the mechanism should cycle on this tick
func cycle_this_tick() -> bool:
    return _cycle_this_tick

## The mechanism is ready to actuate
func is_ready() -> bool:
    return _cycle_timer == 0

## Reset trigger mechanism state
func reset() -> void:
    _fire_this_tick = false
    _cycle_this_tick = false
    _cycle_timer = 0.0
    _delay_timer = 0.0

    # HACK: force the trigger state to reset
    _has_ticked = true
    _weapon_triggered = false
    _has_ticked = false

## Called at least once per frame, may be called multiple times.
## Implement per trigger type.
@warning_ignore("unused_parameter")
func update_trigger(triggered: bool) -> void:
    pass

## Handles actual weapon trigger, implement per trigger type.
func should_trigger() -> bool:
    return false
