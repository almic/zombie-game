extends HBoxContainer


signal tool_selected(tool: Tool)


enum Tool {
    NONE,
    SELECT,
    ADD_TRIANGLE,
    REMOVE_VERTEX,
    REMOVE_TRIANGLE,
}

const Plugin = preload("uid://khsyydwj7rw2")


var plugin: Plugin

var btn_add_region: Button

var group_region: ButtonGroup = ButtonGroup.new()
var sep_region: VSeparator
var btn_select: Button
var btn_add_triangle: Button
var sep_region_remove: VSeparator
var btn_remove_vertex: Button
var btn_remove_triangle: Button


func _init() -> void:
    group_region.allow_unpress = true
    custom_minimum_size = Vector2(20, 0)

func _ready() -> void:
    btn_add_region = Button.new()
    btn_add_region.text = "Add Region"
    btn_add_region.name = &'Add Region'
    btn_add_region.tooltip_text = "Add a new region"
    btn_add_region.theme_type_variation = &'FlatButton'
    btn_add_region.icon = get_theme_icon(&'Add', &'EditorIcons')
    btn_add_region.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    btn_add_region.pressed.connect(on_add_region)

    sep_region = VSeparator.new()

    btn_select = Button.new()
    btn_select.name = &'Select'
    btn_select.tooltip_text = "Select Vertex"
    btn_select.icon = get_theme_icon(&'EditPivot', &'EditorIcons')
    _init_tool_button(btn_select, group_region)

    btn_add_triangle = Button.new()
    btn_add_triangle.name = &'Add Triangles'
    btn_add_triangle.tooltip_text = "Add Triangles. Add new vertices or select existing ones to use them for a new face."
    btn_add_triangle.icon = get_theme_icon(&'ToolTriangle', &'EditorIcons')
    _init_tool_button(btn_add_triangle, group_region)

    sep_region_remove = VSeparator.new()

    btn_remove_vertex = Button.new()
    btn_remove_vertex.name = &'Remove Vertex'
    btn_remove_vertex.tooltip_text = "Remove Vertex. Will also delete any faces connected to the vertex."
    btn_remove_vertex.icon = get_theme_icon(&'Marker3D', &'EditorIcons')
    _init_tool_button(btn_remove_vertex, group_region)

    btn_remove_triangle = Button.new()
    btn_remove_triangle.name = &'Remove Triangles'
    btn_remove_triangle.tooltip_text = "Remove Triangles. Keeps vertices."
    btn_remove_triangle.icon = get_theme_icon(&'MeshInstance3D', &'EditorIcons')
    _init_tool_button(btn_remove_triangle, group_region)

    add_child(btn_add_region)
    add_child(sep_region)
    add_child(btn_select)
    add_child(btn_add_triangle)
    add_child(sep_region_remove)
    add_child(btn_remove_vertex)
    add_child(btn_remove_triangle)

func _init_tool_button(button: Button, group: ButtonGroup) -> void:
    button.toggle_mode = true
    button.theme_type_variation = &'FlatButton'
    button.button_group = group
    button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    button.pressed.connect(on_selection_changed)

func update_visibility() -> void:
    if not plugin:
        visible = false

    var show_sep: bool = false

    if plugin.edited_node:
        btn_add_region.show()
        show_sep = true
    else:
        btn_add_region.hide()

    if plugin.edited_region:
        if show_sep:
            sep_region.show()
        btn_select.show()
        btn_add_triangle.show()
        sep_region_remove.show()
        btn_remove_vertex.show()
        btn_remove_triangle.show()
    else:
        sep_region.hide()
        btn_select.hide()
        btn_add_triangle.hide()
        sep_region_remove.hide()
        btn_remove_vertex.hide()
        btn_remove_triangle.hide()

func create_region_node() -> TerrainInstanceRegion:
    var region := TerrainInstanceRegion.new()

    region.name = &'TerrainInstanceRegion'
    region.set_meta(
            &'_custom_type_script',
            ResourceUID.id_to_text(ResourceLoader.get_resource_uid(region.get_script().get_path()))
    )
    region.set_meta(&'_edit_lock_', true)

    return region

func on_add_region() -> void:
    if not plugin:
        return

    # Add a sibling to the currently selected region
    if plugin.edited_region:
        var new_region := create_region_node()
        plugin.edited_region.add_sibling(new_region, true)
        new_region.owner = plugin.edited_region.owner
        return

    # Add a child of the edited node
    if plugin.edited_node:
        var new_region := create_region_node()
        plugin.edited_node.add_child(new_region, true)
        new_region.owner = plugin.edited_node.owner
        return

    EditorInterface.get_editor_toaster().push_toast(
            "Unable to add region, no selected region or node instance to put with",
            EditorToaster.SEVERITY_ERROR
    )

func on_selection_changed() -> void:
    var selected: BaseButton = group_region.get_pressed_button()
    if not selected:
        tool_selected.emit(Tool.NONE)
        return

    if selected.name == &'Select':
        tool_selected.emit(Tool.SELECT)
    elif selected.name == &'Add Triangles':
        tool_selected.emit(Tool.ADD_TRIANGLE)
    elif selected.name == &'Remove Vertex':
        tool_selected.emit(Tool.REMOVE_VERTEX)
    elif selected.name == &'Remove Triangles':
        tool_selected.emit(Tool.REMOVE_TRIANGLE)
    else:
        push_error('TerrainInstancerPlugin: unknown tool selected! "%s"' % selected.name)
