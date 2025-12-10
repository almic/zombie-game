## Implements a trigger method for weapons, controlling how a weapon activates.
class_name TriggerMechanism extends Resource


## Initial delay, in milliseconds, when actuated before a projectile fires
@export_range(0, 100.0, 0.1, 'or_greater', 'suffix:ms')
var fire_delay: float = 0

## Time when a chambered round ejects, must be after the fire delay and before
## the cycle time. Set to zero to disable automatic ejection. This means the
## weapon must be manually cycled via animations.
@export_range(0, 200.0, 0.1, 'or_greater', 'suffix:ms')
var eject_delay: float = 0

## Time when the next round is chambered, must be after the eject delay.
## Set to zero to disable weapon charging. This means the weapon must be manually
## charged via animations.
@export_range(0, 300.0, 0.1, 'or_greater', 'suffix:ms')
var charge_delay: float = 0

## Weapon fire rate, in milliseconds, minimum time between consecutive triggers.
@export_range(0, 500.0, 0.1, 'or_greater', 'suffix:ms')
var cycle_time: float = 100


var _delay_timer: float = 0
var _eject_timer: float = 0
var _charge_timer: float = 0
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

## Toggled by update_trigger and tick to prevent missed input.
var _has_ticked: bool = false


enum Action {
    FIRE,
    EJECT,
    CHARGE
}

## Order of actions to apply when ticking the mechanism
var _actions: PackedInt32Array = []


## Handles weapon cycle, returns leftover delta time that should be passed
## back to the mechanism for additional updates.
func tick(triggered: bool, delta: float) -> float:
    _has_ticked = true
    _actions.clear()

    var used: bool = false

    if _delay_timer > 0.0:
        used = true
        if delta >= _delay_timer:
            delta -= _delay_timer
            _delay_timer = 0.0
            _actions.append(Action.FIRE)
        else:
            _delay_timer -= delta
            delta = 0.0

    if _eject_timer > 0.0 and delta > 0.0:
        used = true
        if delta >= _eject_timer:
            delta -= _eject_timer
            _eject_timer = 0.0
            _actions.append(Action.EJECT)
        else:
            _eject_timer -= delta
            delta = 0.0

    if _charge_timer > 0.0 and delta > 0.0:
        used = true
        if delta >= _charge_timer:
            delta -= _charge_timer
            _charge_timer = 0.0
            _actions.append(Action.CHARGE)
        else:
            _charge_timer -= delta
            delta = 0.0

    if _cycle_timer > 0.0 and delta > 0.0:
        used = true
        if delta >= _cycle_timer:
            delta -= _cycle_timer
            _cycle_timer = 0.0
        else:
            _cycle_timer -= delta
            delta = 0.0

    if not used:
        delta = 0.0

    update_trigger(triggered)
    return delta

## The mechanism has been actuated and will soon fire a round
func actuated() -> void:
    var offset: float = 0

    if fire_delay == 0.0:
        _actions.append(Action.FIRE)
    else:
        offset = fire_delay
        _delay_timer = fire_delay / 1000.0

    if eject_delay != 0.0:
        if eject_delay < offset:
            push_error('Eject must be after firing!')
        _eject_timer = (eject_delay - offset) / 1000.0
        offset = eject_delay

    if charge_delay != 0.0:
        if charge_delay < offset:
            push_error('Charge must be after firing and ejecting!')
        _charge_timer = (charge_delay - offset) / 1000.0
        offset = charge_delay

    if cycle_time != 0.0:
        if cycle_time < offset:
            push_error('Cycle must be the latest time!')
        _cycle_timer = (cycle_time - offset) / 1000.0

## Actions to perform on the weapon
func get_actions() -> PackedInt32Array:
    return _actions

## The mechanism is ready to actuate
func is_ready() -> bool:
    return _cycle_timer == 0

## Reset trigger mechanism state
func reset() -> void:
    _actions.clear()
    _delay_timer = 0.0
    _eject_timer = 0.0
    _charge_timer = 0.0
    _cycle_timer = 0.0

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
