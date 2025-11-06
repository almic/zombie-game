@abstract
@tool
class_name BehaviorResourceEditor extends Control


## Emitted when a value is modified in this editor, or in a sub editor
signal changed()

## Emitted when this editor is marked as saved
signal saved()


var is_saved: bool = true


## Sets the resource for this editor
@abstract func _set_resource(resource: BehaviorExtendedResource) -> void

''

func set_resource(resource: BehaviorExtendedResource) -> void:
    if is_node_ready():
        push_error('Resource cannot be set after the editor is added to the scene!')
        return
    _set_resource(resource)

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
