## Global class for Kawase blur effects
@tool
extends Node


var rd: RenderingDevice


var shader: RID
var pipeline: RID

var sampler: RID

## The current buffer result of Kawase blur
var current: RID

## The working buffer, used for intermediate steps
var working: RID

## Current buffer size, used to resize buffers
var buffer_size: Vector2i


## Lookup table for pixel offsets, index is pixel blur - 1
const OFFSET_TABLE = [
    # 1 pixel blur
    [0.5],
    # 2 pixels
    [0.5, 1.5],
    # 3 pixels
    [0.5, 1.5, 1.5],
    # 4 pixels
    [0.5, 1.5, 1.5, 2.5],
    # 5 pixels
    [0.5, 1.5, 2.5, 2.5],
    # 35x35
    [0.5, 1.5, 2.5, 2.5, 3.5],
]


func _shader_path() -> StringName:
    return &"res://shader/post_process/kawase.glsl"

func _init() -> void:
    RenderingServer.call_on_render_thread(initialize)

func _notification(what: int) -> void:
    if not what == NOTIFICATION_PREDELETE:
        return

    if sampler.is_valid():
        rd.free_rid(sampler)
        sampler = RID()

    if current.is_valid():
        rd.free_rid(current)
        current = RID()

    if working.is_valid():
        rd.free_rid(working)
        working = RID()

    if shader.is_valid():
        rd.free_rid(shader)
        shader = RID()

    pipeline = RID()

func initialize() -> void:
    rd = RenderingServer.get_rendering_device()

    if not rd:
        push_error("Failed to get a rendering device!")
        return

    var shader_file = load(_shader_path())
    var spirv: RDShaderSPIRV = shader_file.get_spirv()

    shader = rd.shader_create_from_spirv(spirv)
    pipeline = rd.compute_pipeline_create(shader)

    # Texture sampler
    var sampler_state: RDSamplerState = RDSamplerState.new()
    sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
    sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
    sampler = rd.sampler_create(sampler_state)

func setup_buffers(size: Vector2i) -> void:
    buffer_size = size

    if current.is_valid():
        rd.free_rid(current)
        current = RID()

    if working.is_valid():
        rd.free_rid(working)
        working = RID()

    var tf: RDTextureFormat = RDTextureFormat.new()
    tf.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
    tf.width = buffer_size.x
    tf.height = buffer_size.y

    tf.usage_bits = (
              RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
            # | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
            | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
            | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
    )

    current = rd.texture_create(tf, RDTextureView.new())
    working = rd.texture_create(tf, RDTextureView.new())

func blur(
        source: RID,
        size: Vector2i,
        passes: PackedFloat32Array,
        offset_multiplier: float,
        write_source_at_end: bool = false,
        list_to_use: Variant = null
) -> void:
    var inv_resolution: Vector2 = Vector2(1.0 / size.x, 1.0 / size.y)

    if not current.is_valid() or size != buffer_size:
        setup_buffers(size)

    if passes.is_empty():
        return

    var push_constants: PackedByteArray = []
    push_constants.resize(16) # inverse resolution, pass offset, multiplier
    push_constants.encode_float(0, inv_resolution.x)
    push_constants.encode_float(4, inv_resolution.y)
    push_constants.encode_float(12, offset_multiplier)

    var first: bool = true

    var compute_list: int
    if list_to_use != null:
        compute_list = list_to_use as int
    else:
        compute_list = rd.compute_list_begin()
    rd.compute_list_bind_compute_pipeline(compute_list, pipeline)

    for i in range(passes.size()):
        var source_texture: RDUniform = RDUniform.new()
        source_texture.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
        source_texture.binding = 0
        source_texture.add_id(sampler)

        if first:
            source_texture.add_id(source)
        else:
            source_texture.add_id(current)
            rd.compute_list_add_barrier(compute_list)

        var write_texture: RDUniform = RDUniform.new()
        write_texture.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
        write_texture.binding = 1

        if write_source_at_end and not first and i == passes.size() - 1:
            write_texture.add_id(source)
        else:
            write_texture.add_id(working)

        push_constants.encode_float(8, passes[i])

        rd.compute_list_bind_uniform_set(compute_list, UniformSetCacheRD.get_cache(shader, 0, [source_texture, write_texture]), 0)
        rd.compute_list_set_push_constant(compute_list, push_constants, push_constants.size())

        @warning_ignore('integer_division')
        rd.compute_list_dispatch(compute_list, (size.x - 1) / 8 + 1, (size.y - 1) / 8 + 1, 1)

        var tmp: RID = current
        current = working
        working = tmp

        first = false

    if list_to_use == null:
        rd.compute_list_end()
