## Custom auto-exposure post process effect. Uses a lot of Godot's auto-exposure
## implementation, with a custom shader.
@tool
class_name AutoExposureEffect extends PostProcessEffect


const VERSION_DEFINES = '#VERSION_DEFINES'
const READ_TEXTURE = '#define READ_TEXTURE'
const INTERPOLATE_LUMINANCE = '#define INTERPOLATE_LUMINANCE'


var current: RID
var buffers: Array[RID]

var read_shader: RID
var interpolate_shader: RID

var read_pipeline: RID
var interpolate_pipeline: RID

var sampler: RID

func _shader_path() -> StringName:
    return &"res://shader/post_process/auto_exposure.glsl"

func _notification(what: int) -> void:
    if not what == NOTIFICATION_PREDELETE:
        return

    if current.is_valid():
        rd.free_rid(current)
    current = RID()

    for rid in buffers:
        if rid.is_valid():
            rd.free_rid(rid)
    buffers.clear()

    if shader.is_valid():
        rd.free_rid(shader)
        shader = RID()
    pipeline = RID()

    if read_shader.is_valid():
        rd.free_rid(read_shader)
        read_shader = RID()
    read_pipeline = RID()

    if interpolate_shader.is_valid():
        rd.free_rid(interpolate_shader)
        interpolate_shader = RID()
    interpolate_pipeline = RID()

    if sampler.is_valid():
        rd.free_rid(sampler)
        sampler = RID()

func _create_shader() -> void:
    var shader_file: FileAccess = FileAccess.open(_shader_path(), FileAccess.READ)
    var shader_code: String = shader_file.get_as_text(true)

    # Normal shader
    var shader_source: RDShaderSource = RDShaderSource.new()
    shader_source.language = RenderingDevice.SHADER_LANGUAGE_GLSL
    shader_source.source_compute = shader_code.replace(VERSION_DEFINES, '')
    var shader_spirv: RDShaderSPIRV = rd.shader_compile_spirv_from_source(shader_source)
    if shader_spirv.compile_error_compute != "":
        push_error(shader_spirv.compile_error_compute)
        push_error(shader_source.source_compute)

    shader = rd.shader_create_from_spirv(shader_spirv)
    pipeline = rd.compute_pipeline_create(shader)

    # Read shader
    shader_source.source_compute = shader_code.replace(VERSION_DEFINES, READ_TEXTURE)
    shader_spirv = rd.shader_compile_spirv_from_source(shader_source)
    if shader_spirv.compile_error_compute != "":
        push_error(shader_spirv.compile_error_compute)
        push_error(shader_source.source_compute)

    read_shader = rd.shader_create_from_spirv(shader_spirv)
    read_pipeline = rd.compute_pipeline_create(read_shader)

    # Interpolate shader
    shader_source.source_compute = shader_code.replace(VERSION_DEFINES, INTERPOLATE_LUMINANCE)
    shader_spirv = rd.shader_compile_spirv_from_source(shader_source)
    if shader_spirv.compile_error_compute != "":
        push_error(shader_spirv.compile_error_compute)
        push_error(shader_source.source_compute)

    interpolate_shader = rd.shader_create_from_spirv(shader_spirv)
    interpolate_pipeline = rd.compute_pipeline_create(interpolate_shader)

    # Texture sampler
    var sampler_state: RDSamplerState = RDSamplerState.new()
    sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
    sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
    sampler = rd.sampler_create(sampler_state)

func clear_buffers() -> void:
    if current.is_valid():
        rd.free_rid(current)
    current = RID()

    for rid in buffers:
        if rid.is_valid():
            rd.free_rid(rid)
    buffers.clear()

