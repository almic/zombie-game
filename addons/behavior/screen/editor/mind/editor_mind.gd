@tool
extends BehaviorResourceEditor


var resource: BehaviorMindSettings
var edit_containers: Array[BehaviorResourceEditorContainer]


func _exit_tree() -> void:
    disconnect_editors()

func _set_resource(resource: BehaviorExtendedResource) -> void:
    if resource is BehaviorMindSettings:
        self.resource = resource

func _get_resource() -> BehaviorExtendedResource:
    return resource

func get_sub_resource_names() -> PackedStringArray:
    return [
        &'sense_vision',
        &'sense_hearing',
    ]

func accept_editors(editors: Array[BehaviorResourceEditor]) -> void:
    disconnect_editors()

    var sub_resource_names := get_sub_resource_names()
    var i: int = 0
    for e in editors:
        var container: BehaviorResourceEditorContainer
        if i < edit_containers.size():
            container = edit_containers[i]
            container.set_resource_and_property(resource, sub_resource_names[i])
        else:
            container = make_resource_editor_container(resource, sub_resource_names[i])
            edit_containers.append(container)
            %SubResources.add_child(container)
        container.set_editor(e)
        e.changed.connect(on_change)
        i += 1

func disconnect_editors() -> void:
    for container in edit_containers:
        if container.editor.changed.is_connected(on_change):
            container.editor.changed.disconnect(on_change)
        container.set_editor(null)
        container.set_resource_and_property(null, &'')
