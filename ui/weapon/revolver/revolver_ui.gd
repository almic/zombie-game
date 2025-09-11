@tool
extends WeaponUI

@onready var cylinder: TextureRect = %cylinder
@onready var marker: TextureRect = %marker

@onready var port_1: TextureRect = %port1
@onready var port_2: TextureRect = %port2
@onready var port_3: TextureRect = %port3
@onready var port_4: TextureRect = %port4
@onready var port_5: TextureRect = %port5
@onready var port_6: TextureRect = %port6


@export var marker_color: Color = Color(1.0, 1.0, 1.0, 0.667)
@export var marker_color_cocked: Color = Color(1.0, 0.0, 0.0, 1.0)


var ports: Array[TextureRect]

func _ready() -> void:
    ports = [port_1, port_2, port_3, port_4, port_5, port_6]

    for i in range(ports.size()):
        var port: TextureRect = ports[i]
        port.rotation = -i * (PI / 3.0)


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

    var supported: Dictionary = revolver.get_supported_ammunition()
    for i in range(revolver.ammo_reserve_size):
        var port: TextureRect = ports[i]
        var ammo: AmmoResource = supported.get(revolver._mixed_reserve[i]) as AmmoResource
        if ammo:
            port.texture = ammo.alt_ui_texture
            if revolver._cylinder_ammo_state[i]:
                port.self_modulate.a = 1.0
            else:
                port.self_modulate.a = reserve_opacity
        else:
            port.texture = null
