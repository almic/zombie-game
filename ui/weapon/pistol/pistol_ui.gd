@tool
extends WeaponUI


@onready var ammo_row_1: HBoxContainer = %ammo_row_1
@onready var ammo_row_2: HBoxContainer = %ammo_row_2


@export_range(0.0, 100.0, 1.0, 'or_greater')
var ammo_icon_size: float = 18.0:
    set(value):
        ammo_icon_size = value
        if not is_node_ready():
            return

        for row in [ammo_row_1, ammo_row_2]:
            for child in row.get_children():
                var rect: TextureRect = child as TextureRect
                if not rect:
                    continue
                rect.custom_minimum_size.y = ammo_icon_size

@export_range(0.0, 1.0, 0.001)
var reserve_opacity: float = 0.5


var reserve_type: int = 0


func _process(_delta: float) -> void:
    # Set shader parameters
    apply_rect_sizes([ammo_row_1, ammo_row_2])


func update(weapon: WeaponResource) -> void:
    super.update(weapon)

    var ammo: AmmoResource = weapon.get_supported_ammunition().get(weapon.get_reserve_type()) as AmmoResource

    if not ammo:
        ammo = weapon.ammo_supported.front()

    var ammo_count: int = weapon.get_reserve_total()
    if weapon.is_chambered() and weapon.is_chambered_live():
        ammo_count += 1

    var adding: bool = reserve_type != ammo.type
    reserve_type = ammo.type

    if adding:
        print('clearing ammo icons!')
        for row in [ammo_row_1, ammo_row_2]:
            for child in row.get_children():
                row.remove_child(child)
                child.queue_free()

    var half: int = int(float(weapon.ammo_reserve_size) / 2.0)
    for k in range(weapon.ammo_reserve_size):
        var row: HBoxContainer
        var i: int = k

        if i > half:
            row = ammo_row_2
            i -= half + 1
        else:
            row = ammo_row_1

        var rect: TextureRect
        if adding:
            rect = _add_ammo_reserve(ammo, row)
        else:
            rect = row.get_child(i)

        if k + 1 > ammo_count:
            rect.self_modulate.a = reserve_opacity
        else:
            rect.self_modulate.a = 1.0

    # NOTE: Pistol can chamber 1 round, and is shown on the last row if needed
    var chamber_ammo: AmmoResource = weapon.get_chamber_round().ammo
    if not chamber_ammo:
        chamber_ammo = ammo

    var chamber: TextureRect
    if adding:
        chamber = _add_ammo_reserve(chamber_ammo, ammo_row_2)
    else:
        chamber = ammo_row_2.get_child(-1) as TextureRect

        update_texture_rect(
                chamber,
                chamber_ammo.ui_texture,
                chamber_ammo.ui_texture_rotation,
                chamber_ammo.ui_texture_pivot
        )

    chamber.visible = ammo_count > weapon.ammo_reserve_size


func _add_ammo_reserve(ammo: AmmoResource, parent: HBoxContainer) -> TextureRect:
    var round_texture: TextureRect = create_texture_rect(
            ammo.ui_texture,
            ammo.ui_texture_rotation,
            ammo.ui_texture_pivot
    )

    round_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    round_texture.custom_minimum_size.y = ammo_icon_size
    round_texture.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    round_texture.size_flags_vertical = Control.SIZE_SHRINK_CENTER

    parent.add_child(round_texture, Engine.is_editor_hint())
    return round_texture
