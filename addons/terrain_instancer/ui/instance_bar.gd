extends HSplitContainer


const Plugin = preload("uid://khsyydwj7rw2")
const TerrainInstanceTemporary = preload("uid://dumv2y8oq3f1x")


var plugin: Plugin

var region: TerrainInstanceRegion:
    set = set_region


var _preview_update_frames: int = 0
var _preview_last_mouse_pos: Vector3

var left_scroll: ScrollContainer
var instance_btn_group: ButtonGroup
var instance_container: HFlowContainer
var no_selection_text: Label

var right_scroll: ScrollContainer
var setting_rand_container: HBoxContainer
var setting_btn_group: ButtonGroup
var setting_btn_container: HFlowContainer
var editor: EditorInspector

var instance_settings_map: Dictionary
var instance_settings: TerrainInstanceSettings
var rng: RandomNumberGenerator


func _init() -> void:
    instance_btn_group = ButtonGroup.new()
    instance_btn_group.pressed.connect(update_settings)

    setting_btn_group = ButtonGroup.new()

    var split_bg: StyleBoxFlat = StyleBoxFlat.new()
    split_bg.bg_color = Color(0.0, 0.0, 0.0, 0.2)
    split_bg.expand_margin_top = 4

    add_theme_stylebox_override(&'split_bar_background', split_bg)

    rng = RandomNumberGenerator.new()
    rng.randomize()

func _ready() -> void:
    left_scroll = ScrollContainer.new()
    left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    left_scroll.custom_minimum_size = Vector2(0, 176)
    left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    left_scroll.size_flags_stretch_ratio = 2

    no_selection_text = Label.new()
    no_selection_text.text = 'No region selected.'
    no_selection_text.visible = false
    left_scroll.add_child(no_selection_text)

    instance_container = HFlowContainer.new()
    instance_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    instance_container.add_theme_constant_override(&'h_separation', 1)
    instance_container.add_theme_constant_override(&'v_separation', 3)
    left_scroll.add_child(instance_container)

    var margin_left: MarginContainer = MarginContainer.new()
    margin_left.add_theme_constant_override(&'margin_top', 2)
    margin_left.add_theme_constant_override(&'margin_left', 4)
    margin_left.add_theme_constant_override(&'margin_bottom', 2)
    margin_left.add_theme_constant_override(&'margin_right', 4)
    margin_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    margin_left.size_flags_stretch_ratio = 5

    margin_left.add_child(left_scroll)

    add_child(margin_left)

    right_scroll = ScrollContainer.new()
    right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    right_scroll.size_flags_stretch_ratio = 7
    right_scroll.visible = false

    setting_rand_container = HBoxContainer.new()
    setting_rand_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    var btn_rand_all: Button = Button.new()
    btn_rand_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    var btn_rand_color: Button = btn_rand_all.duplicate()
    var btn_rand_height: Button = btn_rand_all.duplicate()
    var btn_rand_spin: Button = btn_rand_all.duplicate()
    var btn_rand_tilt: Button = btn_rand_all.duplicate()
    var btn_rand_scale: Button = btn_rand_all.duplicate()

    btn_rand_color.text = 'Color'
    btn_rand_color.tooltip_text = 'Randomize color of the instance to add'
    btn_rand_color.icon = get_theme_icon(&'VisualShaderNodeColorConstant', &'EditorIcons')
    btn_rand_color.pressed.connect(randomize_instance.bind(&'color'))
    setting_rand_container.add_child(btn_rand_color)

    btn_rand_height.text = 'Height'
    btn_rand_height.tooltip_text = 'Randomize height of the instance to add'
    btn_rand_height.icon = get_theme_icon(&'ExpandTree', &'EditorIcons')
    btn_rand_height.pressed.connect(randomize_instance.bind(&'height'))
    setting_rand_container.add_child(btn_rand_height)

    btn_rand_spin.text = 'Spin'
    btn_rand_spin.tooltip_text = 'Randomize spin of the instance to add'
    btn_rand_spin.icon = get_theme_icon(&'ToolRotate', &'EditorIcons')
    btn_rand_spin.pressed.connect(randomize_instance.bind(&'spin'))
    setting_rand_container.add_child(btn_rand_spin)

    btn_rand_tilt.text = 'Tilt'
    btn_rand_tilt.tooltip_text = 'Randomize tilt of the instance to add'
    btn_rand_tilt.icon = get_theme_icon(&'FadeIn', &'EditorIcons')
    btn_rand_tilt.pressed.connect(randomize_instance.bind(&'tilt'))
    setting_rand_container.add_child(btn_rand_tilt)

    btn_rand_scale.text = 'Scale'
    btn_rand_scale.tooltip_text = 'Randomize scale of the instance to add'
    btn_rand_scale.icon = get_theme_icon(&'DistractionFree', &'EditorIcons')
    btn_rand_scale.pressed.connect(randomize_instance.bind(&'scale'))
    setting_rand_container.add_child(btn_rand_scale)

    btn_rand_all.text = 'Randomize All'
    btn_rand_all.tooltip_text = 'Randomize all variable properties of the instance to add'
    btn_rand_all.icon = get_theme_icon(&'AudioStreamRandomizer', &'EditorIcons')
    btn_rand_all.pressed.connect(randomize_instance)
    btn_rand_all.size_flags_stretch_ratio = 1.8
    setting_rand_container.add_child(btn_rand_all)

    editor = EditorInspector.new()
    editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    editor.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    editor.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    editor.set_use_doc_hints(true)
    editor.set_use_folding(true)
    editor.visible = false

    var right_panel: VBoxContainer = VBoxContainer.new()
    right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    setting_btn_container = instance_container.duplicate()
    right_panel.add_child(setting_btn_container)
    right_panel.add_child(editor)

    right_scroll.add_child(right_panel)

    var right_split: VBoxContainer = VBoxContainer.new()
    right_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right_split.add_child(setting_rand_container)
    right_split.add_child(right_scroll)

    var margin_right: MarginContainer = margin_left.duplicate()
    margin_right.size_flags_stretch_ratio = 14

    margin_right.add_child(right_split)

    add_child(margin_right)

