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
var instance_preview: TerrainInstanceTemporary

var vp_camera: Camera3D
var vp_mouse_position: Vector2
var mouse_update_rate: int = 3
var mouse_position: Vector3
var mouse_position_tick: int = 0


func _enable_plugin():
    pass

func _enter_tree() -> void:
    toolbar = Toolbar.new()
    toolbar.plugin = self
    toolbar.visible = false
    add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, toolbar)

    instance_bar = InstanceBar.new()
    instance_bar.plugin = self
    instance_bar.hide()
    add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_BOTTOM, instance_bar)

    instance_preview = TerrainInstanceTemporary.new()

    if not toolbar.tool_selected.is_connected(on_tool_selected):
        toolbar.tool_selected.connect(on_tool_selected)

    gizmos = Gizmos.new()
    gizmos.plugin = self
    add_node_3d_gizmo_plugin(gizmos)

func _exit_tree() -> void:
    remove_node_3d_gizmo_plugin(gizmos)
    if instance_preview:
        instance_preview.queue_free()

func _disable_plugin():
    pass

func _make_visible(visible: bool) -> void:
    toolbar.visible = visible
    if visible and tool_mode == Toolbar.Tool.ADD_INSTANCE and edited_region:
        instance_bar.show()
        instance_preview.show()
    else:
        instance_bar.hide()
        instance_preview.hide()

func _handles(object: Object) -> bool:
    return (
               object is TerrainInstanceNode
            or object is TerrainInstanceRegion
            or object is TerrainRegionPolygon
    )

