## Fires as "TRIGGERED" on the tick it is actuated, then as "ONGOING"
## for the duration of the window while actuated.
@tool
class_name GUIDETriggerWindow
extends GUIDETrigger

## Number of seconds to stay ONGOING while actuated
@export var window: float = 0.25

var _accumulator: float = 0

func _update_state(input:Vector3, delta:float, value_type:GUIDEAction.GUIDEActionValueType) -> GUIDETriggerState:

    if _is_actuated(input, value_type):
        if _accumulator == 0:
            _accumulator += delta
            return GUIDETriggerState.TRIGGERED
        
        if _accumulator >= window:
            return GUIDETriggerState.NONE
            
        _accumulator += delta
        return GUIDETriggerState.ONGOING

    _accumulator = 0
    return GUIDETriggerState.NONE

func _editor_name() -> String:
    return "Window"

func _editor_description() -> String:
    return "Fires as \"TRIGGERED\" on the tick it is actuated, then as \"ONGOING\"\n" +\
            "for the duration of the window while actuated."
