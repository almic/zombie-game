@tool
@icon("res://icon/weapon_trigger.svg")

## Single fire, double action trigger. Used for weapons that require two actions
## to fire, and can operate as single action.
class_name DoubleActionMechanism extends TriggerMechanism


## Duration of the priming action, in milliseconds
@export_range(0.0, 500.0, 0.1, 'or_greater', 'suffix:ms')
var prime_delay: float = 200.0


## If the mechanism skips the action delay on the next actuation.
var primed: bool = false


## Timer for priming under single-action
var _prime_timer: float = 0.0


func _get(name: StringName) -> Variant:
    if name == &'cycle_time':
        return prime_delay + fire_delay
    elif name == &'fire_rate':
        var rpm: float = prime_delay + fire_delay
        if is_zero_approx(rpm):
            return INF
        return 60000.0 / rpm

    return null


## Handles weapon cycle, returns leftover delta time that should be passed
## back to the mechanism for additional updates.
func tick(delta: float) -> float:
    actuated = false
    _actions.clear()

    var used: bool = false

    if _prime_timer > 0.0:
        if primed:
            # NOTE: some animations may be active which charge the weapon
            #       so do not double-charge and do not use any delta
            _prime_timer = 0.0
        elif delta >= _prime_timer:
            used = true
            delta -= _prime_timer
            _prime_timer = 0.0
            _actions.append(Action.CHARGE)
        else:
            used = true
            _prime_timer -= delta
            delta = 0.0

    if _delay_timer > 0.0 and delta > 0.0:
        used = true
        if delta >= _delay_timer:
            delta -= _delay_timer
            _delay_timer = 0.0
            _actions.append(Action.FIRE)
            primed = false
        else:
            _delay_timer -= delta
            delta = 0.0

    if _delay_timer <= 0.0 and should_trigger():
        actuate()
        actuated = true
        needs_reset = true
    elif not used:
        delta = 0.0

    return delta

## The mechanism has been actuated and will soon fire a round
func actuate() -> void:
    if primed:
        if fire_delay == 0.0:
            _actions.append(Action.FIRE)
            primed = false
        else:
            _delay_timer = fire_delay / 1000.0
    elif prime_delay == 0.0:
        _actions.append(Action.CHARGE)
        if fire_delay == 0.0:
            _actions.append(Action.FIRE)
            primed = false
        else:
            _delay_timer = fire_delay / 1000.0
    else:
        _prime_timer = prime_delay / 1000.0
        if fire_delay == 0.0:
            _delay_timer = 0.0001
        else:
            _delay_timer = fire_delay / 1000.0

## Hide unused properties of the double action (no charging/ ejecting)
func _validate_property(property: Dictionary) -> void:
    if (
               property.name == &'automatic_fire'
            or property.name == &'eject_delay'
            or property.name == &'charge_delay'
            or property.name == &'reset_delay'
    ):
        property.usage = 0