func _edit(object: Object) -> void:
    if not object:
        if edited_node:
            edited_node.hide_gizmos()
            edited_node = null

        if edited_region:
            edited_region.hide_gizmos()
            edited_region = null
            instance_bar.region = null
            instance_bar.hide()
            remove_preview_instance()

        toolbar.update_visibility()
        return

    if edited_node and object != edited_node:
        edited_node.hide_gizmos()
        edited_node = null

    if edited_region and object != edited_region:
        edited_region.hide_gizmos()
        edited_region._last_shape = null
        edited_region._solo_shape = false
        edited_region = null
        instance_bar.region = null
        instance_bar.hide()
        remove_preview_instance()

    if object is TerrainInstanceNode:
        edited_node = object
        edited_node.show_gizmos()

    elif object is TerrainInstanceRegion:
        if object.instance_node:
            edited_region = object
            edited_region._last_shape = null
            edited_region._solo_shape = false
            edited_region.show_gizmos()
            edited_node = edited_region.instance_node
            set_preview_region(edited_region)
        else:
            EditorInterface.get_editor_toaster().push_toast(
                    'TerrainInstanceRegion selected has no owning TerrainInstanceNode!\n' +
                    'Please ensure the region has a parent node and select "Update Regions" ' +
                    'to edit this region.'
            )

    elif object is TerrainRegionPolygon:
        var region: TerrainInstanceRegion = object.get_parent() as TerrainInstanceRegion
        if region and region.instance_node:
            edited_region = region
            edited_region._last_shape = object
            edited_region._solo_shape = true
            edited_region.show_gizmos()
            edited_node = edited_region.instance_node
            set_preview_region(edited_region)
        else:
            EditorInterface.get_editor_toaster().push_toast(
                    'TerrainRegionPolygon selected has no direct TerrainInstanceRegion parent!\n' +
                    'Please move the polygon to be a direct child of a TerrainInstanceRegion, nested ' +
                    'children are not supported. Use additional regions if you need more scene organization.'
            )

    toolbar.update_visibility()

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

        if edited_region:
            # Update marker position when in add mode
            if tool_mode == Toolbar.Tool.ADD_VERTEX:
                edited_region.update_gizmos()

            # Update instance preview location
            elif tool_mode == Toolbar.Tool.ADD_INSTANCE:
                if mouse_position.is_finite():
                    instance_preview.instance_position = mouse_position

        return AFTER_GUI_INPUT_PASS

    if mouse == 0:
        return AFTER_GUI_INPUT_PASS

    if not edited_node.terrain:
        return AFTER_GUI_INPUT_PASS

    var terrain_point: Vector2 = edited_node.project_terrain(Vector2(mouse_position.x, mouse_position.z))

    if mouse == 1:
        var vertex: Vector2i = Vector2i(terrain_point.round())

        if tool_mode == Toolbar.Tool.ADD_VERTEX:
            if not edited_region:
                return AFTER_GUI_INPUT_PASS

            # Test if we selected a vertex gizmo
            var vertex_id: int = gizmos._handles_intersect_ray(
                    edited_region.get_gizmos()[0],
                    viewport_camera,
                    screen_pos
            )
            if vertex_id != -1:
                # Allow ALT + Click to delete vertex
                if Input.is_physical_key_pressed(KEY_ALT):
                    edited_region.remove_vertex(vertex_id)
                    edited_region.update_gizmos()
                    return AFTER_GUI_INPUT_STOP
                return AFTER_GUI_INPUT_CUSTOM

            if Input.is_physical_key_pressed(KEY_SHIFT):
                add_vertex_new_shape(vertex)
                return AFTER_GUI_INPUT_CUSTOM

            if not edited_region._last_shape:
                if edited_region.shapes.size() == 0:
                    add_vertex_new_shape(vertex)
                    return AFTER_GUI_INPUT_CUSTOM

                # Test existing vertices against "placed" vertex and select that shape
                for polygon in edited_region.shapes:
                    var size: int = polygon.count()
                    var i: int = 0
                    while i < size:
                        if vertex == polygon.get_vertex(i):
                            edited_region._last_shape = polygon
                            return AFTER_GUI_INPUT_STOP
                        i += 1

                if insert_vertex(viewport_camera, screen_pos, vertex, edited_region.shapes):
                    return AFTER_GUI_INPUT_CUSTOM

                return AFTER_GUI_INPUT_STOP

            if edited_region.has_vertex(vertex, true):
                EditorInterface.get_editor_toaster().push_toast(
                        'Vertex %s already exists on the selected polygon' % vertex,
                        EditorToaster.SEVERITY_ERROR
                )
                return AFTER_GUI_INPUT_STOP

            if insert_vertex(viewport_camera, screen_pos, vertex, [edited_region._last_shape]):
                return AFTER_GUI_INPUT_CUSTOM

            # Append to shape if it fails
            if edited_region.add_vertex(vertex):
                edited_region.update_shapes()
                gizmos.force_next_edit = edited_region._last_shape.count() - 1
                return AFTER_GUI_INPUT_CUSTOM

            return AFTER_GUI_INPUT_STOP

        elif tool_mode == Toolbar.Tool.SELECT_VERTEX:
            # Allow gizmo selection
            return AFTER_GUI_INPUT_CUSTOM

        elif tool_mode == Toolbar.Tool.REMOVE_VERTEX:
            if not edited_region:
                return AFTER_GUI_INPUT_PASS

            # Use gizmo handle selection to find clicked vertex
            var vertex_id: int = gizmos._handles_intersect_ray(
                    edited_region.get_gizmos()[0],
                    viewport_camera,
                    screen_pos
            )

            if vertex_id != -1:
                edited_region.remove_vertex(vertex_id)
                edited_region.update_shapes()
                edited_region.update_gizmos()

            # do not deselect when missing a vertex

        elif tool_mode == Toolbar.Tool.ADD_INSTANCE:
            if not edited_node:
                return AFTER_GUI_INPUT_PASS

            # TASK: Make it so one click can "lock" the position of the instance
            #       and allow randomizing/ tweaking while in place.

            var inst_data: Dictionary
            var xform: Array[Transform3D] = [instance_preview.global_transform]
            var color: PackedColorArray = [instance_preview.instance_color.srgb_to_linear()]
            inst_data.set(instance_preview.instance_id, {&'xforms': xform, &'colors': color})

            edited_node.add_instances(inst_data)
            instance_bar.randomize_instance()

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

    # Clear vertex marker when deselecting this tool
    if edited_region and previous_tool == Toolbar.Tool.ADD_VERTEX:
        edited_region.update_gizmos()

    if previous_tool == Toolbar.Tool.ADD_INSTANCE:
        instance_bar.hide()
        instance_preview.hide()
    if tool == Toolbar.Tool.ADD_INSTANCE:
        instance_bar.show()
        instance_preview.show()

