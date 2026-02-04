extends HBoxContainer


signal tool_selected(tool: Tool)


enum Tool {
    NONE,
    ADD_INSTANCE,
    EDIT_INSTANCE,
    SELECT_VERTEX,
    ADD_VERTEX,
    REMOVE_VERTEX,
}

const Plugin = preload("uid://khsyydwj7rw2")


var plugin: Plugin

var btn_add_region: Button

var group_region: ButtonGroup = ButtonGroup.new()

var sep_region: VSeparator
var btn_select: Button
var btn_add_vertex: Button
var btn_remove_vertex: Button

var sep_instances: VSeparator
var btn_add_instance: Button
var btn_edit_instance: Button

var sep_region_populate: VSeparator
var btn_populate_region: Button
var btn_clear_region: Button


func _init() -> void:
    group_region.allow_unpress = true
    custom_minimum_size = Vector2(0, 20)

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
    btn_select.name = &'Select Vertex'
    btn_select.tooltip_text = "Select Vertex"
    btn_select.icon = get_theme_icon(&'EditPivot', &'EditorIcons')
    _init_tool_button(btn_select, group_region)

    btn_add_vertex = Button.new()
    btn_add_vertex.name = &'Add Vertex'
    btn_add_vertex.tooltip_text = "Add Vertex"
    btn_add_vertex.icon = get_theme_icon(&'ToolTriangle', &'EditorIcons')
    _init_tool_button(btn_add_vertex, group_region)

    btn_remove_vertex = Button.new()
    btn_remove_vertex.name = &'Remove Vertex'
    btn_remove_vertex.tooltip_text = "Remove Vertex. Will also delete any faces connected to the vertex."
    btn_remove_vertex.icon = get_theme_icon(&'Marker3D', &'EditorIcons')
    _init_tool_button(btn_remove_vertex, group_region)

    sep_instances = VSeparator.new()

    btn_add_instance = Button.new()
    btn_add_instance.name = &'Add Instance'
    btn_add_instance.tooltip_text = "Add instances. Creates a temporary node for editing. Merges with region on save."
    btn_add_instance.icon = get_theme_icon(&'ArrayMesh', &'EditorIcons')
    _init_tool_button(btn_add_instance, group_region)

    btn_edit_instance = Button.new()
    btn_edit_instance.name = &'Edit Instance'
    btn_edit_instance.tooltip_text = "Edit instances. Changes selected instance into temporary node for editing. Merges into region on save."
    btn_edit_instance.icon = get_theme_icon(&'DebugContinue', &'EditorIcons')
    _init_tool_button(btn_edit_instance, group_region)

    sep_region_populate = VSeparator.new()

    btn_populate_region = Button.new()
    btn_populate_region.text = "Populate"
    btn_populate_region.name = &'Populate'
    btn_populate_region.tooltip_text = "Populate the region"
    btn_populate_region.theme_type_variation = &'FlatButton'
    btn_populate_region.icon = get_theme_icon(&'InterpCubicAngle', &'EditorIcons')
    btn_populate_region.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    btn_populate_region.pressed.connect(on_populate_region)

    btn_clear_region = Button.new()
    btn_clear_region.text = "Clear"
    btn_clear_region.name = &'Clear'
    btn_clear_region.tooltip_text = "Remove managed instance types from the region"
    btn_clear_region.theme_type_variation = &'FlatButton'
    btn_clear_region.icon = get_theme_icon(&'InterpLinear', &'EditorIcons')
    btn_clear_region.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    btn_clear_region.pressed.connect(on_clear_region)


    add_child(btn_add_region)

    add_child(sep_region)
    add_child(btn_select)
    add_child(btn_add_vertex)
    add_child(btn_remove_vertex)

    add_child(sep_instances)
    add_child(btn_add_instance)
    add_child(btn_edit_instance)

    add_child(sep_region_populate)
    add_child(btn_populate_region)
    add_child(btn_clear_region)


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
        btn_add_vertex.show()
        btn_remove_vertex.show()

        sep_instances.show()
        btn_add_instance.show()
        btn_edit_instance.show()

        sep_region_populate.show()
        btn_populate_region.show()
        btn_clear_region.show()

    else:
        sep_region.hide()
        btn_select.hide()
        btn_add_vertex.hide()
        btn_remove_vertex.hide()

        sep_instances.hide()
        btn_add_instance.hide()
        btn_edit_instance.hide()

        sep_region_populate.hide()
        btn_populate_region.hide()
        btn_clear_region.hide()

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

func on_populate_region() -> void:
    if not plugin.edited_region:
        return

    plugin.edited_region.editor_populate_region()

    #for k in range(25):
        #plugin.edited_region.btn_randomize_seed.call()
        #plugin.edited_region.settings.instances[0].btn_randomize_seed.call()
        #plugin.edited_region.editor_populate_region()

func on_clear_region() -> void:
    if not plugin.edited_region:
        return

    plugin.edited_region.editor_clear_region()

func on_selection_changed() -> void:
    var selected: BaseButton = group_region.get_pressed_button()
    if not selected:
        tool_selected.emit(Tool.NONE)
        return

    if selected.name == &'Select Vertex':
        tool_selected.emit(Tool.SELECT_VERTEX)
    elif selected.name == &'Add Vertex':
        tool_selected.emit(Tool.ADD_VERTEX)
    elif selected.name == &'Remove Vertex':
        tool_selected.emit(Tool.REMOVE_VERTEX)
    elif selected.name == &'Add Instance':
        tool_selected.emit(Tool.ADD_INSTANCE)
    elif selected.name == &'Edit Instance':
        tool_selected.emit(Tool.EDIT_INSTANCE)
    else:
        push_error('TerrainInstancerPlugin: unknown tool selected! "%s"' % selected.name)
