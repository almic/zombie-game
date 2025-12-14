@tool
extends EditorPlugin


var edited_node: TerrainInstanceNode

var mouse_update_rate: int = 3
var mouse_position: Vector3
var mouse_position_tick: int = 0


func _enable_plugin():
    pass
    # add_autoload_singleton("GUIDE", "res://addons/guide/guide.gd")

func _enter_tree() -> void:
    pass
    # _main_panel = MainPanel.instantiate()
    # _main_panel.initialize(self)
    # EditorInterface.get_editor_main_screen().add_child(_main_panel)
    # Hide the main panel. Very much required.
    # _make_visible(false)

func _exit_tree() -> void:
    pass
    # if is_instance_valid(_main_panel):
    #     _main_panel.queue_free()
    # GUIDEInputFormatter.cleanup()

func _disable_plugin():
    pass
    # remove_autoload_singleton("GUIDE")

func _handles(object: Object) -> bool:
    return object is TerrainInstanceNode

func _edit(object: Object) -> void:
    if not object:
        edited_node = null
        return

    if object == edited_node:
        return

    if object is TerrainInstanceNode:
        edited_node = object
    else:
        edited_node = null

func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> AfterGUIInput:
    if not edited_node:
        return AFTER_GUI_INPUT_PASS

    var mouse: int = 0
    if event is InputEventMouseButton:
        if event.pressed:
            if event.button_index == MOUSE_BUTTON_LEFT:
                mouse = 1
            elif event.button_index == MOUSE_BUTTON_RIGHT:
                mouse = 2
    elif event is InputEventMouseMotion:
        mouse_position_tick += 1
        if mouse_position_tick < mouse_update_rate:
            return AFTER_GUI_INPUT_PASS
        mouse_position_tick = 0

        # Update mouse position
        var viewport: SubViewport = viewport_camera.get_parent()
        var vp_mouse_pos: Vector2 = viewport.get_mouse_position()
        var mouse_pos: Vector2 = vp_mouse_pos
        if viewport.get_parent().stretch_shrink == 2:
            vp_mouse_pos /= 2
        var camera_pos: Vector3 = viewport_camera.project_ray_origin(mouse_pos)
        var camera_dir: Vector3 = viewport_camera.project_ray_normal(mouse_pos)

        mouse_position = edited_node.intersect_terrain(camera_pos, camera_dir)
        return AFTER_GUI_INPUT_PASS

    if mouse == 0:
        return AFTER_GUI_INPUT_PASS

    if not edited_node.terrain:
        return AFTER_GUI_INPUT_PASS

    # Add vertex
    if mouse == 1 and edited_node.active_region:
        var vertex: Vector2i = Vector2i(
                edited_node.project_terrain(
                    Vector2(mouse_position.x, mouse_position.z)
                ).round()
        )
        edited_node.active_region.add_vertex(vertex)
        print('clicked at %s, vertex: %s' % [mouse_position, vertex])
        return AFTER_GUI_INPUT_STOP

    return AFTER_GUI_INPUT_PASS
