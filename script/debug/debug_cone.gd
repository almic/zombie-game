class_name DebugCone extends MeshInstance3D


func _init(length: float, radius: float, color: Color = Color(0.1, 0.9, 0.1, 0.5)) -> void:
    mesh = CylinderMesh.new()
    cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var mat: StandardMaterial3D = StandardMaterial3D.new()
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.disable_receive_shadows = true
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mesh.material = mat
    set_size(length, radius)
    set_color(color)

static func create(node: Node, xform: Transform3D, ttl: float, length: float, radius: float) -> void:
    _add_to_node(node, xform, ttl, DebugCone.new(length, radius))

static func create_color(node: Node, xform: Transform3D, ttl: float, length: float, radius: float, color: Color) -> void:
    _add_to_node(node, xform, ttl, DebugCone.new(length, radius, color))

static func create_fov(node: Node, xform: Transform3D, ttl: float, fov: float, distance: float) -> void:
    var cone_xform := _make_cone_fov_xform(xform, distance)
    _add_to_node(node, cone_xform, ttl, DebugCone.new(distance, distance * tan(fov * 0.5)))

static func create_fov_color(node: Node, xform: Transform3D, ttl: float, fov: float, distance: float, color: Color) -> void:
    var cone_xform := _make_cone_fov_xform(xform, distance)
    _add_to_node(node, cone_xform, ttl, DebugCone.new(distance, distance * tan(fov * 0.5), color))

static func _make_cone_fov_xform(xform: Transform3D, size: float) -> Transform3D:
    var cone_xform: Transform3D = Transform3D.IDENTITY
    cone_xform = cone_xform.rotated_local(Vector3.RIGHT, -PI / 2)
    cone_xform = cone_xform.translated_local(Vector3.UP * size * 0.5)
    return xform * cone_xform

static func _add_to_node(node: Node, xform: Transform3D, ttl: float, cone: DebugCone) -> void:
    var scene: Node = node.get_tree().current_scene
    scene.add_child(cone)
    cone.global_transform = xform
    scene.get_tree().create_timer(ttl, false, true).timeout.connect(cone.queue_free)

func set_color(color: Color) -> void:
    var mat: StandardMaterial3D = mesh.surface_get_material(0) as StandardMaterial3D
    if not mat:
        return

    mat.albedo_color = color

func set_size(length: float, radius: float) -> void:
    var cylinder: CylinderMesh = mesh as CylinderMesh
    if not cylinder:
        return

    cylinder.bottom_radius = 0.0
    cylinder.top_radius = radius
    cylinder.height = length

func set_fov(distance: float, fov: float) -> void:
    set_size(distance, distance * tan(fov * 0.5))

    transform = Transform3D.IDENTITY
    transform = transform.rotated_local(Vector3.RIGHT, -PI / 2)
    transform = transform.translated_local(Vector3.UP * distance * 0.5)
