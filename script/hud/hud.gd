@tool

class_name HUD extends Control


@onready var cross_hair: CrossHair = %CrossHair

@onready var score_value: Label = %score_value

@onready var health_bar: ProgressBar = %health_bar

@onready var time: Label = %time

@onready var weapon_hud: Control = %weapon_hud

@onready var stock_texture: TextureRect = %stock_texture
@onready var stock_amount: Label = %stock_amount


@export_group("Preview", "_preview")

@export var _preview_weapon: WeaponResource:
    set(value):
        if not Engine.is_editor_hint():
            _preview_weapon = null
            return

        _preview_weapon = value
        _preview_weapon._mixed_reserve = _preview_weapon_ammo_mix
        update_weapon_hud.call_deferred(_preview_weapon)

@export var _preview_weapon_ammo_mix: PackedInt32Array:
    set(value):
        if not Engine.is_editor_hint():
            _preview_weapon_ammo_mix = []
            return

        _preview_weapon_ammo_mix = value
        _preview_weapon._mixed_reserve = _preview_weapon_ammo_mix
        _preview_weapon._simple_reserve_type = _preview_weapon_ammo_reserve_type
        _preview_weapon._simple_reserve_total = _preview_weapon_ammo_reserve_total
        update_weapon_hud.call_deferred(_preview_weapon)

@export var _preview_weapon_ammo_reserve_type: int:
    set(value):
        if not Engine.is_editor_hint():
            _preview_weapon_ammo_reserve_type = 0
            return

        _preview_weapon_ammo_reserve_type = value
        _preview_weapon._simple_reserve_type = _preview_weapon_ammo_reserve_type
        update_weapon_hud.call_deferred(_preview_weapon)

@export var _preview_weapon_ammo_reserve_total: int:
    set(value):
        if not Engine.is_editor_hint():
            _preview_weapon_ammo_reserve_total = 0
            return

        _preview_weapon_ammo_reserve_total = value
        _preview_weapon._simple_reserve_total = _preview_weapon_ammo_reserve_total
        update_weapon_hud.call_deferred(_preview_weapon)

@export var _preview_stock_ammo: Dictionary:
    set(value):
        if not Engine.is_editor_hint():
            _preview_stock_ammo = {}
            return

        _preview_stock_ammo = value
        update_weapon_hud.call_deferred(_preview_weapon)


## Path of the currently displayed weapon ui
var _weapon_hud_scene_path: String
var _weapon_ui_scene: WeaponUI


func _ready() -> void:
    if not Engine.is_editor_hint():
        reset.call_deferred()

func _process(_delta: float) -> void:
    # Set shader parameters
    var mat: ShaderMaterial = stock_texture.material as ShaderMaterial
    if mat:
        mat.set_shader_parameter('size', stock_texture.size)

## Resets all elements and placeholders prior to in-game layout
func reset() -> void:
    score_value.text = '0'
    health_bar.value = 0

## Set the crosshair's visibility
@warning_ignore('shadowed_variable_base_class')
func set_crosshair_visible(visible: bool) -> void:
    cross_hair.visible = visible

func update_score(score: int) -> void:
    score_value.text = str(score)

func update_health(health: float) -> void:
    health_bar.value = health

func update_time(clock_time: String) -> void:
    time.text = clock_time

func update_weapon_hud(weapon: WeaponResource) -> void:
    if not _weapon_hud_scene_path or weapon.scene_ui.resource_path != _weapon_hud_scene_path:
        if _weapon_ui_scene:
            weapon_hud.remove_child(_weapon_ui_scene)
            _weapon_ui_scene.queue_free()
            _weapon_ui_scene = null

        _weapon_ui_scene = weapon.scene_ui.instantiate() as WeaponUI
        _weapon_hud_scene_path = weapon.scene_ui.resource_path

        # NOTE: temporary for development, should be removed
        if not _weapon_ui_scene:
            push_error('Weapon type does not have a UI scene set correctly! Investigate!')
            return

        weapon_hud.add_child(_weapon_ui_scene)

    if weapon:
        var stock: Dictionary = weapon.ammo_stock

        if Engine.is_editor_hint() and not stock:
            stock = _preview_stock_ammo

        if stock:
            stock_texture.texture = stock.ammo.ui_texture
            stock_amount.text = str(stock.amount)

            var mat: ShaderMaterial = stock_texture.material as ShaderMaterial
            if mat:
                mat.set_shader_parameter('rotation', stock.ammo.ui_texture_rotation)
                mat.set_shader_parameter('pivot', stock.ammo.ui_texture_pivot)

        else:
            stock_texture.texture = null
            stock_amount.text = ''

    if not _weapon_ui_scene:
        return

    _weapon_ui_scene.update(weapon)
