@tool
extends BehaviorResourceEditor


static var PROPERTIES: PackedStringArray = [
    'fov',
    'vision_range',
    'mask',
    'target_groups',
]

var resource: BehaviorSenseVisionSettings


func _ready() -> void:
    super._ready()

    if not resource:
        return

    var editors := get_property_editors(resource, PROPERTIES, on_change)
    for editor in editors:
        var container: ExpandableContainer = make_property_override_container(editor)
        %Properties.add_child(container)


func _set_resource(resource: BehaviorExtendedResource) -> void:
    if resource is BehaviorSenseVisionSettings:
        self.resource = resource

func _get_resource() -> BehaviorExtendedResource:
    return resource
