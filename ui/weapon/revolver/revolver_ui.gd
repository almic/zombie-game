@tool
extends WeaponUI


## Maximum spin rate of the cylinder on the UI, in radians per second.
## Handles fan-fire spins by applying some short interpolation using this value.
const MAX_SPIN_RATE: float = deg_to_rad(480.0)


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


var revolver_weapon: RevolverWeapon
var cylinder_interp: Interpolation = Interpolation.new(0.0, Tween.TRANS_EXPO, Tween.EASE_OUT)
var ports: Array[TextureRect]


func _ready() -> void:
    ports = [port_1, port_2, port_3, port_4, port_5, port_6]

    for i in range(ports.size()):
        var port: TextureRect = ports[i]
        port.rotation = -i * (PI / 3.0)


func _process(delta: float) -> void:
    if revolver_weapon:
        # NOTE: This value is updated by the animated weapon scene. Due to -Z,
        #       we always want the negative rotation from 3D.
        var target: float = fposmod(-revolver_weapon._animated_cylinder_rotation, TAU)

        var diff: float = target - cylinder.rotation
        var diff_2: float
        if target > cylinder.rotation:
            diff_2 = (cylinder.rotation + TAU) - target
            if abs(diff_2) <= abs(diff):
                cylinder.rotation += TAU
                diff = -diff_2
        else:
            diff_2 = target - (cylinder.rotation - TAU)
            if abs(diff_2) <= abs(diff):
                cylinder.rotation -= TAU
                diff = diff_2

        var rate: float = abs(diff / delta)

        # NOTE: MY EYES!!!!
        if (
                    rate > MAX_SPIN_RATE
                and (
                    cylinder_interp.is_done
                    or (
                            cylinder_interp.is_target_set
                        and not is_equal_approx(cylinder_interp.target, target)
                    )
                )
        ):
            var first_target: bool = !cylinder_interp.is_target_set
            cylinder_interp.set_target_delta(target, diff, cylinder.rotation)
            if first_target:
                cylinder_interp.duration = min(1.0, abs(diff / deg_to_rad(60)))
            else:
                cylinder_interp.duration = min(0.125, abs(diff / MAX_SPIN_RATE))

        if not cylinder_interp.is_done:
            cylinder.rotation = cylinder_interp.update(delta)
        else:
            cylinder.rotation = target


func update(weapon: WeaponResource) -> void:
    super.update(weapon)

    var revolver: RevolverWeapon = weapon as RevolverWeapon
    if not revolver:
        return
    revolver_weapon = revolver

    if revolver.hammer_cocked:
        marker.self_modulate = marker_color_cocked
    else:
        marker.self_modulate = marker_color

    # NOTE NOTE: I don't think this needs to be done...
    # NOTE: When we are told to update, snap to the true angle
    # cylinder.rotation = deg_to_rad(60.0 * revolver._cylinder_position)

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
