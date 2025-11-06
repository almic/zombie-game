@tool
extends BehaviorResourceEditor


var resource: BehaviorSenseHearingSettings


func _set_resource(resource: BehaviorExtendedResource) -> void:
    if resource is BehaviorSenseHearingSettings:
        self.resource = resource
