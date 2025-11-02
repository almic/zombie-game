@tool
extends MarginContainer


var resource: BehaviorMindSettings
var is_saved: bool = true


func _ready() -> void:
    pass

func save(failed: bool = false) -> bool:
    if is_saved:
        return false

    if failed:
        is_saved = false
        return true

    is_saved = true
    return true
