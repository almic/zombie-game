@tool
class_name PhysicalSkyCompute
extends CompositorEffect

## Transmittance LUT resolution, computed once only when needed and retained
## for future frames. Since it is cached, be mindful of memory usage.
@export_enum("64:64","128:128","256:256","512:512","1024:1024")
var lut_size: int:
    set(value):
        if value == lut_size:
            return
        lut_size = value
        _lut_changed = true

## Transmittance LUT steps, computed once only when needed and retained for
## future frames. Since it is cached, consider using high values.
@export_range(1, 32, 1, 'hide_slider')
var lut_steps: int = 32:
    set(value):
        if value == lut_steps:
            return
        lut_steps = value
        _lut_changed = true

var _lut_changed: bool = true

## Sky resolution. The shader actually scales the space to dedicate more texels
## to the horizon, so you can use low values and still get good results.
@export_enum("64:64","128:128","256:256","512:512","1024:1024")
var sky_size: int = 256

## Sky steps, higher is slower but better looking. This has diminishing returns,
## so play with the value until you are happy with the FPS and quality.
@export_range(1, 32, 1, 'hide_slider')
var sky_steps: int = 16


var rd: RenderingDevice

var lut: RID
var lut_shader: RID
var lut_pipeline: RID

var sky: RID
var sky_shader: RID
var sky_pipeline: RID


func _init() -> void:
    effect_callback_type = EFFECT_CALLBACK_TYPE_POST_OPAQUE
    rd = RenderingServer.get_rendering_device()
    RenderingServer.call_on_render_thread(initialize_shader)

func _notification(what: int) -> void:
    if what == NOTIFICATION_PREDELETE:
        if lut_shader.is_valid():
            rd.free_rid(lut_shader)
        if sky_shader.is_valid():
            rd.free_rid(sky_shader)

func initialize_shader() -> void:
    rd = RenderingServer.get_rendering_device()
    if not rd:
        return

    # Load LUT and Sky shaders
    var shader_file = load("res://script/dynamic_day/transmittance.glsl")
    var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()

    lut_shader = rd.shader_create_from_spirv(shader_spirv)
    if not lut_shader.is_valid():
        return

    lut_pipeline = rd.compute_pipeline_create(lut_shader)

    shader_file = load("res://script/dynamic_day/sky.glsl")
    shader_spirv = shader_file.get_spirv()

    sky_shader = rd.shader_create_from_spirv(shader_spirv)
    if not sky_shader.is_valid():
        return

    sky_pipeline = rd.compute_pipeline_create(sky_shader)

    # LUT and Sky texture creation
    var lut_tf: RDTextureFormat = RDTextureFormat.new()
    lut_tf.is_discardable = false # This is computed once and kept until a resize
    lut_tf.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
    lut_tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
    lut_tf.width = lut_size
    lut_tf.height = lut_size
    lut_tf.usage_bits = (
        RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
        RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT |
        RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
    )

    var sky_tf: RDTextureFormat = RDTextureFormat.new()
    sky_tf.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
    sky_tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
    sky_tf.width = sky_size
    sky_tf.height = sky_size
    sky_tf.usage_bits = (
        RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
        RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT |
        RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
    )

    # Investigate if this really gives a performance benefit
    # Sky is already computed each frame
    sky_tf.is_discardable = true

    lut = rd.texture_create(lut_tf, RDTextureView.new())
    sky = rd.texture_create(sky_tf, RDTextureView.new())

func _render_callback(p_effect_callback_type: int, render_data: RenderData) -> void:
    if not (
        rd and
        p_effect_callback_type == EFFECT_CALLBACK_TYPE_POST_OPAQUE and
        lut_pipeline.is_valid() and sky_pipeline.is_valid()
    ):
        return


    # We only need to compute when LUT is changed
    if _lut_changed:
        var push_constants: PackedByteArray = []
        push_constants.resize(16) # size and step count with padding
        push_constants.encode_u32(0, lut_size)
        push_constants.encode_u32(4, lut_steps)
