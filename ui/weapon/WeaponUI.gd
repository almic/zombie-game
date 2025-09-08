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


static func apply_rect_sizes(parents: Array[Node]) -> void:
    for parent in parents:
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
