extends EditorNode3DGizmoPlugin

var SPHERE_MESH: SphereMesh = SphereMesh.new()
var SPHERE_MATERIAL: StandardMaterial3D = StandardMaterial3D.new()

func _init() -> void:
    SPHERE_MESH.height = 0.25
    SPHERE_MESH.radius = 0.125
    SPHERE_MESH.rings = 7
    SPHERE_MESH.radial_segments = 14

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

    var instance: TerrainInstanceNode = gizmo.get_node_3d() as TerrainInstanceNode
    if not instance:
        print_debug('no instance node!')
        return

    var region: TerrainInstanceRegion = instance.active_region
    if not region:
        return

    var transform: Transform3D = Transform3D()
    for vertex_id in region.get_vertex_count():
        transform.origin = instance.project_global(region.get_vertex(vertex_id))
        gizmo.add_mesh(SPHERE_MESH, SPHERE_MATERIAL, transform)
        print('put sphere at %s' % transform.origin)
