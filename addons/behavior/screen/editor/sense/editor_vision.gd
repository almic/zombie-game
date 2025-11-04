@tool
extends Control


var resource: BehaviorSenseVisionSettings:
    set = set_resource


var mask_editor: EditorProperty


func _ready() -> void:
    if not resource:
        push_error('Must have a resource before adding to scene!')
        return

    %FovSlider.share(%FovSpinBox)
    %RangeSlider.share(%RangeSpinBox)

    mask_editor = BehaviorExtendedResource.get_editor_property(resource, &'mask', on_mask_changed)

    %Properties.add_child(mask_editor)

    resource = resource

func on_mask_changed(mask: int) -> void:
    resource.mask = mask

func set_resource(res: BehaviorSenseVisionSettings) -> void:
    resource = res

    if not is_node_ready():
        return

    %FovSlider.value = resource.fov
    %RangeSlider.value = resource.vision_range
    mask_editor.set_object_and_property(resource, 'mask')
    mask_editor.update_property()
