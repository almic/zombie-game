@tool
class_name BehaviorPropertyEditorContainer extends ExpandableContainer


var editor: BehaviorPropertyEditor
var main_resource: BehaviorExtendedResource
var property_name: StringName


var label_property: Label
var label_default: Label
var label_default_value: Label
var vbox_title: VBoxContainer
var hbox_property: HBoxContainer
var hbox_default: HBoxContainer
var btn_override: CheckButton

var margins_editor: MarginContainer = MarginContainer.new()


func _ready() -> void:
    super._ready()

    margins_editor.add_theme_constant_override(&'margin_top', 8)
    margins_editor.add_theme_constant_override(&'margin_bottom', 8)
    margins_editor.add_theme_constant_override(&'margin_left', 8)
    margins_editor.add_theme_constant_override(&'margin_right', 8)
    set_expandable_control(margins_editor)

    btn_override = CheckButton.new()
    btn_override.toggled.connect(on_override_toggle)

    label_property = Label.new()
    label_property.theme_type_variation = &'LabelMono'

    hbox_property = HBoxContainer.new()
    hbox_property.add_theme_constant_override(&'separation', 8)
    hbox_property.add_child(btn_override)
    hbox_property.add_child(label_property)

    label_default = Label.new()
    label_default.text = 'Base Value:'
    label_default.theme_type_variation = &'TransparentLabel'

    label_default_value = Label.new()
    label_default_value.theme_type_variation = &'LabelMono'

    hbox_default = HBoxContainer.new()
    hbox_default.add_child(label_default)
    hbox_default.add_child(label_default_value)

    vbox_title = VBoxContainer.new()
    vbox_title.add_child(hbox_property)
    vbox_title.add_child(hbox_default)

    # NOTE: this set will child it to the title_bar
    title = MarginContainer.new()
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.add_theme_constant_override(&'margin_top', 4)
    title.add_theme_constant_override(&'margin_bottom', 4)
    title.add_theme_constant_override(&'margin_left', 8)
    title.add_theme_constant_override(&'margin_right', 8)

    title.add_child(vbox_title)

    update_title_bar()


func set_resource_and_property(resource: BehaviorExtendedResource, property: StringName) -> void:
    if (
                main_resource
            and main_resource.base
            and main_resource.base.property_changed.is_connected(on_base_property_changed)
    ):
        main_resource.base.property_changed.disconnect(on_base_property_changed)

    main_resource = resource
    property_name = property

    if (
                main_resource
            and main_resource.base
            and (not main_resource.base.property_changed.is_connected(on_base_property_changed))
    ):
        main_resource.base.property_changed.connect(on_base_property_changed)

    update_title_bar()

func set_editor(e: BehaviorPropertyEditor) -> void:
    if editor and editor.get_parent() == margins_editor:
        margins_editor.remove_child(editor)

    editor = e

    if not editor:
        return

    if editor.get_parent():
        editor.reparent(margins_editor, false)
    else:
        margins_editor.add_child(editor)

    editor._is_override = main_resource.base_overrides.has(property_name)

func update_title_bar() -> void:
    if not is_node_ready():
        return

    title.tooltip_text = ' ' + property_name + ' '
    label_property.text = property_name.capitalize()

    if main_resource and main_resource.base:
        var is_override: bool = main_resource.base_overrides.has(property_name)

        btn_override.visible = true
        btn_override.set_pressed_no_signal(is_override)

        if is_override:
            is_expanded = true

        hbox_default.visible = true
        label_default_value.text = str(main_resource.base.get(property_name))
    else:
        is_expanded = true
        btn_override.visible = false
        hbox_default.visible = false

func on_override_toggle(enabled: bool) -> void:
    if editor:
        editor.set_override(enabled)

    if not is_expanded:
        is_expanded = true

func on_base_property_changed(property: StringName, value: Variant) -> void:
    if property != property_name:
        return

    label_default_value.text = str(value)
