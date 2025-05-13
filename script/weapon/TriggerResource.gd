## Implements a trigger method for weapons, controlling how a weapon activates,
## how it spaws particles, and how it hits targets.
class_name TriggerResource extends Resource

## Called once per physics frame, implement per trigger type
func update(_action: GUIDEAction, _base: Weapon, _delta: float) -> void:
    pass

## Handles actual weapon trigger, implement per trigger type to allow
## weapon activation/ deactivation from code, bypassing the action.
func _trigger(_base: Weapon, _activate: bool) -> void:
    pass
