@tool
class_name WeaponUI extends MarginContainer

@onready var weapon_texture: TextureRect = %weapon_texture

const ROTATE_UI = preload('res://ui/rotate_ui.gdshader')

## Extend per weapon, update the UI to match the weapon state
func update(weapon: WeaponResource) -> void:
    if not weapon:
        weapon_texture.texture = null
        return

    weapon_texture.texture = weapon.ui_texture


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

## Helper for slamming out rows of bullets, provide a function to be called when
## a bullet should be added, the signature is:
## func add_func(ammo: AmmoResource, parent: HBoxContainer) -> TextureRect
## Returns the reserve type of the added bullets, which can be passed to future
## calls to avoid recreating the UI each update.
static func update_reserve_rows(
        weapon: WeaponResource,
        rows: Array[HBoxContainer],
        row_extra_count: int,
        opacity: float,
        reserve_type: int,
        add_func: Callable
) -> int:
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
            rect = add_func.call(ammo, row)
        else:
            rect = row.get_child(i)

        if k + 1 > ammo_count:
            rect.self_modulate.a = opacity
        else:
            rect.self_modulate.a = 1.0

    # NOTE: Pistol can chamber 1 round, and is shown on the last row if needed
    var chamber_ammo: AmmoResource = weapon.get_chamber_round().ammo
    if not chamber_ammo:
        chamber_ammo = ammo

    var chamber: TextureRect
    if adding:
        chamber = add_func.call(chamber_ammo, rows.back())
    else:
        chamber = rows.back().get_child(-1)

        update_texture_rect(
                chamber,
                chamber_ammo.ui_texture,
                chamber_ammo.ui_texture_rotation,
                chamber_ammo.ui_texture_pivot
        )

    chamber.visible = ammo_count > weapon.ammo_reserve_size

    return ammo.type
