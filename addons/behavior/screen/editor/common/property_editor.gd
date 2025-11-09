@tool
class_name BehaviorPropertyEditor extends BehaviorBaseEditor


static var NUMBER_EDITOR: PackedScene
static var ARRAY_EDITOR: PackedScene

static func _static_init() -> void:
    # TODO: put editor scenes here
    NUMBER_EDITOR = load("uid://xafwseh7radi")
    ARRAY_EDITOR = load("uid://do33q3toxspah")


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
        editor.set_line_edit_variation(&'LineEditMono')
    elif type == TYPE_ARRAY:
        editor = ARRAY_EDITOR.instantiate()
        editor.set_line_edit_variation(&'LineEditMono')
    else:
        push_error('No editor for type (%d)!' % type)
        return

    editor.set_resource_property(resource, property)
    if on_changed_func.is_null():
        if type == TYPE_ARRAY:
            editor.on_changed_func = editor.default_on_changed_array
        else:
            editor.on_changed_func = editor.default_on_changed
    else:
        editor.on_changed_func = on_changed_func
    return editor

func set_resource_property(res: BehaviorExtendedResource, info: Dictionary) -> void:
    resource = res
    property = info

func default_on_changed(value: Variant) -> void:
    resource.set(property.name, value)

func default_on_changed_array(value: Variant, index: int) -> void:
    var array: Array = resource.get(property.name)
    # Deleting element
    if value == null:
        if array.is_empty():
            push_error('Cannot remove the value at index %d, array is empty!' % index)
            return
        elif index < 0 or index >= array.size():
            push_error('Cannot remove the value at index %d, not in the range [0, %d]!' % [index, array.size() - 1])
            return

        array.remove_at(index)
    # Setting / Adding element
    else:
        if index < 0 or index > array.size():
            push_error('Cannot set the value at index %d, not in the range [0, %d]!' % [index, array.size()])
            return
        if index == array.size():
            array.append(value)
        else:
            array[index] = value
