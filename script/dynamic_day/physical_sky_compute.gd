@tool
class_name PhysicalSkyCompute
extends CompositorEffect

## Transmittance LUT resolution, computed once only when needed and retained
## for future frames. Since it is cached, be mindful of memory usage.
@export_enum("64:64","128:128","256:256","512:512","1024:1024")
var lut_size: int = 512:
    set(value):
        if value == lut_size:
            return
        lut_size = value
        _lut_size_changed = true
var _lut_size_changed: bool = true

## Transmittance LUT steps, computed once only when needed and retained for
## future frames. Since it is cached, consider using high values.
@export_range(1, 32, 1)
var lut_steps: int = 32:
    set(value):
        if value == lut_steps:
            return
        lut_steps = value
        _lut_steps_changed = true
var _lut_steps_changed: bool = true

## Sky resolution. The shader actually scales the space to dedicate more texels
## to the horizon, so you can use low values and still get good results.
@export_enum("64:64","128:128","256:256","512:512","1024:1024")
var sky_size: int = 256:
    set(value):
        if value == sky_size:
            return
        sky_size = value
        _sky_size_changed = true
var _sky_size_changed: bool = true

## Sky steps, higher is slower but better looking. This has diminishing returns,
## so play with the value until you are happy with the FPS and quality.
@export_range(1, 32, 1)
var sky_steps: int = 16

## Direction of the sun
@export var sun_direction: Vector3

var rd: RenderingDevice

var lut: RID
var lut_sampler: RID
var lut_shader: RID
var lut_pipeline: RID
var lut_uniform_set: RID:
    get():
        var lut_uniform: RDUniform = RDUniform.new()
        lut_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
        lut_uniform.binding = 0
        lut_uniform.add_id(lut)

        return UniformSetCacheRD.get_cache(lut_shader, 0, [lut_uniform])

var sky: RID
var sky_shader: RID
var sky_pipeline: RID
var sky_uniform_set: RID:
    get():
        var sky_lut_uniform: RDUniform = RDUniform.new()
        sky_lut_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
        sky_lut_uniform.binding = 0
        sky_lut_uniform.add_id(lut_sampler)
        sky_lut_uniform.add_id(lut)

        var sky_image_uniform: RDUniform = RDUniform.new()
        sky_image_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
        sky_image_uniform.binding = 1
        sky_image_uniform.add_id(sky)

        return UniformSetCacheRD.get_cache(
            sky_shader,
            0,
            [sky_lut_uniform, sky_image_uniform],
        )

var sky_texture: Texture2DRD = Texture2DRD.new()
var lut_texture: Texture2DRD = Texture2DRD.new()

func _init() -> void:
    effect_callback_type = EFFECT_CALLBACK_TYPE_POST_OPAQUE
    reload_shaders()

func _notification(what: int) -> void:
    if not what == NOTIFICATION_PREDELETE:
        return

    print_debug("destroying sky compute")

    # LUT resources
    if lut.is_valid():
        rd.free_rid(lut)
        lut = RID()
    if lut_sampler.is_valid():
        rd.free_rid(lut_sampler)
        lut_sampler = RID()
    if lut_shader.is_valid():
        rd.free_rid(lut_shader)
        lut_shader = RID()

    # Sky resources
    if sky.is_valid():
        rd.free_rid(sky)
        sky = RID()
    if sky_shader.is_valid():
        rd.free_rid(sky_shader)
        sky_shader = RID()

func reload_shaders() -> void:
    RenderingServer.call_on_render_thread(initialize_shader)

func initialize_shader() -> void:
    rd = RenderingServer.get_rendering_device()
    if not rd:
        push_error("Failed te get a rendering device!")
        return

    # Free in case we are reloading
    if sky_shader.is_valid():
        rd.free_rid(sky_shader)
    if lut_shader.is_valid():
        rd.free_rid(lut_shader)

    # Load LUT and Sky shaders
    var shader_file = load("res://script/dynamic_day/transmittance.glsl")
    var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()

    lut_shader = rd.shader_create_from_spirv(shader_spirv)
    if not lut_shader.is_valid():
        push_error("Failed to load transmittance GLSL!")
        return

    lut_pipeline = rd.compute_pipeline_create(lut_shader)
    if not lut_pipeline.is_valid():
        push_error("Failed to create LUT pipeline!")
        return

    shader_file = load("res://script/dynamic_day/atmosphere.glsl")
    shader_spirv = shader_file.get_spirv()

    sky_shader = rd.shader_create_from_spirv(shader_spirv)
    if not sky_shader.is_valid():
        push_error("Failed to load sky GLSL!")
        return

    sky_pipeline = rd.compute_pipeline_create(sky_shader)
    if not sky_pipeline.is_valid():
        push_error("Failed to create Sky pipeline!")
        return

    # LUT and Sky texture creation
    create_lut()
    create_sky()

    # Need a sampler for the lut texture
    var lut_sm: RDSamplerState = RDSamplerState.new()
    lut_sm.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
    lut_sm.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR

    lut_sampler = rd.sampler_create(lut_sm)
    if not lut_sampler.is_valid():
        push_error("Failed to create LUT sampler!")
        return

