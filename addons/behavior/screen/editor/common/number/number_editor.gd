@tool
class_name BehaviorPropertyEditorNumber extends BehaviorPropertyEditor


var show_slider: bool = true:
    set = set_show_slider
var show_spinner: bool = true:
    set = set_show_spinner
var suffix: String = '':
    set = set_suffix


func _ready() -> void:
    super._ready()
    if _is_ghost:
        return

    # NOTE: Slider will be the main owner of range settings
    %Slider.share(%SpinBox)


func get_range() -> Range:
    return %Slider

func set_show_slider(value: bool) -> void:
    %Slider.visible = value

func set_show_spinner(value: bool) -> void:
    %SpinBox.visible = value

func set_suffix(suf: String) -> void:
    suffix = suf
    %SpinBox.suffix = suffix

func set_resource_property(res: BehaviorExtendedResource, info: Dictionary) -> void:
    super(res, info)
    var hint = info.hint
    var hint_string = info.hint_string

    if hint == PROPERTY_HINT_NONE:
        var range: Range = get_range()
        range.value_changed.connect(_value_changed)
        range.allow_greater = true
        range.allow_lesser = true
        range.set_value_no_signal(resource.get(property.name))
        show_slider = false
        return

    if (
               hint == PROPERTY_HINT_ENUM
            or hint == PROPERTY_HINT_EXP_EASING
            or hint == PROPERTY_HINT_FLAGS
            or hint == PROPERTY_HINT_LAYERS_2D_RENDER
            or hint == PROPERTY_HINT_LAYERS_2D_PHYSICS
            or hint == PROPERTY_HINT_LAYERS_2D_NAVIGATION
            or hint == PROPERTY_HINT_LAYERS_3D_RENDER
            or hint == PROPERTY_HINT_LAYERS_3D_PHYSICS
            or hint == PROPERTY_HINT_LAYERS_3D_NAVIGATION
            or hint == PROPERTY_HINT_LAYERS_AVOIDANCE
    ):
        show_slider = false
        show_spinner = false

        var editor: EditorProperty = EditorInspector.instantiate_property_editor(
                # NOTE: the passed object and name are actually 100% ignored
                #       because we MUST call 'set_object_and_property' later,
                #       otherwise it claims the object was Nil (stupid)
                null, info.type, '',
                info.hint, info.hint_string, PROPERTY_USAGE_NONE
        )
        editor.draw_label = false
        editor.set_object_and_property(resource, info.name)
        editor.update_property()
        editor.property_changed.connect(_on_editor_property_changed)
        add_child(editor)

    if hint == PROPERTY_HINT_RANGE:
        var range: Range = get_range()
        var args: PackedStringArray = hint_string.split(',')

        if args.size() < 3:
            push_error('Range hint expects at least "min,max,step"!')
            return

        range.value_changed.connect(_value_changed)
        range.min_value = float(args[0])
        range.max_value = float(args[1])
        range.step = float(args[2])
        range.set_value_no_signal(resource.get(property.name))

        for i in range(3, args.size()):
            var extra: String = args[i]
            if extra == 'or_greater':
                range.allow_greater = true
            elif extra == 'or_less':
                range.allow_lesser = true
            elif extra == 'hide_slider':
                show_slider = false
            elif extra == 'exp':
                range.exp_edit = true
            elif extra == 'radians_as_degrees':
                suffix = '°'
                if range.value_changed.is_connected(_value_changed):
                    range.value_changed.disconnect(_value_changed)
                if not range.value_changed.is_connected(_radians_as_degrees):
                    range.value_changed.connect(_radians_as_degrees)
            elif extra == 'degrees':
                suffix = '°'
            elif extra.begins_with('suffix:'):
                suffix = extra.get_slicec(ord(':'), 1)


func _value_changed(value: float) -> void:
    if on_changed_func.is_valid():
        on_changed_func.call(value)
    changed.emit()
    var new_value: float = resource.get(property.name)
    if new_value == value:
        return
    get_range().set_value_no_signal(new_value)


func _on_editor_property_changed(
        _prop_name: StringName,
        value: Variant,
        _field: StringName,
        _changing: bool
) -> void:
    _value_changed(float(value))

func _radians_as_degrees(value: float) -> void:
    value = deg_to_rad(value)
    resource.set(property.name, value)
    _value_changed(value)
