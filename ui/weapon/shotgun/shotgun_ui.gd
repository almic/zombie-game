@tool
extends WeaponUI


@export var empty_slot_texture: Texture2D


var reserve_size: int = 0


func update(weapon_node: WeaponNode) -> void:
    super.update(weapon_node)

    var weapon: WeaponResource = weapon_node.weapon_type
    var adding: bool = weapon.ammo_reserve_size != reserve_size
    reserve_size = weapon.ammo_reserve_size

    var ammo_row: HBoxContainer = rows.front()

    if adding:
        for child in ammo_row.get_children():
            ammo_row.remove_child(child)
            child.queue_free()

    var supported: Dictionary = weapon.get_supported_ammunition()
    var reserve: PackedInt32Array = weapon.get_mixed_reserve()
    var reserve_total: int = reserve.size()

    for i in range(weapon.ammo_reserve_size):
        var rect: TextureRect

        var tex: Texture2D = empty_slot_texture
        var opacity: float = reserve_opacity

        if i < reserve_total:
            var ammo: AmmoResource = supported.get(reserve[reserve_total - i - 1]) as AmmoResource
            if ammo:
                tex = ammo.ui_texture
                opacity = 1.0

        if adding:
            rect = create_texture_rect(
                    tex,
                    ammo_rotation,
                    ammo_rotation_pivot
            )
            _set_rect_size(rect)
            ammo_row.add_child(rect)
        else:
            # NOTE: the first slot is for the chamber round
            rect = ammo_row.get_child(i + 1)
            update_texture_rect(
                    rect,
                    tex,
                    ammo_rotation,
                    ammo_rotation_pivot
            )

        rect.self_modulate.a = opacity

    var chamber_ammo: AmmoResource = weapon.get_chamber_round().ammo
    var chamber_tex: Texture2D = empty_slot_texture
    if chamber_ammo:
        chamber_tex = chamber_ammo.ui_texture

    var chamber: TextureRect
    if adding:
        chamber = create_texture_rect(
                chamber_tex,
                ammo_rotation,
                ammo_rotation_pivot
        )
        _set_rect_size(chamber)
        ammo_row.add_child(chamber)
        ammo_row.move_child(chamber, 0)
    else:
        chamber = ammo_row.get_child(0)
        update_texture_rect(
                chamber,
                chamber_tex,
                ammo_rotation,
                ammo_rotation_pivot
        )

    if weapon.is_chambered_live():
        chamber.self_modulate.a = 1.0
    else:
        chamber.self_modulate.a = reserve_opacity

    if adding:
        apply_rect_sizes.call_deferred(rows)

func _set_rect_size(rect: TextureRect) -> void:
    rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    rect.custom_minimum_size.y = ammo_icon_size
    rect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
