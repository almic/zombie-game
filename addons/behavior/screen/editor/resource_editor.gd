@abstract
@tool
class_name BehaviorResourceEditor extends Control


## Emitted when a value is modified in this editor, or in a sub editor
signal changed()

## Emitted when this editor is marked as saved
signal saved()


var is_saved: bool = true


func _ready() -> void:
    # print('ready %s with parent %s' % [get_script().resource_path.get_file(), get_parent().name])
    # NOTE: When the editor opens, it for some reason loads up the old UI
    #       nodes but in a weird SubViewport node and without any state?
    #       Stupid Godot tbh. Check if my parent is named "@SubViewport@".
    if get_parent().name.begins_with('@SubViewport@'):
        return

    if not get_resource():
        push_error('Must have a resource before adding to scene (%s)!' % get_script().resource_path)
        return

## Sets the resource for this editor
@abstract func _set_resource(resource: BehaviorExtendedResource) -> void

''

## Get the resource of this editor
@abstract func _get_resource() -> BehaviorExtendedResource

''

func set_resource(resource: BehaviorExtendedResource) -> void:
    if is_node_ready():
        push_error('Resource cannot be set after the editor is added to the scene!')
        return
    _set_resource(resource)

func get_resource() -> BehaviorExtendedResource:
    return _get_resource()

func on_change() -> void:
    if not is_saved:
        return

    is_saved = false
    changed.emit()

func on_save() -> void:
    if is_saved:
        return

    is_saved = true
    saved.emit()