func _physics_process(_delta: float) -> void:
    if (not visible) or (not Engine.is_editor_hint()):
        return

    # Help the instance preview align to terrain after mouse stops moving
    if _preview_update_frames == 0 and _preview_last_mouse_pos != plugin.mouse_position:
        _preview_last_mouse_pos = plugin.mouse_position
        _preview_update_frames = 5
        return

    if _preview_update_frames > 0:
        _preview_update_frames -= 1
        if plugin.instance_preview and plugin.instance_preview.visible:
            plugin.update_mouse_position()
            if plugin.mouse_position.is_finite():
                plugin.instance_preview.instance_position = plugin.mouse_position
            else:
                _preview_update_frames = 0

func set_region(new_region: TerrainInstanceRegion) -> void:
    if new_region == region:
        return

    editor.visible = false

    if new_region == null:
        region = null

        instance_container.visible = false
        no_selection_text.visible = true

        right_scroll.visible = false

        return

    if region == null:
        instance_container.visible = true
        no_selection_text.visible = false

        right_scroll.visible = true

    region = new_region
    update_instance_grid()

func update_instance_grid() -> void:
    for child in instance_container.get_children():
        instance_container.remove_child(child)
        child.queue_free()

    if not region.settings:
        return

    var ids: PackedInt32Array
    for setting in region.settings.instances:
        if ids.has(setting.id):
            continue
        ids.append(setting.id)

    var previewer: EditorResourcePreview = EditorInterface.get_resource_previewer()
    var is_first: bool = true
    for instance_id in ids:
        var container: MarginContainer = MarginContainer.new()
        container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

        var btn: Button = Button.new()
        btn.button_group = instance_btn_group
        btn.toggle_mode = true

        btn.theme_type_variation = &'FlatButton'
        btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        btn.custom_minimum_size = Vector2(90, 90)

        btn.expand_icon = true
        btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
        btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
        btn.add_theme_constant_override(&'icon_max_width', 80)

        btn.add_theme_constant_override(&'outline_size', 1)
        btn.add_theme_color_override(&'font_color', Color(1.0, 1.0, 1.0, 0.7))

        btn.name = str(instance_id)
        btn.text = region.instance_node.get_instance_name(instance_id)
        btn.tooltip_text = 'ID: %d' % instance_id

        container.add_child(btn)

        var instance_scene: PackedScene = region.instance_node.get_instance_scene(instance_id)
        previewer.queue_resource_preview(
                instance_scene.resource_path,
                self,
                &'set_instance_thumbnail',
                btn
        )

        instance_container.add_child(container)

        if is_first:
            is_first = false
            btn.set_pressed.call_deferred(true)

    # Add blank control to consume remainder of last line
    var spacer: Control = Control.new()
    spacer.custom_minimum_size = Vector2(0, 1)
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    spacer.size_flags_stretch_ratio = INF
    instance_container.add_child(spacer)

