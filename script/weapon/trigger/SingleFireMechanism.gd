@tool
@icon("res://icon/weapon_trigger.svg")

## Single fire trigger method, fires only once per action and must wait for
## the cycle time before it can be triggered again.
class_name SingleFireMechanism extends TriggerMechanism


## If the trigger may be held to automatically fire, or if it must be
## released to fire again. This should not be used to create rapid firing
## weapons as it triggers particles and sound on each trigger.
@export var automatic_fire: bool


var _released: bool = true


func actuated() -> void:
    super.actuated()
    _released = false

func update_trigger(triggered: bool) -> void:
    if triggered:
        _weapon_triggered = true
    else:
        _released = true
        _weapon_triggered = false

func should_trigger() -> bool:
    if _weapon_triggered and is_ready():
        if automatic_fire:
            return true

        return _released

    return false

func reset() -> void:
    super.reset()
    _released = true
