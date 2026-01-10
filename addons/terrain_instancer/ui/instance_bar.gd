extends HBoxContainer

const Plugin = preload("uid://khsyydwj7rw2")

var plugin: Plugin

var region: TerrainInstanceRegion:
    set = set_region

var _preview_update_frames: int = 0
var _preview_last_mouse_pos: Vector3


func _init() -> void:
    pass


func _ready() -> void:
    var label: Label = Label.new()
    label.text = 'Add instance bar'
    add_child(label)

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
