@tool
class_name BehaviorSenseHearingSettings extends BehaviorSenseSettings


## Groups that can be heard
@export var target_groups: Array[StringName]

## Quietest sound that can be heard
@export_range(0.0, 40.0, 1.0, 'or_less', 'or_greater', 'suffix:dB')
var min_loudness: float = 10.0

@export_range(100.0, 1000.0, 1.0, 'or_less', 'or_greater', 'suffix:m')
var max_distance: float = 200.0
