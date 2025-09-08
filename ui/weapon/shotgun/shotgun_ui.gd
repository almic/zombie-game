@tool
extends WeaponUI


@onready var ammo_flow: HBoxContainer = %ammo_flow


func update(weapon: WeaponResource) -> void:
    super.update(weapon)

    for child in ammo_flow.get_children():
        ammo_flow.remove_child(child)
        child.queue_free()

    var ammo: Dictionary = weapon.get_supported_ammunition()

    if weapon.is_chambered() and weapon.get_chamber_round().is_live:
        _add_ammo_reserve(weapon._chambered_round_type, ammo)

    if weapon.ammo_can_mix:
        var reserve: PackedInt32Array = weapon.get_mixed_reserve()

        if weapon.ammo_reversed_use:
            reserve = reserve.duplicate()
            reserve.reverse()

        for type in reserve:
            # NOTE: HACK for revolver, need rework of weapon UI elements!
            if not type:
                continue
            _add_ammo_reserve(type, ammo)
    else:
        var type: int = weapon.get_reserve_type()
        for i in range(weapon.get_reserve_total()):
            _add_ammo_reserve(type, ammo)

func _add_ammo_reserve(type: int, ammo: Dictionary) -> void:
    var round_texture: TextureRect = TextureRect.new()
    round_texture.texture = ammo.get(type).ui_texture
    ammo_flow.add_child(round_texture, Engine.is_editor_hint())
    round_texture.owner = self.owner
