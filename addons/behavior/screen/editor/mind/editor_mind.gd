@tool
extends BehaviorResourceEditor


var resource: BehaviorMindSettings


func _ready() -> void:
    super._ready()
    if _is_ghost:
        return

    for sub_resource_name in get_sub_resource_names():
        var container: ExpandableContainer = make_sub_resource_override_container(resource, sub_resource_name)
        %SubResources.add_child(container)

func _set_resource(resource: BehaviorExtendedResource) -> void:
    if resource is BehaviorMindSettings:
        self.resource = resource

func _get_resource() -> BehaviorExtendedResource:
    return resource

func on_save() -> void:
    super.on_save()

    for container in %SubResources.get_children():
        if container is ExpandableContainer:
            var editor = container.get_child(0)
            if editor is BehaviorResourceEditor:
                editor.on_save()

func get_sub_resource_names() -> PackedStringArray:
    return [
        &'sense_vision',
        &'sense_hearing',
    ]

func accept_editors(editors: Array[BehaviorResourceEditor]) -> void:
    var i: int = 0
    for e in editors:
        connect_editor(e)
        var container: ExpandableContainer = %SubResources.get_child(i) as ExpandableContainer
        container.set_expandable_control(e)
        i += 1

func connect_editor(editor: BehaviorResourceEditor) -> void:
    if not editor.changed.is_connected(on_change):
        editor.changed.connect(on_change)
    if not editor.saved.is_connected(on_save):
        editor.saved.connect(on_save)

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
