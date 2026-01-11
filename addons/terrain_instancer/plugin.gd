@tool
extends EditorPlugin

const Toolbar = preload("uid://c3rp8rh2rylb0")
const InstanceBar = preload("uid://btydstng0aghh")
const Gizmos = preload("uid://diallkouwe5cd")
const TerrainInstanceTemporary = preload("uid://dumv2y8oq3f1x")


var gizmos: Gizmos
var toolbar: Toolbar
var tool_mode: Toolbar.Tool = Toolbar.Tool.NONE
var instance_bar: InstanceBar
var edited_node: TerrainInstanceNode
var edited_region: TerrainInstanceRegion
var instance_preview: MeshInstance3D

var vp_camera: Camera3D
var vp_mouse_position: Vector2
var mouse_update_rate: int = 3
var mouse_position: Vector3
var mouse_position_tick: int = 0

var triangle_vertices: PackedInt32Array = []


func _enable_plugin():
    pass

func _enter_tree() -> void:
    toolbar = Toolbar.new()
    toolbar.plugin = self
    toolbar.visible = false
    add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, toolbar)

    instance_bar = InstanceBar.new()
    instance_bar.plugin = self
    instance_bar.visible = false
    add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_BOTTOM, instance_bar)

    if not toolbar.tool_selected.is_connected(on_tool_selected):
        toolbar.tool_selected.connect(on_tool_selected)

    gizmos = Gizmos.new()
    gizmos.plugin = self
    add_node_3d_gizmo_plugin(gizmos)

    ensure_instance_preview()

func _exit_tree() -> void:
    remove_node_3d_gizmo_plugin(gizmos)
    if instance_preview:
        instance_preview.queue_free()
        instance_preview = null

func _disable_plugin():
    pass

func _make_visible(visible: bool) -> void:
    toolbar.visible = visible
    if visible and tool_mode == Toolbar.Tool.ADD_INSTANCE and edited_region:
        instance_bar.region = edited_region
        instance_bar.visible = true
    else:
        instance_bar.region = null
        instance_bar.visible = false

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
        toolbar.update_visibility()
        instance_bar.region = null
        instance_bar.hide()
        if instance_preview:
            instance_preview.hide()
        return

    if object == edited_node:
        if edited_region:
            edited_region = null
        edited_node.show_gizmos()
        toolbar.update_visibility()
        instance_bar.region = null
        instance_bar.hide()
        if instance_preview:
            instance_preview.hide()
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

    toolbar.update_visibility()
    if edited_region and tool_mode == Toolbar.Tool.ADD_INSTANCE:
        instance_bar.region = edited_region
        instance_bar.show()

        ensure_instance_preview()

        var preview_parent: Node = instance_preview.get_parent()
        if preview_parent:
            preview_parent.remove_child(instance_preview)
        edited_region.add_child(instance_preview, false, Node.INTERNAL_MODE_FRONT)
    else:
        instance_bar.region = null
        instance_bar.hide()
        if instance_preview:
            instance_preview.hide()

