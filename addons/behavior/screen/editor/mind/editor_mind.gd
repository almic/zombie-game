@tool
extends BehaviorResourceEditor


var resource: BehaviorMindSettings


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
    # Disconnect any current editors
    for container in %SubResources.get_children():
        if container is BehaviorResourceEditorContainer:
            if container.editor.changed.is_connected(on_change):
                container.editor.changed.disconnect(on_change)
            container.set_editor(null)
            container.set_resource_and_property(null, &'')

    var sub_resource_names := get_sub_resource_names()
    var i: int = 0
    for e in editors:
        var container: BehaviorResourceEditorContainer
        if i < %SubResources.get_child_count():
            container = %SubResources.get_child(i) as BehaviorResourceEditorContainer
            container.set_resource_and_property(resource, sub_resource_names[i])
        else:
            container = make_sub_resource_override_container(resource, sub_resource_names[i])
            %SubResources.add_child(container)
        container.set_editor(e)
        e.changed.connect(on_change)
        i += 1

func _set_extendable(btn: Button, extendable: bool, extend_func) -> void:
    for c in btn.pressed.get_connections():
        btn.pressed.disconnect(c.callable)

    if extendable:
        btn.text = 'Extend'
        btn.tooltip_text = 'Create a new resource that inherits from the current resource and load it'
        btn.pressed.connect(extend_func.bind(false))
    else:
        btn.text = 'Save As'
        btn.tooltip_text = 'Save this sub resource to the file system and reference it'
        btn.pressed.connect(extend_func.bind(true))
