extends Camera3D

@export var enable: bool = false

var path_start_position: Vector3 = Vector3.ZERO

func _ready() -> void:
    if not enable:
        queue_free()
        %DebugPaths.queue_free()


func _process(_delta: float) -> void:
    if not enable:
        return

    make_current()
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

    var mouse_cursor_position: Vector2 = get_viewport().get_mouse_position()

    var map: RID = get_world_3d().navigation_map
    # Do not query when the map has never synchronized and is empty.
    if NavigationServer3D.map_get_iteration_id(map) == 0:
        return

    var camera: Camera3D = get_viewport().get_camera_3d()
    var camera_ray_length: float = 1000.0
    var camera_ray_start: Vector3 = camera.project_ray_origin(mouse_cursor_position)
    var camera_ray_end: Vector3 = camera_ray_start + camera.project_ray_normal(mouse_cursor_position) * camera_ray_length
    var closest_point_on_navmesh: Vector3 = NavigationServer3D.map_get_closest_point_to_segment(
        map,
        camera_ray_start,
        camera_ray_end
    )

    if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        for player in get_tree().root.find_children("", "Player"):
            if player is Player:
                player.global_position = closest_point_on_navmesh
        path_start_position = closest_point_on_navmesh

    %DebugPaths.global_position = path_start_position

    %PathDebugCorridorFunnel.target_position = closest_point_on_navmesh
    %PathDebugEdgeCentered.target_position = closest_point_on_navmesh
    %PathDebugNoPostProcessing.target_position = closest_point_on_navmesh

    %PathDebugCorridorFunnel.get_next_path_position()
    %PathDebugEdgeCentered.get_next_path_position()
    %PathDebugNoPostProcessing.get_next_path_position()
