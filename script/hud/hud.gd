@tool

class_name HUD extends Control


@onready var cross_hair: CrossHair = %CrossHair

@onready var score_value: Label = %score_value

@onready var health_bar: ProgressBar = %health_bar

@onready var weapon_texture: TextureRect = %weapon_texture
@onready var stock_texture: TextureRect = %stock_texture
@onready var stock_amount: Label = %stock_amount

@onready var ammo_flow: HBoxContainer = %ammo_flow


@export_group("Preview", "_preview")

@export var _preview_weapon: WeaponResource:
    set(value):
        if not Engine.is_editor_hint():
            _preview_weapon = null
            return

        _preview_weapon = value
        _preview_weapon._mixed_reserve = _preview_weapon_ammo_mix
        update_weapon_ammo.call_deferred(_preview_weapon)

@export var _preview_weapon_ammo_mix: PackedInt32Array:
    set(value):
        if not Engine.is_editor_hint():
            _preview_weapon_ammo_mix = []
            return

        _preview_weapon_ammo_mix = value
        _preview_weapon._mixed_reserve = _preview_weapon_ammo_mix
        _preview_weapon._simple_reserve_type = _preview_weapon_ammo_reserve_type
        _preview_weapon._simple_reserve_total = _preview_weapon_ammo_reserve_total
        update_weapon_ammo.call_deferred(_preview_weapon)

@export var _preview_weapon_ammo_reserve_type: int:
    set(value):
        if not Engine.is_editor_hint():
            _preview_weapon_ammo_reserve_type = 0
            return

        _preview_weapon_ammo_reserve_type = value
        _preview_weapon._simple_reserve_type = _preview_weapon_ammo_reserve_type
        update_weapon_ammo.call_deferred(_preview_weapon)

@export var _preview_weapon_ammo_reserve_total: int:
    set(value):
        if not Engine.is_editor_hint():
            _preview_weapon_ammo_reserve_total = 0
            return

        _preview_weapon_ammo_reserve_total = value
        _preview_weapon._simple_reserve_total = _preview_weapon_ammo_reserve_total
        update_weapon_ammo.call_deferred(_preview_weapon)

@export var _preview_stock_ammo: Dictionary:
    set(value):
        if not Engine.is_editor_hint():
            _preview_stock_ammo = {}
            return

        _preview_stock_ammo = value
        update_weapon_ammo.call_deferred(_preview_weapon)


func _ready() -> void:
    if not Engine.is_editor_hint():
        reset.call_deferred()

## Resets all elements and placeholders prior to in-game layout
func reset() -> void:
    score_value.text = '0'
    health_bar.value = 0

    for child in ammo_flow.get_children():
        ammo_flow.remove_child(child)
        child.queue_free()

    stock_texture.texture = null
    stock_amount.text = ''

    weapon_texture.texture = null

## Set the crosshair's visibility
@warning_ignore('shadowed_variable_base_class')
func set_crosshair_visible(visible: bool) -> void:
    cross_hair.visible = visible

func update_score(score: int) -> void:
    score_value.text = str(score)

func update_health(health: float) -> void:
    health_bar.value = health

func update_weapon_ammo(weapon: WeaponResource) -> void:

    for child in ammo_flow.get_children():
        ammo_flow.remove_child(child)
        child.queue_free()

    if weapon:
        var stock: Dictionary = weapon.ammo_stock

        if stock:
            stock_texture.texture = stock.ammo.ui_texture
            stock_amount.text = str(stock.amount)
        else:
            stock_texture.texture = null
            stock_amount.text = ''

    if not weapon:
        weapon_texture.texture = null
        return

    weapon_texture.texture = weapon.ui_texture

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
