@tool
@icon("res://icon/weapon_trigger.svg")

## Single fire trigger method, fires only once per action and must wait for
## the cycle time before it can be triggered again. Activates the particle
## and sound on each fire.
class_name SingleFireMechanism extends TriggerMechanism


## If the trigger may be held to automatically fire, or if it must be
## released to fire again. This should not be used to create rapid firing
## weapons as it triggers particles and sound on each trigger.
@export var automatic_fire: bool


var _released: bool = false


func update_input(action: GUIDEAction) -> void:
    if action.is_completed():
        _released = true
        _weapon_triggered = false

    # wait for trigger to release for non-automatic
    if _weapon_triggered and not automatic_fire:
        return

    if action.is_triggered():
        _weapon_triggered = true


func _should_trigger() -> bool:
    if not _weapon_triggered or not is_cycled():
        return false

    if not automatic_fire and not _released:
        return false

    _released = false
    return true
