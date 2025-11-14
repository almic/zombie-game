@tool
extends BehaviorResourceEditor


static var PROPERTIES: PackedStringArray = [
    'fov',
    'vision_range',
    'mask',
    'target_groups',
]

var resource: BehaviorSenseVisionSettings
var edit_containers: Array[BehaviorPropertyEditorContainer]


func _ready() -> void:
    super._ready()

    if not resource:
        return

    for property in resource.get_property_list():
        if not PROPERTIES.has(property.name):
            continue

        var container: BehaviorPropertyEditorContainer = make_property_editor_container(resource, property)
        container.editor.changed.connect(on_change)
        edit_containers.append(container)
        %Properties.add_child(container)

func _notification(what: int) -> void:
    if what == NOTIFICATION_PREDELETE:
        delete_editors()

func _set_resource(resource: BehaviorExtendedResource) -> void:
    if resource is BehaviorSenseVisionSettings:
        self.resource = resource

func _get_resource() -> BehaviorExtendedResource:
    return resource

func delete_editors() -> void:
    for container in edit_containers:
        if container.editor and container.editor.changed.is_connected(on_change):
            container.editor.changed.disconnect(on_change)
        container.set_editor(null)
        container.set_resource_and_property(null, &'')
