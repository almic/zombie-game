class_name HudDebugBarItem extends Control

var label_name: Label
var label_val: Label

func _ready() -> void:
    label_name = get_node('margin/text/name')
    label_val = get_node('margin/text/value')

func set_int_value(value: int) -> void:
    label_val.text = "%3d" % value
