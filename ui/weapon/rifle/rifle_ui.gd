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

        for row in rows:
            for child in row.get_children():
                var rect: TextureRect = child as TextureRect
                if not rect:
                    continue
                rect.custom_minimum_size.y = ammo_icon_size

@export_range(0.0, 1.0, 0.001)
var reserve_opacity: float = 0.5


var reserve_type: int = 0
var rows: Array[HBoxContainer]


func _ready() -> void:
    rows = [ammo_row_1, ammo_row_2]

func _process(_delta: float) -> void:
    # Set shader parameters
    apply_rect_sizes(rows)


func update(weapon: WeaponResource) -> void:
    super.update(weapon)

    reserve_type = update_reserve_rows(
        weapon,
        rows,
        1,
        reserve_opacity,
        reserve_type,
        _add_ammo_reserve
    )

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