func set_instance_thumbnail(path: String, preview: Texture2D, thumbnail: Texture2D, user_data: Variant) -> void:
    var btn: Button = user_data as Button
    if not btn:
        return

    if not thumbnail:
        if not preview:
            return
        thumbnail = preview

    btn.icon = thumbnail

func update_settings(selected: BaseButton) -> void:
    for child in setting_btn_container.get_children():
        setting_btn_container.remove_child(child)
        child.queue_free()

    set_instance_setting(true, null)

    if not region or not region.settings:
        return

    var id: int = -1
    if selected:
        id = int(selected.name)
    plugin.instance_preview.instance_id = id

    var options: Array[TerrainInstanceSettings]
    for setting in region.settings.instances:
        if setting.id == id:
            options.append(setting)

    var option_id: int = 0
    var is_first: bool = true
    for option in options:
        option_id += 1

        var child_settings: TerrainInstanceSettings
        if instance_settings_map.has(option):
            child_settings = instance_settings_map.get(option)
            child_settings.resource_name = option.resource_name
        else:
            child_settings = option.duplicate(true)
            child_settings.resource_name = option.resource_name
            child_settings._parent = option
            instance_settings_map.set(option, child_settings)

        var btn: Button = Button.new()
        btn.button_group = setting_btn_group
        btn.toggle_mode = true

        btn.theme_type_variation = &'FlatButton'
        btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        btn.custom_minimum_size = Vector2(100, 70)

        btn.text = option.resource_name
        if not btn.text:
            btn.text = 'Option %d' % option_id
            btn.tooltip_text = 'Set a resource name to display here.'

        btn.toggled.connect(set_instance_setting.bind(child_settings))
        setting_btn_container.add_child(btn)

        # Only one choice, hide the button
        if options.size() == 1:
            btn.visible = false
            if is_first:
                is_first = true
                btn.set_pressed.call_deferred(true)

func set_instance_setting(toggled: bool, setting: TerrainInstanceSettings) -> void:
    if not toggled:
        return

    instance_settings = setting

    if instance_settings:
        editor.edit(setting)
        randomize_instance()
        editor.show()
    else:
        editor.hide()

func randomize_instance(prop: StringName = &'all') -> void:
    var do_all: bool = prop == &'all'

    if do_all or prop == &'color':
        plugin.instance_preview.instance_color = instance_settings.rand_color(rng)

    if do_all or prop == &'height':
        plugin.instance_preview.instance_height = instance_settings.rand_height(rng)

    if do_all or prop == &'spin':
        plugin.instance_preview.instance_spin = instance_settings.rand_spin(rng)

    if do_all or prop == &'tilt':
        plugin.instance_preview.rand_tilt_axis()
        plugin.instance_preview.instance_tilt = instance_settings.rand_tilt(rng)

    if do_all or prop == &'scale':
        plugin.instance_preview.instance_scale = instance_settings.rand_scale(rng)
