extends HudDebugBarItem


func _process(_delta: float) -> void:
    set_int_value(int(Engine.get_frames_per_second()))
