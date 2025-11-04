@tool
class_name BehaviorMindSettings extends BehaviorExtendedResource


@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_STORAGE)
var sense_vision: BehaviorSenseVisionSettings

@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_STORAGE)
var sense_hearing: BehaviorSenseHearingSettings


func _init() -> void:
    sense_vision = BehaviorSenseVisionSettings.new()
    sense_hearing = BehaviorSenseHearingSettings.new()
