@tool
@icon("res://icon/weapon_trigger.svg")

## Single fire, double action trigger. Used for weapons that require two actions
## to fire, and can operate as single action.
class_name DoubleActionMechanism extends TriggerMechanism


## Duration of the priming action, in milliseconds
@export_range(0.0, 500.0, 0.1, 'or_greater', 'suffix:ms')
var action_duration: float = 200.0


## If the mechanism skips the action delay on the next actuation.
var primed: bool = false

## Timer for priming under single-action
var _prime_timer: float = 0.0

var _released: bool = true


## Handles weapon cycle, returns leftover delta time that should be passed
## back to the mechanism for additional updates.
func tick(triggered: bool, delta: float) -> float:
    _has_ticked = true
    _actions.clear()

    var used: bool = false

    if _prime_timer > 0.0:
        used = true
        if delta >= _prime_timer:
            delta -= _prime_timer
            _prime_timer = 0.0
            _actions.append(Action.CHARGE)
        else:
            _prime_timer -= delta
            delta = 0.0

    if _delay_timer > 0.0 and delta > 0.0:
        used = true
        if delta >= _delay_timer:
            delta -= _delay_timer
            _delay_timer = 0.0
            _actions.append(Action.FIRE)
        else:
            _delay_timer -= delta
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
    _released = false

    if primed:
        primed = false
    elif action_duration == 0.0:
        _actions.append(Action.CHARGE)
    else:
        _prime_timer = action_duration / 1000.0

    if fire_delay == 0.0:
        _actions.append(Action.FIRE)
    else:
        _delay_timer = fire_delay / 1000.0

    if cycle_time != 0.0:
        if cycle_time < fire_delay:
            push_error('Cycle must be after fire delay!')
        _cycle_timer = (cycle_time - fire_delay) / 1000.0

func update_trigger(triggered: bool) -> void:
    if triggered:
        _weapon_triggered = true
    else:
        _released = true
        _weapon_triggered = false

func should_trigger() -> bool:
    if _weapon_triggered and _delay_timer == 0.0:
        return _released
    return false

func reset() -> void:
    super.reset()
    _released = true

## Hide unused properties of the double action (no charging/ ejecting)
func _validate_property(property: Dictionary) -> void:
    if (
               property.name == &'eject_delay'
            or property.name == &'charge_delay'
            or property.name == &'cycle_time'
    ):
        property.usage = 0
