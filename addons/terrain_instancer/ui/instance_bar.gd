extends HBoxContainer

const Plugin = preload("uid://khsyydwj7rw2")

var plugin: Plugin

var region: TerrainInstanceRegion:
    set = set_region


func _init() -> void:
    pass


func _ready() -> void:
    var label: Label = Label.new()
    label.text = 'Add instance bar'
    add_child(label)


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