func insert_vertex(
        viewport_camera: Camera3D,
        screen_pos: Vector2,
        vertex: Vector2i,
        shapes: Array[TerrainRegionPolygon]
) -> bool:
    # Test edges for inserting the vertex
    const EDGE_DISTANCE: float = 8.0
    const EDGE_DIST_SQ: float = EDGE_DISTANCE * EDGE_DISTANCE
    var nearest_edge: float = INF
    var nearest_insertion: int = -1

    for polygon in shapes:
        var size: int = polygon.count()
        if size < 2:
            continue

        var i: int = 0
        size -= 1 # checking [i, i + 1] segments

        var a: Vector2 = viewport_camera.unproject_position(polygon.world_vertices[i])
        while i < size:
            var b: Vector2 = viewport_camera.unproject_position(polygon.world_vertices[i + 1])

            var dist_sq: float = screen_pos.distance_squared_to(Geometry2D.get_closest_point_to_segment(screen_pos, a, b))
            if dist_sq <= EDGE_DIST_SQ and dist_sq < nearest_edge:
                edited_region._last_shape = polygon
                nearest_edge = dist_sq
                nearest_insertion = i + 1

            # Next segment
            a = b
            i += 1

    if nearest_insertion == -1:
        return false

    if edited_region.add_vertex(vertex, nearest_insertion):
        edited_region.update_shapes()
        gizmos.force_next_edit = nearest_insertion
        edited_region.update_gizmos()
        return true

    return false

func add_vertex_new_shape(vertex: Vector2i) -> void:
    var new_shape: TerrainRegionPolygon = TerrainRegionPolygon.new()
    new_shape.name = &'RegionPolygon'
    new_shape.set_meta(
            &'_custom_type_script',
            ResourceUID.id_to_text(ResourceLoader.get_resource_uid(new_shape.get_script().get_path()))
    )
    edited_region.add_child(new_shape, true)
    new_shape.owner = edited_region.owner
    edited_region._last_shape = new_shape
    edited_region.add_vertex(vertex)
    edited_region.update_shapes()
    gizmos.force_next_edit = 0
    edited_region.update_gizmos()

func update_mouse_position() -> void:
    var camera_pos: Vector3 = vp_camera.project_ray_origin(vp_mouse_position)
    var camera_dir: Vector3 = vp_camera.project_ray_normal(vp_mouse_position)

    mouse_position = edited_node.intersect_terrain(camera_pos, camera_dir)

## Remove the instance preview from the scene and hide it
func remove_preview_instance() -> void:
    if not instance_preview:
        return

    instance_preview.visible = false
    instance_preview.region = null
    instance_preview.instance_id = -1

    var preview_parent: Node = instance_preview.get_parent()
    if preview_parent:
        preview_parent.remove_child(instance_preview)

## Reparents the instance preview and updates the instance bar
func set_preview_region(region: TerrainInstanceRegion) -> void:
    # Set region to null before clearing the instance ID
    instance_preview.region = null
    instance_preview.instance_id = -1
    instance_preview.region = region

    var preview_parent: Node = instance_preview.get_parent()
    if preview_parent:
        preview_parent.remove_child(instance_preview)
    region.add_child(instance_preview, false, Node.INTERNAL_MODE_FRONT)

    instance_bar.region = region
    if tool_mode == Toolbar.Tool.ADD_INSTANCE:
        instance_bar.show()
        instance_preview.show()
