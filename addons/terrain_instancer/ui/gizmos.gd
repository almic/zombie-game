extends EditorNode3DGizmoPlugin

const Plugin = preload("uid://khsyydwj7rw2")
const Toolbar = preload("uid://c3rp8rh2rylb0")


var SPHERE_MESH: SphereMesh
var SPHERE_COLLISION: TriangleMesh
var SPHERE_MATERIAL: StandardMaterial3D
var SPHERE_EDITING_MATERIAL: StandardMaterial3D
var SPHERE_FADED_MATERIAL: StandardMaterial3D
var SURFACE_MATERIAL: StandardMaterial3D
var SURFACE_FADED_MATERIAL: StandardMaterial3D
var PATH_MATERIAL: StandardMaterial3D
var PATH_FADED_MATERIAL: StandardMaterial3D


var plugin: Plugin
var last_mouse_update_rate: int = -1
var edited_handle: Dictionary

func _init() -> void:
    SPHERE_MESH = SphereMesh.new()
    SPHERE_MESH.height = 0.7
    SPHERE_MESH.radius = 0.35
    SPHERE_MESH.rings = 7
    SPHERE_MESH.radial_segments = 14

    SPHERE_COLLISION = SPHERE_MESH.generate_triangle_mesh()

    var priority: int = BaseMaterial3D.RENDER_PRIORITY_MAX - 10

    SPHERE_MATERIAL = StandardMaterial3D.new()
    SPHERE_MATERIAL.set_flag(BaseMaterial3D.FLAG_DISABLE_DEPTH_TEST, true)
    SPHERE_MATERIAL.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    SPHERE_MATERIAL.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    SPHERE_MATERIAL.albedo_color = Color(1.0, 0.6, 1.0, 0.12)
    SPHERE_MATERIAL.render_priority = priority + 1

    SPHERE_EDITING_MATERIAL = SPHERE_MATERIAL.duplicate(true)
    SPHERE_EDITING_MATERIAL.albedo_color = Color(0.5, 0.8, 1.0, 0.08)
    SPHERE_EDITING_MATERIAL.render_priority = priority + 2

    SPHERE_FADED_MATERIAL = SPHERE_MATERIAL.duplicate(true)
    SPHERE_FADED_MATERIAL.albedo_color = Color(0.6, 0.6, 0.6, 0.08)
    SPHERE_FADED_MATERIAL.render_priority = priority - 2

    SURFACE_MATERIAL = SPHERE_MATERIAL.duplicate(true)
    SURFACE_MATERIAL.albedo_color = Color(0.5, 0.8, 1.0, 0.08)
    SURFACE_MATERIAL.render_priority = priority

    SURFACE_FADED_MATERIAL = SURFACE_MATERIAL.duplicate(true)
    SURFACE_FADED_MATERIAL.albedo_color = SURFACE_MATERIAL.albedo_color.lightened(0.1)
    SURFACE_FADED_MATERIAL.albedo_color.a *= 0.5
    SURFACE_FADED_MATERIAL.render_priority = priority - 3

    PATH_MATERIAL = SURFACE_MATERIAL.duplicate(true)
    PATH_MATERIAL.albedo_color = Color(0.9, 0.0, 0.0, 1.0)
    PATH_MATERIAL.render_priority = priority + 3

    PATH_FADED_MATERIAL = PATH_MATERIAL.duplicate(true)
    PATH_FADED_MATERIAL.albedo_color = PATH_MATERIAL.albedo_color.lightened(0.1)
    PATH_FADED_MATERIAL.albedo_color.a *= 0.5
    PATH_FADED_MATERIAL.render_priority = priority - 1

func _get_gizmo_name() -> String:
    return 'Terrain Instance Region'

func _has_gizmo(for_node_3d: Node3D) -> bool:
    return for_node_3d is TerrainInstanceRegion

