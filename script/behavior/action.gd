## Represents an action,
@abstract
class_name BehaviorAction


## Unique name of this action type.
## Classes should also have a constant NAME member, and this method should
## simply return that constant.
@abstract func name() -> StringName

""

## If the action supports completion at a later time. This should either always
## return true, or always return false.
@abstract func can_complete() -> bool

""

## Called when an action is completed. Should only be called when `can_complete()`
## returns `true`. It is up to the implementing class to set some internal state
## so that `is_complete()` returns `true` after this method is called.
func complete() -> void:
    pass

## Implemented by extending class. Should always return `false` until the method
## `complete()` is called, and then it should always return `true` after.
func is_complete() -> bool:
    return false
