@tool
class_name BehaviorPropertyEditorArray extends BehaviorPropertyEditor


var type: Variant.Type

var line_edit_variation: StringName = &'':
    set = set_line_edit_variation

var spinbox_variation: StringName = &'':
    set = set_spinbox_variation


func _ready() -> void:
    super._ready()
    if _is_ghost:
        return

    %ButtonAddElement.icon = get_theme_icon(&'Add', &'EditorIcons')
    %ButtonAddElement.pressed.connect(_add_element)

    var array: Array = resource.get(property.name)
    type = array.get_typed_builtin()
    for elem in array:
        _add_element(elem)


func set_line_edit_variation(variation: StringName) -> void:
    line_edit_variation = variation
    for line_edit in find_children('', 'LineEdit'):
        if line_edit is LineEdit:
            line_edit.theme_type_variation = line_edit_variation

func set_spinbox_variation(variation: StringName) -> void:
    spinbox_variation = variation
    for spinbox in find_children('', 'SpinBox'):
        if spinbox is SpinBox:
            spinbox.theme_type_variation = spinbox_variation

func _add_element(initial: Variant = null) -> void:
    var elem: HBoxContainer = HBoxContainer.new()
    var index: int = %Elements.get_child_count()

    var control: Control
    if type == TYPE_STRING or type == TYPE_STRING_NAME:
        var line_edit: LineEdit = LineEdit.new()
        line_edit.theme_type_variation = line_edit_variation
        if initial != null:
            line_edit.text = initial
        else:
            if type == TYPE_STRING:
                initial = ''
            elif type == TYPE_STRING_NAME:
                initial = &''
            _on_element_modified(initial, index, line_edit)

        if type == TYPE_STRING_NAME:
            line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL

            var hbox: HBoxContainer = HBoxContainer.new()
            hbox.add_theme_constant_override(&'separation', 0)

            var prefix: Label = Label.new()
            prefix.text = '&'
            prefix.tooltip_text = 'StringName'
            prefix.theme_type_variation = &'DarkLabel'
            prefix.mouse_filter = Control.MOUSE_FILTER_STOP

            hbox.add_child(prefix)
            hbox.add_child(line_edit)

            control = hbox
        else:
            control = line_edit

        line_edit.text_changed.connect(_on_control_modified.bind(control, line_edit))
    elif type == TYPE_INT or type == TYPE_FLOAT:
        var spin_box: SpinBox = SpinBox.new()
        spin_box.theme_type_variation = spinbox_variation
        spin_box.get_line_edit().theme_type_variation = line_edit_variation

        if type == TYPE_INT:
            spin_box.rounded = true

        if initial != null:
            spin_box.set_value_no_signal(initial)
        else:
            if type == TYPE_INT:
                initial = int(0)
            elif type == TYPE_FLOAT:
                initial = float(0)
            _on_element_modified(initial, index, spin_box)
        control = spin_box
        spin_box.value_changed.connect(_on_control_modified.bind(control, spin_box))
    else:
        push_error('Unsupported element type (%d)!' % type)
        return

    control.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    var btn_delete: Button = Button.new()
    btn_delete.icon = get_theme_icon(&'Remove', &'EditorIcons')
    var btn_style: StyleBox = btn_delete.get_theme_stylebox(&'normal')
    var btn_size: Vector2 = btn_delete.icon.get_size()
    var min_size: int = max(
            btn_size.y + btn_style.content_margin_top + btn_style.content_margin_bottom,
            btn_size.x + btn_style.content_margin_left + btn_style.content_margin_right
    )
    btn_delete.custom_minimum_size = Vector2(min_size, min_size)
    btn_delete.pressed.connect(_on_element_delete.bind(elem))

    elem.add_child(control)
    elem.add_child(btn_delete)

    %Elements.add_child(elem)
    %LabelSize.text = str(%Elements.get_child_count())

func _on_element_modified(value: Variant, index: int, control: Control) -> void:
    var old_size: int = resource.get(property.name).size()
    if on_changed_func.is_valid():
        on_changed_func.call(value, index)
    changed.emit()

    # NOTE: it is important that change functions do not resize the array, and it
    #       should only modify the provided index
    var array: Array = resource.get(property.name)
    if index != old_size and old_size != array.size():
        push_error('Array on_changed_func must not resize the array, except to add a new element when index == size!')
        return

    var new_value: Variant = array[index]
    if new_value == value:
        return

    if control is LineEdit:
        control.text = new_value
    elif control is SpinBox:
        control.set_value_no_signal(new_value)

func _on_control_modified(value: Variant, base: Control, editor: Control) -> void:
    _on_element_modified(value, base.get_parent().get_index(), editor)

func _on_element_delete(element: Control) -> void:
    var index: int = element.get_index()
    if Input.is_physical_key_pressed(KEY_SHIFT):
        _remove_element(index, element)
        return

    var confirm: ConfirmationDialog = ConfirmationDialog.new()
    confirm.theme = self.theme
    confirm.title = 'Confirm delete element'
    confirm.cancel_button_text = 'Keep'
    confirm.ok_button_text = 'Remove'
    confirm.confirmed.connect(_remove_element.bind(index, element))

    var inner: VBoxContainer = VBoxContainer.new()
    var label: Label = Label.new()
    label.text = 'Delete element at index %d with the following value' % index

    var label_value: Label = Label.new()
    label_value.theme_type_variation = &'LabelMono'
    label_value.add_theme_font_size_override(&'font_size', 20)
    label_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label_value.text = str(resource.get(property.name)[index])
    if type == TYPE_STRING:
        label_value.text = '"%s"' % label_value.text
    elif type == TYPE_STRING_NAME:
        label_value.text = '&"%s"' % label_value.text

    inner.add_child(label)
    inner.add_child(label_value)
    confirm.add_child(inner)

    EditorInterface.popup_dialog_centered(confirm)

func _remove_element(index: int, element: Control) -> void:
    var expected_size: int = resource.get(property.name).size() - 1
    # NOTE: it is important that change function causes the array to resize down 1
    if on_changed_func.is_valid():
        on_changed_func.call(null, index)
    changed.emit()

    if expected_size != resource.get(property.name).size():
        push_error('Array on_changed_func failed to reduce the array size from %d to %d!' % [expected_size + 1, expected_size])
        return

    %Elements.remove_child(element)
    element.queue_free()
    %LabelSize.text = str(%Elements.get_child_count())
