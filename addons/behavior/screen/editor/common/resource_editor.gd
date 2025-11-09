@abstract
@tool
class_name BehaviorResourceEditor extends BehaviorBaseEditor


## Maps class names to editor scenes
static var RESOURCE_EDITORS: Dictionary[StringName, PackedScene] = {
        &'BehaviorMindSettings': load("uid://dfu7q11sy44hk"),
        &'BehaviorSenseVisionSettings': load("uid://dh5k5n1pp0xmg"),
        &'BehaviorSenseHearingSettings': load("uid://b7bxudl0ogo2i"),
}


## Emitted when this editor is marked as saved
signal saved()


var is_saved: bool = true


func _ready() -> void:
    super._ready()
    if _is_ghost:
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


## Get the property names of sub resources
func get_sub_resource_names() -> PackedStringArray:
    return PackedStringArray()

## Accepts the sub resource editors for display, will be in the same order as
## requested by get_sub_resource_names()
func accept_editors(editors: Array[BehaviorResourceEditor]) -> void:
    pass

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


static func get_editor_for_resource(
        resource: BehaviorExtendedResource
) -> BehaviorResourceEditor:
    var packed: PackedScene = RESOURCE_EDITORS.get(resource.get_script().get_global_name())
    if not packed:
        return null

    return packed.instantiate() as BehaviorResourceEditor


static func get_property_editors(
        resource: BehaviorExtendedResource,
        properties: PackedStringArray,
        on_change_func: Callable,
) -> Array[BehaviorPropertyEditor]:
    var editors: Array[BehaviorPropertyEditor] = []
    for prop in resource.get_property_list():
        if not properties.has(prop.name):
            continue
        var editor: BehaviorPropertyEditor = BehaviorPropertyEditor.get_editor_for_property(resource, prop)
        editor.changed.connect(on_change_func)
        editors.append(editor)
    return editors

static func make_property_override_container(
        editor: BehaviorPropertyEditor
) -> ExpandableContainer:
    var container: ExpandableContainer = ExpandableContainer.new()
    container.set_expandable_separation(0)
    container.icon_visible = false
    container.allow_interaction = false
    container.theme_type_variation = &'ExpandableTransparent'
    container.title_theme_variation = &'ExpandableNoBorder'

    var title_bar: Control
    if editor.resource.base:
        title_bar = VBoxContainer.new()

        var property_header: HBoxContainer = HBoxContainer.new()

        var property_name: Label = Label.new()
        property_name.theme_type_variation = &'LabelMono'
        property_name.text = editor.property.name.capitalize()

        var override_button: CheckButton = CheckButton.new()
        override_button.text = 'Override'
        # TODO: button things

        property_header.add_child(property_name)
        property_header.add_child(override_button)

        var base_default: HBoxContainer = HBoxContainer.new()
        var base_default_label: Label = Label.new()
        base_default_label.text = 'Base Value:'
        base_default_label.theme_type_variation = &'TransparentLabel'

        var base_default_value: Label = Label.new()
        base_default_value.text = str()
        base_default_value.theme_type_variation = &'LabelMono'

        base_default.add_child(base_default_label)

        title_bar.add_child(property_header)
        title_bar.add_child(base_default)
    else:
        title_bar = MarginContainer.new()
        title_bar.add_theme_constant_override(&'margin_top', 4)
        title_bar.add_theme_constant_override(&'margin_bottom', 4)
        title_bar.add_theme_constant_override(&'margin_left', 8)
        title_bar.add_theme_constant_override(&'margin_right', 8)

        var property_name: Label = Label.new()
        property_name.theme_type_variation = &'LabelMono'
        property_name.text = editor.property.name.capitalize()

        title_bar.add_child(property_name)

    title_bar.tooltip_text = ' %s ' % editor.property.name
    title_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    var margins: MarginContainer = MarginContainer.new()
    margins.add_theme_constant_override(&'margin_top', 8)
    margins.add_theme_constant_override(&'margin_bottom', 8)
    margins.add_theme_constant_override(&'margin_left', 8)
    margins.add_theme_constant_override(&'margin_right', 8)

    margins.add_child(editor)

    container.set_title_control(title_bar)
    container.set_expandable_control(margins)

    return container

static func make_sub_resource_override_container(
    resource: BehaviorExtendedResource,
    property_name: StringName,
) -> ExpandableContainer:
    const btn_width = 80
    const min_height = 40

    var sub_resource: BehaviorExtendedResource = resource.get(property_name)

    var container: ExpandableContainer = ExpandableContainer.new()
    container.set_expandable_separation(0)

    var title_bar: Control

    var label: LineEdit = LineEdit.new()
    label.theme_type_variation = &'LabelMono'
    label.editable = false
    label.expand_to_text_length = true
    label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN | Control.SIZE_EXPAND
    label.size_flags_vertical = Control.SIZE_SHRINK_CENTER

    if sub_resource.resource_scene_unique_id.is_empty():
        label.text = sub_resource.resource_path.get_file()
        label.placeholder_text = 'Unknown Resource'
    else:
        label.placeholder_text = 'Sub Resource'

    var btn_extend: Button = Button.new()

    title_bar = HBoxContainer.new()
    title_bar.alignment = BoxContainer.ALIGNMENT_BEGIN
    title_bar.add_theme_constant_override('separation', 8)
    title_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_bar.tooltip_text = property_name

    var title: Label = Label.new()
    title.text = property_name.capitalize()
    title.custom_minimum_size.y = min_height
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

    var override_button: CheckButton
    if resource.base:
        override_button = CheckButton.new()
        # TODO: button things

    var button_bar: HBoxContainer = HBoxContainer.new()
    button_bar.alignment = BoxContainer.ALIGNMENT_END
    button_bar.add_theme_constant_override('separation', 8)
    button_bar.size_flags_horizontal = Control.SIZE_SHRINK_END
    button_bar.mouse_filter = Control.MOUSE_FILTER_STOP

    # New button
    var btn_new: Button = Button.new()
    btn_new.text = 'New'
    btn_new.custom_minimum_size.x = btn_width
    btn_new.size_flags_vertical = Control.SIZE_SHRINK_CENTER

    # Extend / Save As button
    btn_extend.custom_minimum_size.x = btn_width
    btn_extend.size_flags_vertical = Control.SIZE_SHRINK_CENTER

    # Load button
    var btn_load: Button = Button.new()
    btn_load.text = 'Load'
    btn_load.custom_minimum_size.x = btn_width
    btn_load.size_flags_vertical = Control.SIZE_SHRINK_CENTER

    # Final layout
    button_bar.add_spacer(true)
    button_bar.add_child(btn_extend)
    button_bar.add_child(btn_load)
    button_bar.add_child(btn_new)
    button_bar.add_spacer(false)

    if override_button:
        title_bar.add_child(override_button)

    title_bar.add_child(title)
    title_bar.add_child(label)
    title_bar.add_child(button_bar)

    container.set_title_control(title_bar)

    return container
