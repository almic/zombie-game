class_name HUD extends Control

@onready var score_value: Label = %score_value

@onready var health_bar: ProgressBar = %health_bar

@onready var weapon_texture: TextureRect = %weapon_texture
@onready var stock_texture: TextureRect = %stock_texture
@onready var stock_amount: Label = %stock_amount

@onready var ammo_flow: HFlowContainer = %ammo_flow


func update_score(score: int) -> void:
    score_value.text = str(score)

func update_health(health: float) -> void:
    health_bar.value = health

func update_weapon_ammo(weapon: WeaponResource, ammo_stock: Dictionary) -> void:

    for child in ammo_flow.get_children():
        ammo_flow.remove_child(child)
        child.queue_free()

    if ammo_stock:
        stock_texture.texture = ammo_stock.ammo.ui_texture
        stock_amount.text = str(ammo_stock.amount)
    else:
        stock_texture.texture = null
        stock_amount.text = ''

    if not weapon:
        weapon_texture.texture = null
        return

    weapon_texture.texture = weapon.ui_texture

    var ammo: Dictionary = weapon.get_supported_ammunition()

    if weapon.can_chamber and weapon._chambered_round_type:
        add_ammo_reserve(weapon._chambered_round_type, ammo)

    if weapon.ammo_can_mix:
        var reserve: PackedInt32Array = weapon.get_mixed_reserve()

        if weapon.ammo_reversed_use:
            reserve = reserve.duplicate()
            reserve.reverse()

        for type in reserve:
            add_ammo_reserve(type, ammo)
    else:
        var type: int = weapon.get_reserve_type()
        for i in range(weapon.get_reserve_total()):
            add_ammo_reserve(type, ammo)

func add_ammo_reserve(type: int, ammo: Dictionary) -> void:
    var round_texture: TextureRect = TextureRect.new()
    round_texture.texture = ammo.get(type).ui_texture
    ammo_flow.add_child(round_texture)
