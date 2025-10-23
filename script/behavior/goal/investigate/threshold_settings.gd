class_name BehaviorGoalInvestigateInterestSettings extends Resource


## The type of sensory memory
@export var type: BehaviorMemorySensory.Type = BehaviorMemorySensory.Type.MAX

## Interest needed to turn towards something
@export_range(0, 10, 1, 'or_greater')
var turn: int = 2

## Interest needed to navigate towards something
@export_range(0, 10, 1, 'or_greater')
var navigate: int = 5

## Overall multiplier to interest for this event type. Use this, for example, to
## make sight more important than sound even when both meet turn/ navigation
## target values.
@export_range(0.0, 2.0, 0.01, 'or_greater')
var multiplier: float = 1.0