func _redraw(gizmo: EditorNode3DGizmo) -> void:
    gizmo.clear()

    var region: TerrainInstanceRegion = gizmo.get_node_3d() as TerrainInstanceRegion
    if not region:
        push_error('No region!')
        return

    if not region._show_gizmo:
        return

    var instance: TerrainInstanceNode = region.instance_node
    if not instance:
        return

    region.update_shapes()

    for polygon in region.shapes:
        if polygon.mesh.get_surface_count() < 1:
            continue

        # Wireframe
        var size: int = polygon.triangle_mesh_faces.size()
        var i: int = 0
        while i < size:

            gizmo.add_lines(
                [
                    polygon.triangle_mesh_faces[i],
                    polygon.triangle_mesh_faces[i + 1],

                    polygon.triangle_mesh_faces[i],
                    polygon.triangle_mesh_faces[i + 2],

                    polygon.triangle_mesh_faces[i + 1],
                    polygon.triangle_mesh_faces[i + 2]
                ], SURFACE_MATERIAL)
            i += 3

        # Filling
        gizmo.add_mesh(polygon.mesh, SURFACE_MATERIAL)

    # Path
    for polygon in region.shapes:
        if polygon.world_vertices.size() < 2:
            continue

        var path_mat: StandardMaterial3D = PATH_MATERIAL
        if region._last_shape and polygon != region._last_shape:
            path_mat = PATH_FADED_MATERIAL
        var size: int = polygon.world_vertices.size()
        var i: int = 0
        while i < size - 1:
            var a: Vector3 = polygon.world_vertices[i]
            var b: Vector3 = polygon.world_vertices[i + 1]
            gizmo.add_lines([a, b], path_mat)
            i += 1

    var transform: Transform3D = Transform3D()

    # Show blue marker to nearest terrain vertex when adding vertices
    if (not edited_handle) and plugin.tool_mode == Plugin.Toolbar.Tool.ADD_VERTEX:
        var terrain_point: Vector2 = instance.project_terrain(
                Vector2(
                    plugin.mouse_position.x,
                    plugin.mouse_position.z
                )
        )
        var global_point: Vector3 = instance.project_global(terrain_point.round())
        if global_point.is_finite():
            transform.origin = global_point
            gizmo.add_mesh(SPHERE_MESH, SPHERE_EDITING_MATERIAL, transform)

    if region._last_shape:
        var index: int = 0
        for vertex in region._last_shape.world_vertices:
            transform.origin = vertex

            if edited_handle and edited_handle.id == index:
                gizmo.add_mesh(SPHERE_MESH, SPHERE_EDITING_MATERIAL, transform)
                transform.origin = plugin.mouse_position
                gizmo.add_mesh(SPHERE_MESH, SPHERE_MATERIAL, transform)
            else:
                gizmo.add_mesh(SPHERE_MESH, SPHERE_MATERIAL, transform)
            index += 1

    var sphere_mat: StandardMaterial3D = SPHERE_MATERIAL
    if region._last_shape and region._solo_shape:
        sphere_mat = SPHERE_FADED_MATERIAL

    for polygon in region.shapes:
        if polygon == region._last_shape:
            continue

        for vertex in polygon.world_vertices:
            transform.origin = vertex
            gizmo.add_mesh(SPHERE_MESH, sphere_mat, transform)

func _handles_intersect_ray(gizmo: EditorNode3DGizmo, camera: Camera3D, screen_pos: Vector2) -> int:
    var region: TerrainInstanceRegion = gizmo.get_node_3d() as TerrainInstanceRegion
    if not region:
        return -1

    var instance: TerrainInstanceNode = region.instance_node
    if not instance:
        return -1

    var affine: Transform3D = instance.terrain.global_transform.affine_inverse()
    var ray_from: Vector3 = affine * camera.project_ray_origin(screen_pos)
    var ray_dir: Vector3 = (affine.basis * camera.project_ray_normal(screen_pos)).normalized()

    if region._last_shape:
        var index: int = 0
        for vertex in region._last_shape.world_vertices:
            if SPHERE_COLLISION.intersect_ray(ray_from - vertex, ray_dir):
                return index
            index += 1

    if region._solo_shape:
        return -1

    for polygon in region.shapes:
        var index: int = 0
        for vertex in polygon.world_vertices:
            if SPHERE_COLLISION.intersect_ray(ray_from - vertex, ray_dir):
                region._last_shape = polygon
                return index
            index += 1

    return -1

func _get_handle_name(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> String:
    return 'Vertex %d' % handle_id

func _get_handle_value(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> Variant:
    var region: TerrainInstanceRegion = gizmo.get_node_3d() as TerrainInstanceRegion
    if not region:
        print_debug('no region!')
        return null

    if not region._last_shape:
        print_debug('region has no last shape!')
        return null

    var world_vert: Vector3 = region._last_shape.world_vertices[handle_id]
    return Vector2i(world_vert.x, world_vert.z)

func _begin_handle_action(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> void:
    var region: TerrainInstanceRegion = gizmo.get_node_3d() as TerrainInstanceRegion
    if not region:
        print_debug('no region!')
        return

    var position: Vector2i = _get_handle_value(gizmo, handle_id, secondary)
    edited_handle = {
        id = handle_id,
        region = region,
        current_pos = position,
        initial_pos = position
    }
    last_mouse_update_rate = plugin.mouse_update_rate
    plugin.mouse_update_rate = 2

func _set_handle(
        gizmo: EditorNode3DGizmo,
        handle_id: int,
        secondary: bool,
        camera: Camera3D,
        screen_pos: Vector2
) -> void:
    if not edited_handle:
        return

    if edited_handle.get('id') != handle_id:
        edited_handle.clear()
        return

    var region: TerrainInstanceRegion = edited_handle.region as TerrainInstanceRegion
    if (not region) or (not region._last_shape):
        edited_handle.clear()
        return

    var terrain_point: Vector2 = region.instance_node.project_terrain(
            Vector2(
                plugin.mouse_position.x,
                plugin.mouse_position.z
            )
    )

    edited_handle.current_pos = Vector2i(terrain_point.round())
    region.set_vertex(edited_handle.id, edited_handle.current_pos)
    region.update_gizmos()

func _commit_handle(
        gizmo: EditorNode3DGizmo,
        handle_id: int,
        secondary: bool,
        restore: Variant,
        cancel: bool
) -> void:
    if last_mouse_update_rate != -1:
        plugin.mouse_update_rate = last_mouse_update_rate
        last_mouse_update_rate = -1

    if not edited_handle:
        return

    if edited_handle.get('id') != handle_id:
        edited_handle.clear()
        return

    var region: TerrainInstanceRegion = edited_handle.region as TerrainInstanceRegion
    if not region:
        edited_handle.clear()
        return

    if cancel:
        region.set_vertex(edited_handle.id, edited_handle.initial_pos)
        edited_handle.clear()
        return

    region.set_vertex(edited_handle.id, edited_handle.current_pos)
    edited_handle.clear()
