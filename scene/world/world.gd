class_name World extends Node3D

@export var first_person: GUIDEMappingContext

@export var pause : GUIDEAction
@onready var pause_menu: Control = %pause

func _ready() -> void:
    GUIDE.enable_mapping_context(first_person)
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

    # Engine.time_scale = 0.334

func _process(_delta: float) -> void:
    if pause.is_triggered():
        if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
            get_tree().paused = false
            pause_menu.visible = false
        else:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
            get_tree().paused = true
            pause_menu.visible = true
