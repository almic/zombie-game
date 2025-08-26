@tool

class_name PostProcessEffect
extends CompositorEffect

@export_file('*.glsl')
var shader_path: String:
    set(value):
        shader_path = value
        reload_shader()

## The white reference value for tonemapping. For photorealistic lighting,
## recommended values are between 6.0 and 8.0.
@export_range(0.0, 16.0, 0.01)
var white: float = 6.0

var rd: RenderingDevice


var shader: RID
var pipeline: RID


func _init():
    reload_shader()

func _notification(what: int) -> void:
    if not what == NOTIFICATION_PREDELETE:
        return

    if shader.is_valid():
        rd.free_rid(shader)
        shader = RID()


func reload_shader() -> void:
    RenderingServer.call_on_render_thread(initialize_shader)

func initialize_shader() -> void:
    # We can be called long before our resource finishes loading, so wait
    if not shader_path:
        return

    rd = RenderingServer.get_rendering_device()
    if not rd:
        push_error("Failed to get a rendering device!")
        return

    # Free in case we are reloading
    if shader.is_valid():
        rd.free_rid(shader)
        shader = RID()

    pipeline = RID()

    var shader_file = load(shader_path)
    var spirv: RDShaderSPIRV = shader_file.get_spirv()

    shader = rd.shader_create_from_spirv(spirv)
    pipeline = rd.compute_pipeline_create(shader)

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

    var push_constants: PackedByteArray = []
    push_constants.resize(16) # size, white, padding
    push_constants.encode_u32(0, size.x)
    push_constants.encode_u32(4, size.y)
    push_constants.encode_float(8, white)

    var view_count = render_scene_buffers.get_view_count()
    for view in range(view_count):
        var input_image = render_scene_buffers.get_color_layer(view)

        var uniform: RDUniform = RDUniform.new()
        uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
        uniform.binding = 0
        uniform.add_id(input_image)
        var uniform_set = UniformSetCacheRD.get_cache(shader, 0, [ uniform ])

        var compute_list:= rd.compute_list_begin()
        rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
        rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
        rd.compute_list_set_push_constant(compute_list, push_constants, push_constants.size())
        rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
        rd.compute_list_end()
