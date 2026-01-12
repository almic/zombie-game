extends HSplitContainer


const Plugin = preload("uid://khsyydwj7rw2")


var plugin: Plugin

var region: TerrainInstanceRegion:
    set = set_region


var _preview_update_frames: int = 0
var _preview_last_mouse_pos: Vector3
var _instance_data: TerrainInstanceSettings


func _init() -> void:
    pass


func _ready() -> void:
    var left_scroll: ScrollContainer = ScrollContainer.new()
    left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    left_scroll.custom_minimum_size = Vector2(0, 80)
    left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    var right_scroll: ScrollContainer = ScrollContainer.new()
    right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    right_scroll.custom_minimum_size = Vector2(0, 80)
    right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    var instance_grid: GridContainer = GridContainer.new()
    instance_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    var test_parent_data: TerrainInstanceSettings = TerrainInstanceSettings.new()
    test_parent_data.v_height_offset = 12.23

    _instance_data = test_parent_data.duplicate(true)
    _instance_data._parent = test_parent_data

    var right_panel: VBoxContainer = VBoxContainer.new()
    right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    var editor: EditorInspector = EditorInspector.new()
    editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    editor.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    editor.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    editor.set_use_doc_hints(true)
    editor.set_use_folding(true)
    editor.edit.call_deferred(_instance_data)

    left_scroll.add_child(instance_grid)

    right_panel.add_child(editor)
    right_scroll.add_child(right_panel)

    add_child(left_scroll)
    add_child(right_scroll)


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
                plugin.instance_preview.global_position = plugin.mouse_position
            else:
                _preview_update_frames = 0

func set_region(new_region: TerrainInstanceRegion) -> void:
    if new_region == region:
        return

    if new_region == null:
        region = null
        # TODO ?
        print('cleared region!')
        return

    if region:
        # TODO ?
        print('changing old region %s' % region.name)
        pass

    region = new_region
    print('set new region %s' % region.name)
