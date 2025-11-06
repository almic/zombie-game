@tool
extends BehaviorResourceEditor


var resource: BehaviorSenseVisionSettings


func _ready() -> void:
    if not resource:
        push_error('Must have a resource before adding to scene!')
        return

    for prop in resource.get_property_list():
        var editor: BehaviorPropertyEditor
        if prop.name == 'fov':
            editor = BehaviorPropertyEditor.get_editor_for_property(resource, prop)
        elif prop.name == 'vision_range':
            editor = BehaviorPropertyEditor.get_editor_for_property(resource, prop)
        elif prop.name == 'mask':
            editor = BehaviorPropertyEditor.get_editor_for_property(resource, prop)
        else:
            continue
        editor.changed.connect(on_change)
        %Properties.add_child(editor)

func _set_resource(resource: BehaviorExtendedResource) -> void:
    if resource is BehaviorSenseVisionSettings:
        self.resource = resource
