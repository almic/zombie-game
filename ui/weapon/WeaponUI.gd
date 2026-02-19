@tool
class_name WeaponUI extends MarginContainer


const ROTATE_UI = preload('res://ui/rotate_ui.gdshader')


@onready var weapon_texture: TextureRect = %weapon_texture


@export_range(0.0, 100.0, 1.0, 'or_greater')
var ammo_icon_size: float = 32.0:
    set(value):
        ammo_icon_size = value
        if not is_node_ready():
            return

        for row in rows:
            for child in row.get_children():
                var rect: TextureRect = child as TextureRect
                if not rect:
                    continue
                rect.custom_minimum_size.y = ammo_icon_size

@export_range(-180.0, 180.0, 0.001, 'radians_as_degrees')
var ammo_rotation: float = 0

@export var ammo_rotation_pivot: Vector2 = Vector2(0.5, 0.5)

@export_range(0.0, 1.0, 0.001)
var reserve_opacity: float = 0.4

## If the weapon uses default reserve row behavior
@export var enable_auto_rows: bool = false

## If the weapon uses default row sizing behavior
@export var enable_row_sizing: bool = false

## Extra reserve rounds per row, can use negative values to reduce the length
## of the first rows.
@export_range(-2.0, 2.0, 1.0, 'or_greater', 'or_less')
var row_extra_count: int = 0

## Rows used for reserve, in order
@export var rows: Array[HBoxContainer]


var reserve_type: int = 0


func _process(_delta: float) -> void:
    if enable_row_sizing:
        # Set shader parameters
        apply_rect_sizes(rows)


## Extend per weapon, update the UI to match the weapon state
func update(weapon: WeaponNode) -> void:
    var weapon_type: WeaponResource
    if weapon:
        weapon_type = weapon.weapon_type

    if not weapon_type:
        weapon_texture.texture = null
        return

    weapon_texture.texture = weapon_type.ui_texture

    if enable_auto_rows:
        update_reserve_rows(weapon_type)

static func apply_rect_sizes(parents: Array[Variant]) -> void:
    for parent in parents:
        var node: Node = parent as Node
        if not node:
            continue

        for child in parent.get_children():
            var rect: TextureRect = child as TextureRect
            if not rect:
                continue

            var mat: ShaderMaterial = rect.material as ShaderMaterial
            if mat:
                mat.set_shader_parameter('size', child.size)

static func create_texture_rect(texture: Texture2D, tex_rotation: float, tex_pivot: Vector2) -> TextureRect:
    var texture_rect: TextureRect = TextureRect.new()
    texture_rect.texture = texture

    var mat: ShaderMaterial = ShaderMaterial.new()
    mat.shader = ROTATE_UI
    mat.set_shader_parameter('rotation', tex_rotation)
    mat.set_shader_parameter('pivot', tex_pivot)

    texture_rect.material = mat

    return texture_rect

static func update_texture_rect(
        rect: TextureRect,
        texture: Texture2D,
        tex_rotation: float,
        tex_pivot: Vector2
) -> void:
    rect.texture = texture

    var mat: ShaderMaterial = rect.material as ShaderMaterial
    if not mat:
        return

    mat.set_shader_parameter('rotation', tex_rotation)
    mat.set_shader_parameter('pivot', tex_pivot)

func update_reserve_rows(weapon: WeaponResource) -> void:
    var ammo: AmmoResource = weapon.get_supported_ammunition().get(weapon.get_reserve_type()) as AmmoResource

    if not ammo:
        ammo = weapon.ammo_supported.front()

    var ammo_count: int = weapon.get_reserve_total()
    if weapon.is_chambered() and weapon.is_chambered_live():
        ammo_count += 1

    var adding: bool = reserve_type != ammo.type

    if adding:
        for row in rows:
            for child in row.get_children():
                row.remove_child(child)
                child.queue_free()

    var row_count: int = rows.size()
    var split: int = roundi(float(weapon.ammo_reserve_size) / float(row_count))
    split += row_extra_count
    for k in range(weapon.ammo_reserve_size):
        var i: int = k

        var row_i: int = mini(int(float(i) / float(split)), row_count - 1)
        var row: HBoxContainer = rows[row_i]
        i -= row_i * int(split)

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
        chamber = _add_ammo_reserve(chamber_ammo, rows.back())
    else:
        chamber = rows.back().get_child(-1)

        update_texture_rect(
                chamber,
                chamber_ammo.ui_texture,
                ammo_rotation,
                ammo_rotation_pivot
        )

    chamber.visible = ammo_count > weapon.ammo_reserve_size

    reserve_type = ammo.type

func _add_ammo_reserve(ammo: AmmoResource, parent: HBoxContainer) -> TextureRect:
    var round_texture: TextureRect = create_texture_rect(
            ammo.ui_texture,
            ammo_rotation,
            ammo_rotation_pivot
    )

    parent.add_child(round_texture, Engine.is_editor_hint())

    round_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    round_texture.custom_minimum_size.y = ammo_icon_size
    round_texture.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    round_texture.size_flags_vertical = Control.SIZE_SHRINK_CENTER

    return round_texture