func create_lut() -> void:
    var lut_tf: RDTextureFormat = RDTextureFormat.new()
    lut_tf.is_discardable = false # This is computed once and kept until a resize
    lut_tf.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
    lut_tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
    lut_tf.width = lut_size
    lut_tf.height = lut_size
    lut_tf.mipmaps = 1
    lut_tf.usage_bits = (
        RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
        RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT |
        RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
        RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
    )

    lut = rd.texture_create(lut_tf, RDTextureView.new())

    if not lut.is_valid():
        push_error("Failed to create LUT texture!")

    # This cleans up our old textures for us... actually kinda annoying
    lut_texture.texture_rd_rid = lut

func create_sky() -> void:
    var sky_tf: RDTextureFormat = RDTextureFormat.new()
    sky_tf.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
    sky_tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
    sky_tf.width = sky_size
    sky_tf.height = sky_size
    sky_tf.mipmaps = 1
    sky_tf.usage_bits = (
        RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
        RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT |
        RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
        RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
    )

    # Investigate if this really gives a performance benefit
    # Sky is already computed each frame
    sky_tf.is_discardable = false

    sky = rd.texture_create(sky_tf, RDTextureView.new())
    if not sky.is_valid():
        push_error("Failed to create Sky texture!")

    # This cleans up our old textures for us... actually kinda annoying
    sky_texture.texture_rd_rid = sky

func _render_callback(p_effect_callback_type: int, _render_data: RenderData) -> void:

    if not (
        rd and
        p_effect_callback_type == EFFECT_CALLBACK_TYPE_POST_OPAQUE and
        lut_pipeline.is_valid() and sky_pipeline.is_valid() and
        sky.is_valid() and lut.is_valid()
    ):
        return

    # We only need to compute when LUT is changed
    if _lut_size_changed:
        create_lut()
        _lut_size_changed = false
        _lut_steps_changed = true # force next test to compute

    if _lut_steps_changed:
        compute_lut()
        _lut_steps_changed = false

    # Run the sky shader every frame
    if _sky_size_changed:
        create_sky()
        _sky_size_changed = false

    compute_sky()


func compute_lut() -> void:
    @warning_ignore("integer_division")
    var groups: int = int(lut_size / 8)

    var push_constants: PackedByteArray = []
    push_constants.resize(16) # size and step count, padded to 16
    push_constants.encode_u32(0, lut_size)
    push_constants.encode_u32(4, lut_steps)

    var compute: int = rd.compute_list_begin()
    rd.compute_list_bind_compute_pipeline(compute, lut_pipeline)
    rd.compute_list_bind_uniform_set(compute, lut_uniform_set, 0)
    rd.compute_list_set_push_constant(compute, push_constants, push_constants.size())
    rd.compute_list_dispatch(compute, groups, groups, 1)
    rd.compute_list_end()

func compute_sky() -> void:
    @warning_ignore("integer_division")
    var groups: int = int(sky_size / 8)

    var push_constants: PackedByteArray = []
    push_constants.resize(32) # size, steps, padding, sun direction, padding
    push_constants.encode_u32(0, sky_size)
    push_constants.encode_u32(4, sky_steps)

    # TODO: update sky shader to use Godot's coordinate system so we don't have
    #       to do any direction fixing math
    # Swizzle y and z, negate y
    push_constants.encode_float(16, sun_direction.x)
    push_constants.encode_float(20, sun_direction.z)
    push_constants.encode_float(24, -sun_direction.y)

    var compute: int = rd.compute_list_begin()
    rd.compute_list_bind_compute_pipeline(compute, sky_pipeline)
    rd.compute_list_bind_uniform_set(compute, sky_uniform_set, 0)
    rd.compute_list_set_push_constant(compute, push_constants, push_constants.size())

    # Must wait for LUT to finish, and then finish sky before sending to shader
    rd.compute_list_add_barrier(compute)
    rd.compute_list_dispatch(compute, groups, groups, 1)
    rd.compute_list_add_barrier(compute)

    rd.compute_list_end()
