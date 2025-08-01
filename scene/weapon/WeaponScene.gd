@icon("res://icon/weapon.svg")

class_name WeaponScene extends Node3D

@warning_ignore('unused_signal')
signal swap_hand(time: float)

func on_fire() -> void:
    pass

func on_reload() -> void:
    pass

@warning_ignore('unused_parameter')
func on_walking(is_walking: bool = true) -> void:
    pass
