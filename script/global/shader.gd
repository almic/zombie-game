@tool
extends Node


var world_time: float = 0.0


func _process(delta: float) -> void:

    if get_tree().paused:
        return

    # Only when game is running
    world_time += delta
    while (world_time > 3600):
        world_time -= 3600

    RenderingServer.global_shader_parameter_set(&'world_time', world_time)
