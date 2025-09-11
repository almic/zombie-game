@tool
extends WeaponUI

@onready var cylinder: TextureRect = %cylinder
@onready var marker: TextureRect = %marker


@export var marker_color: Color = Color(1.0, 1.0, 1.0, 0.667)
@export var marker_color_cocked: Color = Color(1.0, 0.0, 0.0, 1.0)


func _process(delta: float) -> void:
    super._process(delta)

    var mat: ShaderMaterial = cylinder.material as ShaderMaterial
    if mat:
        mat.set_shader_parameter('rotation', cylinder.rotation)


func update(weapon: WeaponResource) -> void:
    super.update(weapon)

    var revolver: RevolverWeapon = weapon as RevolverWeapon
    if not revolver:
        return

    if revolver._hammer_cocked:
        marker.self_modulate = marker_color_cocked
    else:
        marker.self_modulate = marker_color

    cylinder.rotation = deg_to_rad(60.0 * revolver._cylinder_position)
