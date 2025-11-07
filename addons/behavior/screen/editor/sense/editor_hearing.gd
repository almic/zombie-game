@tool
extends BehaviorResourceEditor


var resource: BehaviorSenseHearingSettings


func _ready() -> void:
    super._ready()

    if not resource:
        return

    for prop in resource.get_property_list():
        var editor: BehaviorPropertyEditor
        if prop.name == 'min_loudness':
            editor = BehaviorPropertyEditor.get_editor_for_property(resource, prop)
        elif prop.name == 'max_distance':
            editor = BehaviorPropertyEditor.get_editor_for_property(resource, prop)
        elif prop.name == 'target_groups':
            editor = BehaviorPropertyEditor.get_editor_for_property(resource, prop)
        else:
            continue
        editor.changed.connect(on_change)



        %Properties.add_child(editor)


func _set_resource(resource: BehaviorExtendedResource) -> void:
    if resource is BehaviorSenseHearingSettings:
        self.resource = resource

func _get_resource() -> BehaviorExtendedResource:
    return resource
