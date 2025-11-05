@tool
extends Control


var resource: BehaviorSenseVisionSettings:
    set(value):
        if is_node_ready():
            push_error('Cannot change resource once added to scene!')
            return
        resource = value


func _ready() -> void:
    if not resource:
        push_error('Must have a resource before adding to scene!')
        return

    for prop in resource.get_property_list():
        if prop.name == 'fov':
            %Properties.add_child(BehaviorPropertyEditor.get_editor_for_property(resource, prop))
        elif prop.name == 'vision_range':
            %Properties.add_child(BehaviorPropertyEditor.get_editor_for_property(resource, prop))
        elif prop.name == 'mask':
            %Properties.add_child(BehaviorPropertyEditor.get_editor_for_property(resource, prop))
