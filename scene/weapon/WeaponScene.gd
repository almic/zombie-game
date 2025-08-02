@icon("res://icon/weapon.svg")

class_name WeaponScene extends Node3D

@warning_ignore('unused_signal')
signal swap_hand(time: float)


## Weapon is ready to be used
func on_ready() -> void:
    pass

## Weapon has been triggered
func on_fire() -> void:
    pass

## Weapon is reloading
func on_reload() -> void:
    pass

## Controller is walking with the weapon
@warning_ignore('unused_parameter')
func on_walking(is_walking: bool = true) -> void:
    pass
