## Stores some type of information
@abstract
class_name BehaviorMemory extends Resource


@export_group("Debug", "debug")
## Name for debugging
@export var debug_name: StringName = &"MEMORY"


## Unique name of this memory type.
## Classes should also have a constant NAME member, and this method should
## simply return that constant.
@abstract func name() -> StringName

""

## If the memory supports decay over time. Must return `true` if you want the
## `decay()` method to be called. This should either always return true, or
## always return false.
@abstract func can_decay() -> bool

""

## Called when an internal delta accumulator exceeds a frequency rate, and only
## if `can_decay()` returns true.
@warning_ignore("unused_parameter")
func decay(seconds: float) -> void:
    pass
