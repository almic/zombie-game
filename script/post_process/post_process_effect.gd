@tool

class_name PostProcessEffect
extends CompositorEffect


var rd: RenderingDevice

var shader: RID
var pipeline: RID


func _init():
    RenderingServer.call_on_render_thread(initialize_effect)

func _notification(what: int) -> void:
    if not what == NOTIFICATION_PREDELETE:
        return

    if shader.is_valid():
        rd.free_rid(shader)
        shader = RID()

    pipeline = RID()

func initialize_effect() -> void:
    rd = RenderingServer.get_rendering_device()
    if not rd:
        push_error("Failed to get a rendering device!")
        return

    _create_shader()

## Implement per effect to return the desired shader file path
func _shader_path() -> StringName:
    return &""

## Implement per effect to initialize resources on the render device
func _create_shader() -> void:
    var shader_file = load(_shader_path())
    var spirv: RDShaderSPIRV = shader_file.get_spirv()

    shader = rd.shader_create_from_spirv(spirv)
    pipeline = rd.compute_pipeline_create(shader)
