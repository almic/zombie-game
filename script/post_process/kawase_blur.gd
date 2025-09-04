@tool
class_name KawaseBlurEffect extends PostProcessEffect

## The passes to perform for the blur effect
@export
var passes: PackedFloat32Array = [0.5, 1.5, 2.5, 2.5, 3.5]

## Offset multiplier, can be used for cool effects
@export_range(1.0, 4.0, 0.0001, 'or_greater', 'or_less')
var offset_multiplier: float = 1.0


## The global class loads the shader
func _create_shader() -> void:
    pass

func _render_callback(p_effect_callback_type: int, p_render_data: RenderData) -> void:

    if not (
        rd and
        p_effect_callback_type == effect_callback_type
    ):
        return

    var render_scene_buffers: RenderSceneBuffersRD = p_render_data.get_render_scene_buffers()
    if not render_scene_buffers:
        return

    var size: Vector2i = render_scene_buffers.get_internal_size()
    if size.x == 0 and size.y == 0:
        return

    var view_count = render_scene_buffers.get_view_count()
    for view in range(view_count):
        var input_image = render_scene_buffers.get_color_layer(view)

        KawaseBlurGlobal.blur(input_image, size, passes, offset_multiplier, true)
