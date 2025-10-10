## Logical goal, processes memories and calls actions
@abstract
class_name BehaviorGoal extends Resource


enum Priority {
    LOWEST = 1,
    LOW = 10,
    MEDIUM = 50,
    HIGH = 100,
    HIGHEST = Vector3i.MAX.x
}


## Name for differentiating goals of the same type
@export var code_name: StringName = &"GOAL"


@export_group("Interest Activated")

@export_custom(PROPERTY_HINT_GROUP_ENABLE, '')
var interest_activated: bool = false

## Threshold of interest value to process this goal
@export_range(0, 100, 1)
var interest_threshold: int = 0


@export_group("Sense Activated")

@export_custom(PROPERTY_HINT_GROUP_ENABLE, '')
var sense_activated: bool = false

## Which senses this goal is responsive to
@export var sense_code_names: Array[StringName]

## If the goal should be checked regardless of senses every X seconds, set this
## to a value greater than zero. Leave at zero to only respond when senses are
## activated.
@export_range(0, 10, 1, 'or_greater', 'hide_slider', 'suffix:sec')
var minimum_period: int = 0


## Unique name of this goal type.
## Classes should also have a constant NAME member, and this method should
## simply return that constant.
@abstract func name() -> StringName

""

## Process memories and return a desired call priority. Return `0` to skip being
## called during the action phase, larger values are called earlier.
@abstract func update_priority(mind: BehaviorMind) -> int

""

## Calls actions to be taken as part of this goal, called only if 'update_priority'
## returned a positive value, in order relative to other active goals.
@abstract func perform_actions(mind: BehaviorMind) -> void
