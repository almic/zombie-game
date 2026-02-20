@tool
@icon("res://icon/weapon_trigger.svg")

## Implements a trigger method for weapons, controlling how a weapon activates.
class_name TriggerMechanism extends Resource

## If the trigger may be held to automatically fire, or if it must be released
## to fire again.
@export var automatic_fire: bool

## Initial delay, in milliseconds, when actuated before a projectile fires
@export_range(0, 50.0, 0.1, 'or_greater', 'suffix:ms')
var fire_delay: float = 0

## Time when a chambered round ejects, must be after the fire delay and before
## the cycle time. Set to zero to disable automatic ejection. This means the
## weapon must be manually cycled via animations.
@export_range(0, 100.0, 0.1, 'or_greater', 'suffix:ms')
var eject_delay: float = 0

## Time when the next round is chambered, must be after the eject delay.
## Set to zero to disable weapon charging. This means the weapon must be manually
## charged via animations.
@export_range(0, 100.0, 0.1, 'or_greater', 'suffix:ms')
var charge_delay: float = 0

## Weapon reset time, after all other steps have completed.
@export_range(0.1, 50.0, 0.1, 'or_greater', 'suffix:ms')
var reset_delay: float = 10.0


## If the mechanism actuated on the previous call to tick()
var actuated: bool = false

## If the trigger is currently pressed
var triggered: bool = false

## If the mechanism has a bullet to fire
var can_fire: bool = false

## If the trigger needs to be released before the mechanism can actuate again
var needs_reset: bool = false


var _delay_timer: float = 0
var _eject_timer: float = 0
var _charge_timer: float = 0
var _reset_timer: float = 0

enum Action {
    FIRE,
    EJECT,
    CHARGE
}

## Order of actions to apply when ticking the mechanism
var _actions: PackedInt32Array = []


## Visualize the overall cycle time and fire rate
func _get_property_list() -> Array[Dictionary]:
    return [
        {
            'name': &'cycle_time',
            'type': TYPE_FLOAT,
            'hint': PROPERTY_HINT_RANGE,
            'hint_string': '0,400,0.1,or_greater,hide_control,suffix:ms',
            'usage': PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY,
        },
        {
            'name': &'fire_rate',
            'type': TYPE_FLOAT,
            'hint': PROPERTY_HINT_RANGE,
            'hint_string': '0,1000,0.1,or_greater,hide_control,suffix:rpm',
            'usage': PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY,
        }
    ]

func _get(name: StringName) -> Variant:
    if name == &'cycle_time':
        return fire_delay + eject_delay + charge_delay + reset_delay
    elif name == &'fire_rate':
        var rpm: float = fire_delay + eject_delay + charge_delay + reset_delay
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

    if _delay_timer > 0.0:
        used = true
        if delta >= _delay_timer:
            delta -= _delay_timer
            _delay_timer = 0.0
            if can_fire:
                fire()
            else:
                # Clear other timers
                _eject_timer = 0.0
                _charge_timer = 0.0
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

    if _reset_timer > 0.0 and delta > 0.0:
        used = true
        if delta >= _reset_timer:
            delta -= _reset_timer
            _reset_timer = 0.0
        else:
            _reset_timer -= delta
            delta = 0.0


    if _reset_timer <= 0.0 and should_trigger():
        actuate()
        actuated = true
    elif not used:
        delta = 0.0

    return delta

## The mechanism has been actuated and will soon fire a round
func actuate() -> void:
    if fire_delay == 0.0:
        if can_fire:
            fire()
        else:
            _reset_timer = reset_delay / 1000.0
            return
    else:
        _delay_timer = fire_delay / 1000.0

    if eject_delay != 0.0:
        _eject_timer = eject_delay / 1000.0

    if charge_delay != 0.0:
        _charge_timer = charge_delay / 1000.0

    if reset_delay != 0.0:
        _reset_timer = reset_delay / 1000.0

## Actions to perform on the weapon
func get_actions() -> PackedInt32Array:
    return _actions

## Reset trigger mechanism state
func reset() -> void:
    _actions.clear()
    _delay_timer = 0.0
    _eject_timer = 0.0
    _charge_timer = 0.0
    _reset_timer = 0.0
    actuated = false
    can_fire = false
    triggered = false

## Update the user input to the trigger
func update_trigger(pressed: bool) -> void:
    if needs_reset:
        if pressed:
            return
        needs_reset = false
        triggered = false
    else:
        triggered = pressed

## Update the ability of the mechanism to fire and do a full cycle
func update_can_fire(value: bool) -> void:
    can_fire = value

## Handles actual weapon trigger, implement per trigger type.
func should_trigger() -> bool:
    if not triggered:
        return false

    if automatic_fire:
        return true

    if needs_reset:
        return false

    return true

func fire() -> void:
    _actions.append(Action.FIRE)
    if automatic_fire:
        return
    needs_reset = true
