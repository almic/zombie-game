class_name BehaviorGoalInvestigateThresholdSettings extends Resource

@export var type: BehaviorMemorySensory.Type = BehaviorMemorySensory.Type.MAX

@export_range(0, 50, 1, 'or_greater')
var threshold: int = 1
