@tool
extends EditorPlugin

const Toolbar = preload("uid://c3rp8rh2rylb0")
const Gizmos = preload("uid://diallkouwe5cd")


var gizmos: Gizmos
var toolbar: Toolbar
var tool_mode: Toolbar.Tool = Toolbar.Tool.NONE
var edited_node: TerrainInstanceNode
var edited_region: TerrainInstanceRegion

var mouse_update_rate: int = 3
var mouse_position: Vector3
var mouse_position_tick: int = 0

var triangle_vertices: PackedInt32Array = []


func _enable_plugin():
    pass
    # add_autoload_singleton("GUIDE", "res://addons/guide/guide.gd")

func _enter_tree() -> void:
    toolbar = Toolbar.new()
    toolbar.visible = false
    add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, toolbar)

    if not toolbar.tool_selected.is_connected(on_tool_selected):
        toolbar.tool_selected.connect(on_tool_selected)

    gizmos = Gizmos.new()
    gizmos.plugin = self
    add_node_3d_gizmo_plugin(gizmos)
    # _main_panel = MainPanel.instantiate()
    # _main_panel.initialize(self)
    # EditorInterface.get_editor_main_screen().add_child(_main_panel)
    # Hide the main panel. Very much required.
    # _make_visible(false)

func _exit_tree() -> void:
    remove_node_3d_gizmo_plugin(gizmos)

    pass
    # if is_instance_valid(_main_panel):
    #     _main_panel.queue_free()
    # GUIDEInputFormatter.cleanup()

func _disable_plugin():
    pass
    # remove_autoload_singleton("GUIDE")

func _make_visible(visible: bool) -> void:
    toolbar.visible = visible

func _handles(object: Object) -> bool:
    return (
               object is TerrainInstanceNode
            or object is TerrainInstanceRegion
    )

func _edit(object: Object) -> void:
    if not object:
        if edited_node:
            edited_node.hide_gizmos()
        elif edited_region:
            edited_region.hide_gizmos()
        edited_node = null
        edited_region = null
        return

    if object == edited_node:
        if edited_region:
            edited_region = null
        edited_node.show_gizmos()
        return

    if object is TerrainInstanceNode:
        edited_node = object
        edited_node.show_gizmos()
    elif object is TerrainInstanceRegion:
        if edited_node:
            edited_node.hide_gizmos()
            edited_node = null

        if object.instance_node:
            edited_region = object
            edited_region.show_gizmos()
            edited_node = edited_region.instance_node
        else:
            EditorInterface.get_editor_toaster().push_toast(
                    'TerrainInstanceRegion selected has no owning TerrainInstanceNode!\n' +
                    'Please ensure the region has a parent node and select "Update Regions" ' +
                    'to edit this region.'
            )
    else:
        if edited_node:
            edited_node.hide_gizmos()
            edited_node = null
        if edited_region:
            edited_region.hide_gizmos()
            edited_region = null

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

        # Update marker position when in triangle mode
        if edited_region and tool_mode == Toolbar.Tool.ADD_TRIANGLE:
            edited_region.update_gizmos()

        return AFTER_GUI_INPUT_PASS

    if mouse == 0:
        return AFTER_GUI_INPUT_PASS

    if not edited_node.terrain:
        return AFTER_GUI_INPUT_PASS

    var terrain_point: Vector2 = edited_node.project_terrain(Vector2(mouse_position.x, mouse_position.z))

    if mouse == 1:
        var vertex: Vector2i = Vector2i(terrain_point.round())
        print('clicked at %s, vertex: %s' % [mouse_position, vertex])

        if tool_mode == Toolbar.Tool.ADD_TRIANGLE:
            var update: bool = false
            var existing: int = edited_region.get_vertex_id(vertex)
            if existing != -1:
                triangle_vertices.append(existing)
            else:
                triangle_vertices.append(edited_region.add_vertex(vertex, false))
                update = true

            if triangle_vertices.size() >= 3:
                triangle_vertices.resize(3)
                edited_region.add_face(triangle_vertices, false)
                triangle_vertices.clear()
                update = true

            if update:
                edited_region.update_gizmos()

        elif tool_mode == Toolbar.Tool.SELECT:
            # Allow gizmo selection
            return AFTER_GUI_INPUT_CUSTOM
        else:
            print('No tool selected!')

        return AFTER_GUI_INPUT_STOP


    return AFTER_GUI_INPUT_PASS

func on_tool_selected(tool: Toolbar.Tool) -> void:
    var previous_tool := tool_mode
    tool_mode = tool

    # Clear triangle list when selecting that tool
    if tool == Toolbar.Tool.ADD_TRIANGLE:
        triangle_vertices.clear()
    # Clear triangle marker when deselecting this tool
    elif edited_region and previous_tool == Toolbar.Tool.ADD_TRIANGLE:
        edited_region.update_gizmos()
