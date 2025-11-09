@tool
class_name BehaviorBaseEditor extends Control

## Emitted when changing the value
signal changed()


var _is_ghost: bool = true

func _ready() -> void:
    # print('ready %s at path %s' % [get_script().resource_path.get_file(), str(get_path())])
    # NOTE: When the editor opens, it for some reason loads up the old UI
    #       nodes but in a weird SubViewport node and without any state?
    #       Stupid Godot tbh. Check if my parent is named "@SubViewport@".
    if get_parent().name.begins_with('@SubViewport@'):
        # AHHHH
        return
    _is_ghost = false