func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> AfterGUIInput:
    if not edited_node:
        return AFTER_GUI_INPUT_PASS

    var mouse: int = 0
    var screen_pos: Vector2

    if event is InputEventMouseButton:
        if event.pressed:
            if event.button_index == MOUSE_BUTTON_LEFT:
                mouse = 1
            elif event.button_index == MOUSE_BUTTON_RIGHT:
                mouse = 2
            screen_pos = event.position
    elif event is InputEventMouseMotion:
        mouse_position_tick += 1
        if mouse_position_tick < mouse_update_rate:
            return AFTER_GUI_INPUT_PASS
        mouse_position_tick = 0

        # Update mouse position
        vp_camera = viewport_camera
        var viewport: SubViewport = vp_camera.get_parent()
        var mouse_pos: Vector2 = viewport.get_mouse_position()
        vp_mouse_position = mouse_pos
        if viewport.get_parent().stretch_shrink == 2:
            vp_mouse_position /= 2

        update_mouse_position()

        # Update marker position when in triangle mode
        if edited_region and tool_mode == Toolbar.Tool.ADD_TRIANGLE:
            edited_region.update_gizmos()

        # Update instance preview location
        if edited_region and tool_mode == Toolbar.Tool.ADD_INSTANCE:
            if not instance_preview:
                ensure_instance_preview()
                edited_region.add_child(instance_preview, false, Node.INTERNAL_MODE_FRONT)

            if mouse_position.is_finite():
                instance_preview.global_position = mouse_position
                if not instance_preview.visible:
                    instance_preview.visible = true
            elif instance_preview.visible:
                instance_preview.visible = false

        return AFTER_GUI_INPUT_PASS

    if mouse == 0:
        return AFTER_GUI_INPUT_PASS

    if not edited_node.terrain:
        return AFTER_GUI_INPUT_PASS

    var terrain_point: Vector2 = edited_node.project_terrain(Vector2(mouse_position.x, mouse_position.z))

    if mouse == 1:
        var vertex: Vector2i = Vector2i(terrain_point.round())

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

        elif tool_mode == Toolbar.Tool.SELECT_VERTEX:
            # Allow gizmo selection
            return AFTER_GUI_INPUT_CUSTOM

        elif tool_mode == Toolbar.Tool.REMOVE_VERTEX:
            if not edited_region:
                return AFTER_GUI_INPUT_PASS

            # Use gizmo handle selection to find clicked vertex
            var vertex_id: int = gizmos._handles_intersect_ray(
                    edited_region.get_gizmos()[0],
                    viewport_camera, vp_mouse_position
            )

            # allow deselection when not clicking a vertex
            if vertex_id == -1:
                return AFTER_GUI_INPUT_PASS

            edited_region.remove_vertex(vertex_id)
            edited_region.update_gizmos()

        elif tool_mode == Toolbar.Tool.REMOVE_TRIANGLE:
            if not edited_region:
                return AFTER_GUI_INPUT_PASS

            var face_idx: int = edited_region.pick_face(
                    viewport_camera.project_ray_origin(vp_mouse_position),
                    viewport_camera.project_ray_normal(vp_mouse_position)
            )

            # allow deselection when not clicking a face
            if face_idx == -1:
                return AFTER_GUI_INPUT_PASS

            edited_region.remove_face(face_idx)
            edited_region.update_gizmos()

        elif tool_mode == Toolbar.Tool.ADD_INSTANCE:
            if (not edited_region) or (not instance_bar.region):
                return AFTER_GUI_INPUT_PASS

            var t_instance := TerrainInstanceTemporary.new()
            t_instance.instance_id = 0
            t_instance.region = edited_region
            t_instance.name = 'TemporaryInstance'
            edited_region.add_child(t_instance, true)
            t_instance.owner = edited_region.owner
            t_instance.global_position = mouse_position

        elif tool_mode == Toolbar.Tool.EDIT_INSTANCE:
            if not edited_region:
                return AFTER_GUI_INPUT_PASS

            # NOTE: region handles full instance editing behavior
            if not edited_region.edit_instance(mouse_position):
                return AFTER_GUI_INPUT_PASS

        else:
            print('No tool selected!')

        return AFTER_GUI_INPUT_STOP


    return AFTER_GUI_INPUT_PASS

static func logs(message: String) -> void:
    print_rich('[color=light_slate_gray]TerrainInstancer : %s[/color]' % message)

func on_tool_selected(tool: Toolbar.Tool) -> void:
    var previous_tool := tool_mode
    tool_mode = tool

    # Clear triangle list when selecting that tool
    if tool == Toolbar.Tool.ADD_TRIANGLE:
        triangle_vertices.clear()
    # Clear triangle marker when deselecting this tool
    elif edited_region and previous_tool == Toolbar.Tool.ADD_TRIANGLE:
        edited_region.update_gizmos()

    ensure_instance_preview()

    if previous_tool == Toolbar.Tool.ADD_INSTANCE:
        instance_bar.hide()
        instance_preview.hide()
    if tool == Toolbar.Tool.ADD_INSTANCE:
        if edited_region:
            instance_bar.region = edited_region
            instance_bar.show()
            var preview_parent: Node = instance_preview.get_parent()
            if preview_parent != edited_region:
                if preview_parent:
                    preview_parent.remove_child(instance_preview)
                edited_region.add_child(instance_preview, false, Node.INTERNAL_MODE_FRONT)
            instance_preview.show()
            instance_preview.mesh = edited_region.instance_node.get_instance_lod_mesh(0)
        else:
            instance_bar.region = null
            instance_bar.hide()
            instance_preview.hide()

func update_mouse_position() -> void:
    var camera_pos: Vector3 = vp_camera.project_ray_origin(vp_mouse_position)
    var camera_dir: Vector3 = vp_camera.project_ray_normal(vp_mouse_position)

    mouse_position = edited_node.intersect_terrain(camera_pos, camera_dir)

func ensure_instance_preview() -> void:
    if instance_preview:
        return

    instance_preview = MeshInstance3D.new()
    instance_preview.top_level = true
