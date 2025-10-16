@icon("res://addons/guide/guide_internal.svg")
class_name GUIDETriggerComboStep
extends Resource

@export var action:GUIDEAction
@export_flags("Triggered:1", "Started:2", "Ongoing:4", "Cancelled:8","Completed:16")
var completion_events:int = GUIDETriggerCombo.ActionEventType.TRIGGERED
@export var time_to_actuate:float = 0.5


func is_same_as(other:GUIDETriggerComboStep) -> bool:
	return action == other.action and \
		completion_events == other.completion_events and \
		is_equal_approx(time_to_actuate, other.time_to_actuate)

var _has_fired:bool = false

func _prepare():
	_connect(GUIDETriggerCombo.ActionEventType.TRIGGERED, action.triggered)
	_connect(GUIDETriggerCombo.ActionEventType.STARTED, action.started)
	_connect(GUIDETriggerCombo.ActionEventType.ONGOING, action.ongoing)
	_connect(GUIDETriggerCombo.ActionEventType.CANCELLED, action.cancelled)
	_connect(GUIDETriggerCombo.ActionEventType.COMPLETED, action.completed)
	_has_fired = false

func _connect(type: GUIDETriggerCombo.ActionEventType, to: Signal) -> void:
	if completion_events & type:
		if not to.is_connected(_fired):
			to.connect(_fired)
	else:
		if to.is_connected(_fired):
			to.disconnect(_fired)

func _fired():
	_has_fired = true
