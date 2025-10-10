## Container for logic related to a sense, saves memories
@abstract
class_name BehaviorSense extends Resource


@warning_ignore("unused_signal")
signal on_sense(sense: BehaviorSense)


## If this sense is currently enabled
@export var enabled: bool = true

## Name for differentiating senses of the same type
@export var code_name: StringName = &"SENSE"

## Frequency of sensory updates, number of ticks between updates
@export var frequency: int = 30
var _tick_timer: int = 0

## Set by the sense when it has been activated. Used for goals responsive to
## specific senses. Cleared by the BehaviorMind during the update phase.
var activated: bool = false


## Updates the tick timer of the sense, returns `true` when the timer resets.
func tick() -> bool:
    if not enabled:
        return false

    _tick_timer -= 1
    if _tick_timer < 1:
        _tick_timer = frequency
        return true
    return false


## Unique name of this sense type.
## Classes should also have a constant NAME member, and this method should
## simply return that constant.
@abstract func name() -> StringName

""

## Logical function for this sense. Called every physics frame. Should only
## modify information on memories relevant to the current mind.
@abstract func sense(mind: BehaviorMind) -> void
