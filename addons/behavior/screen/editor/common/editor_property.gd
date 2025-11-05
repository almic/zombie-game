@tool
class_name BehaviorPropertyEditor extends Control


# TODO: put editor scenes here
const NUMBER_EDITOR = preload("uid://xafwseh7radi")


var resource: BehaviorExtendedResource
var property: Dictionary
var on_changed_func: Callable


## Create property editors for basic resource exports. Does not modify the
## original resource. Value updates are passed to the provided callable.
static func get_editor_for_property(
        resource: BehaviorExtendedResource,
        property: Dictionary,
        on_changed_func: Callable = Callable()
) -> BehaviorPropertyEditor:
    if property.is_empty():
        push_error('Cannot create editor for "%s" because its info was empty!' % resource.resource_path)
        return null

    var type: int = property.type
    var hint: PropertyHint = property.hint
    var hint_string: String = property.hint_string

    var editor: BehaviorPropertyEditor
    if type == TYPE_INT or type == TYPE_FLOAT:
        editor = NUMBER_EDITOR.instantiate()


    editor.set_resource_property(resource, property)
    if on_changed_func.is_null():
        editor.on_changed_func = editor.default_on_changed
    else:
        editor.on_changed_func = on_changed_func
    return editor


func set_resource_property(res: BehaviorExtendedResource, info: Dictionary) -> void:
    resource = res
    property = info

func default_on_changed(value: Variant) -> void:
    resource.set(property.name, value)
