extends HBoxContainer


signal tool_selected(tool: Tool)


enum Tool {
    NONE,
    SELECT,
    ADD_TRIANGLE,
}

var button_group: ButtonGroup = ButtonGroup.new()

func _init() -> void:
    button_group.allow_unpress = true
    custom_minimum_size = Vector2(20, 0)


func _ready() -> void:
    var btn_select: Button = Button.new()
    btn_select.name = &'Select'
    btn_select.tooltip_text = "Select Vertex"
    btn_select.icon = get_theme_icon(&'EditPivot', &'EditorIcons')
    _init_button(btn_select)

    var btn_add_triangle: Button = Button.new()
    btn_add_triangle.name = &'Add Triangles'
    btn_add_triangle.tooltip_text = "Add Triangles. Add new vertices or select existing ones to use them for a new face."
    btn_add_triangle.icon = get_theme_icon(&'ToolTriangle', &'EditorIcons')
    _init_button(btn_add_triangle)

    add_child(btn_select)
    add_child(btn_add_triangle)

func _init_button(button: Button) -> void:
    button.toggle_mode = true
    button.theme_type_variation = &'FlatButton'
    button.button_group = button_group
    button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    button.pressed.connect(on_selection_changed)

func on_selection_changed() -> void:
    var selected: BaseButton = button_group.get_pressed_button()
    if not selected:
        tool_selected.emit(Tool.NONE)
        return

    if selected.name == &'Select':
        tool_selected.emit(Tool.SELECT)
    elif selected.name == &'Add Triangles':
        tool_selected.emit(Tool.ADD_TRIANGLE)
    else:
        push_error('TerrainInstancerPlugin: unknown tool selected! "%s"' % selected.name)
