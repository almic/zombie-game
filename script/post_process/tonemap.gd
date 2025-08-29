@tool
class_name TonemapEffect extends PostProcessEffect

## The white reference value for tonemapping. For photorealistic lighting,
## recommended values are between 6.0 and 8.0.
@export_range(0.0, 16.0, 0.01)
var white: float = 6.0


var sampler: RID


func _init() -> void:
    super._init()


func _shader_path() -> StringName:
    return &"res://shader/post_process/tonemap.glsl"

func _create_shader() -> void:
    super._create_shader()

    # Texture sampler
    var sampler_state: RDSamplerState = RDSamplerState.new()
    sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
    sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
    sampler = rd.sampler_create(sampler_state)

func _render_callback(p_effect_callback_type: int, p_render_data: RenderData) -> void:

    if not (
        rd and
        p_effect_callback_type == effect_callback_type and
        pipeline.is_valid() and shader.is_valid()
    ):
        return

    var render_scene_buffers: RenderSceneBuffersRD = p_render_data.get_render_scene_buffers()
    if not render_scene_buffers:
        return

    var size: Vector2i = render_scene_buffers.get_internal_size()
    if size.x == 0 and size.y == 0:
        return

    @warning_ignore('integer_division')
    var x_groups = (size.x - 1) / 8 + 1
    @warning_ignore('integer_division')
    var y_groups = (size.y - 1) / 8 + 1

    var camera_attributes: RID = p_render_data.get_camera_attributes()
    var exposure_scale: float = RenderingServer.camera_attributes_get_auto_exposure_scale(camera_attributes)

    var push_constants: PackedByteArray = []
    push_constants.resize(16) # size, white, padding
    push_constants.encode_u32(0, size.x)
    push_constants.encode_u32(4, size.y)
    push_constants.encode_float(8, white)
    push_constants.encode_float(12, exposure_scale)

    var view_count = render_scene_buffers.get_view_count()
    for view in range(view_count):
        var input_image = render_scene_buffers.get_color_layer(view)

        var screen_texture: RDUniform = RDUniform.new()
        screen_texture.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
        screen_texture.binding = 0
        screen_texture.add_id(input_image)

        var exposure_texture: RDUniform = RDUniform.new()
        exposure_texture.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
        exposure_texture.binding = 1
        exposure_texture.add_id(sampler)
        exposure_texture.add_id(AutoExposureGlobal.exposure_texture)

        var uniform_set = UniformSetCacheRD.get_cache(shader, 0, [ screen_texture, exposure_texture ])

        var compute_list:= rd.compute_list_begin()
        rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
        rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
        rd.compute_list_set_push_constant(compute_list, push_constants, push_constants.size())
        rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
        rd.compute_list_end()