func setup_buffers(size: Vector2i) -> void:
    clear_buffers()

    var w: int = size.x
    var h: int = size.y

    # what the Godot moment
    while true:
        @warning_ignore('integer_division')
        w = maxi(w / 8, 1)
        @warning_ignore('integer_division')
        h = maxi(h / 8, 1)

        var final: bool = w == 1 and h == 1
        var tf: RDTextureFormat = RDTextureFormat.new()

        tf.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
        tf.width = w
        tf.height = h

        tf.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT

        if final:
            tf.usage_bits |= RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT

        buffers.append(rd.texture_create(tf, RDTextureView.new()))

        if final:
            current = rd.texture_create(tf, RDTextureView.new())
            rd.texture_clear(current, Color(), 0, 1, 0, 1)
            break

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

    if not current.is_valid():
        setup_buffers(size)

    var camera_attributes: RID = p_render_data.get_camera_attributes()
    var min_exposure: float = RenderingServer.camera_attributes_get_auto_exposure_min_sensitivity(camera_attributes)
    var max_exposure: float = RenderingServer.camera_attributes_get_auto_exposure_max_sensitivity(camera_attributes)
    var adjustment: float = RenderingServer.camera_attributes_get_auto_exposure_adjust_speed(camera_attributes)
    adjustment *= p_render_data.get_render_scene_data().get_time_step()

    var push_constants: PackedByteArray = []
    push_constants.resize(32) # size, min, max, adjustment, padding
    push_constants.encode_s32(0, size.x)
    push_constants.encode_s32(4, size.y)
    push_constants.encode_float(8, max_exposure)
    push_constants.encode_float(12, min_exposure)
    push_constants.encode_float(16, adjustment)

    var compute_list := rd.compute_list_begin()
    var compute_shader: RID

    for view in range(render_scene_buffers.get_view_count()):
        var input_image: RID = render_scene_buffers.get_color_layer(view)

        if view != 0:
            rd.compute_list_add_barrier(compute_list)

        for i in range(buffers.size()):
            if i == 0:
                var screen_texture: RDUniform = RDUniform.new()
                screen_texture.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
                screen_texture.binding = 0
                screen_texture.add_id(sampler)
                screen_texture.add_id(input_image)

                compute_shader = read_shader
                rd.compute_list_bind_compute_pipeline(compute_list, read_pipeline)
                rd.compute_list_bind_uniform_set(compute_list, UniformSetCacheRD.get_cache(read_shader, 0, [screen_texture]), 0)
            else:
                rd.compute_list_add_barrier(compute_list)

                if i == buffers.size() - 1:
                    # NOTE: on the last buffer, send the previous result for intepolation
                    var current_luminance: RDUniform = RDUniform.new()
                    current_luminance.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
                    current_luminance.binding = 0
                    current_luminance.add_id(sampler)
                    current_luminance.add_id(current)

                    compute_shader = interpolate_shader
                    rd.compute_list_bind_compute_pipeline(compute_list, interpolate_pipeline)
                    rd.compute_list_bind_uniform_set(compute_list, UniformSetCacheRD.get_cache(interpolate_shader, 2, [current_luminance]), 2)
                else:
                    compute_shader = shader
                    rd.compute_list_bind_compute_pipeline(compute_list, pipeline)

                var source_texture: RDUniform = RDUniform.new()
                source_texture.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
                source_texture.binding = 0
                source_texture.add_id(buffers[i - 1])

                rd.compute_list_bind_uniform_set(compute_list, UniformSetCacheRD.get_cache(compute_shader, 0, [source_texture]), 0)

            var reduce_texture: RDUniform = RDUniform.new()
            reduce_texture.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
            reduce_texture.binding = 0
            reduce_texture.add_id(buffers[i])

            rd.compute_list_bind_uniform_set(compute_list, UniformSetCacheRD.get_cache(compute_shader, 1, [reduce_texture]), 1)

            rd.compute_list_set_push_constant(compute_list, push_constants, push_constants.size())

            var groups_x: int = (size.x + 7) / 8
            var groups_y: int = (size.y + 7) / 8
            rd.compute_list_dispatch(compute_list, groups_x, groups_y, 1)

            @warning_ignore('integer_division')
            size.x = maxi(push_constants.decode_s32(0) / 8, 1)
            @warning_ignore('integer_division')
            size.y = maxi(push_constants.decode_s32(4) / 8, 1)

            # NOTE: This seems weird, buffers never change size but our screen might?
            push_constants.encode_s32(0, size.x)
            push_constants.encode_s32(4, size.y)

    rd.compute_list_end()

    var tmp: RID = current
    current = buffers[buffers.size() - 1]
    AutoExposureGlobal.exposure_texture = current
    buffers[buffers.size() - 1] = tmp
