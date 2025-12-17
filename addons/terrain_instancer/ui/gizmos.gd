extends EditorNode3DGizmoPlugin

const Plugin = preload("uid://khsyydwj7rw2")


var SPHERE_MESH: SphereMesh
var SPHERE_COLLISION: TriangleMesh
var SPHERE_MATERIAL: StandardMaterial3D


var plugin: Plugin
var last_mouse_update_rate: int = -1
var edited_handle: Dictionary

var cached_collision_meshes: Array[TriangleMesh]

func _init() -> void:
    SPHERE_MESH = SphereMesh.new()
    SPHERE_MESH.height = 0.25
    SPHERE_MESH.radius = 0.125
    SPHERE_MESH.rings = 7
    SPHERE_MESH.radial_segments = 14

    SPHERE_COLLISION = SPHERE_MESH.generate_triangle_mesh()

    SPHERE_MATERIAL = StandardMaterial3D.new()
    SPHERE_MATERIAL.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    SPHERE_MATERIAL.disable_fog = true
    SPHERE_MATERIAL.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    SPHERE_MATERIAL.stencil_mode = BaseMaterial3D.STENCIL_MODE_OUTLINE
    SPHERE_MATERIAL.albedo_color = Color(1.0, 0.5, 1.0, 0.08)
    SPHERE_MATERIAL.stencil_color = Color(0.4, 0.05, 0.35, 0.8)

func _get_gizmo_name() -> String:
    return 'Terrain Instance Region'

func _has_gizmo(for_node_3d: Node3D) -> bool:
    return for_node_3d is TerrainInstanceNode

func _redraw(gizmo: EditorNode3DGizmo) -> void:
    gizmo.clear()
    cached_collision_meshes.clear()

    var instance: TerrainInstanceNode = gizmo.get_node_3d() as TerrainInstanceNode
    if not instance:
        print_debug('no instance node!')
        return

    var region: TerrainInstanceRegion = instance.active_region
    if not region:
        return

    cached_collision_meshes.resize(region.get_vertex_count())

    var transform: Transform3D = Transform3D()
    for vertex_id in region.get_vertex_count():
        transform.origin = instance.project_global(region.get_vertex(vertex_id))
        gizmo.add_mesh(SPHERE_MESH, SPHERE_MATERIAL, transform)

        # Set up collision mesh
        var collision_mesh: TriangleMesh = TriangleMesh.new()
        var collision_faces: PackedVector3Array = SPHERE_COLLISION.get_faces()
        for v in range(collision_faces.size()):
            collision_faces[v] += transform.origin
        collision_mesh.create_from_faces(collision_faces)

        cached_collision_meshes[vertex_id] = collision_mesh
        gizmo.add_collision_triangles(collision_mesh)

        #print('put sphere at %s' % transform.origin)

func _handles_intersect_ray(gizmo: EditorNode3DGizmo, camera: Camera3D, screen_pos: Vector2) -> int:
    var instance: TerrainInstanceNode = gizmo.get_node_3d() as TerrainInstanceNode
    if not instance:
        return -1

    var region: TerrainInstanceRegion = instance.active_region
    if not region:
        return -1

    var affine: Transform3D = instance.global_transform.affine_inverse()
    var ray_from: Vector3 = affine * camera.project_ray_origin(screen_pos)
    var ray_dir: Vector3 = (affine.basis * camera.project_ray_normal(screen_pos)).normalized()

    for vertex_id in region.get_vertex_count():
        var collision_mesh: TriangleMesh = cached_collision_meshes[vertex_id]
        if collision_mesh.intersect_ray(ray_from, ray_dir):
            return vertex_id

    return -1

func _get_handle_name(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> String:
    return 'Vertex %d' % handle_id

func _get_handle_value(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> Variant:
    var instance: TerrainInstanceNode = gizmo.get_node_3d() as TerrainInstanceNode
    if not instance:
        print_debug('no instance node!')
        return null

    var region: TerrainInstanceRegion = instance.active_region
    if not region:
        return null

    return region.get_vertex(handle_id)

func _begin_handle_action(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> void:
    print('start editing vertex %d' % handle_id)
    var instance: TerrainInstanceNode = gizmo.get_node_3d() as TerrainInstanceNode
    if not instance:
        print_debug('no instance node!')
        return

    var region: TerrainInstanceRegion = instance.active_region
    if not region:
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
    if not region:
        edited_handle.clear()
        return

    var terrain_point: Vector2 = region.instance_node.project_terrain(
            Vector2(
                plugin.mouse_position.x,
                plugin.mouse_position.z
            )
    )

    print('updating vertex %d' % handle_id)
    edited_handle.current_pos = Vector2i(terrain_point.round())
    region.set_vertex(edited_handle.id, edited_handle.current_pos)
    region.instance_node.update_gizmos()

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
        print('canceled handle %d' % handle_id)
        region.set_vertex(edited_handle.id, edited_handle.initial_pos)
        edited_handle.clear()
        return

    print('commiting handle %d' % handle_id)
    region.set_vertex(edited_handle.id, edited_handle.current_pos)
    edited_handle.clear()
