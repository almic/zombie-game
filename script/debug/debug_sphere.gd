class_name DebugSphere extends MeshInstance3D


func _init(radius: float, color: Color = Color(0.1, 0.9, 0.1, 0.5), draw_inside: bool = false) -> void:
    mesh = SphereMesh.new()
    var mat: StandardMaterial3D = StandardMaterial3D.new()
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    if draw_inside:
        mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mesh.material = mat
    set_radius(radius)
    set_color(color)

static func create(node: Node, pos: Vector3, ttl: float, radius: float) -> void:
    _add_to_node(node, pos, ttl, DebugSphere.new(radius))

static func create_color(node: Node, pos: Vector3, ttl: float, radius: float, color: Color) -> void:
    _add_to_node(node, pos, ttl, DebugSphere.new(radius, color))

static func _add_to_node(node: Node, pos: Vector3, ttl: float, sphere: DebugSphere) -> void:
    var scene: Node = node.get_tree().current_scene
    scene.add_child(sphere)
    sphere.global_position = pos
    scene.get_tree().create_timer(ttl, false, true).timeout.connect(sphere.queue_free)

func set_color(color: Color) -> void:
    var mat: StandardMaterial3D = mesh.surface_get_material(0) as StandardMaterial3D
    if not mat:
        return

    mat.albedo_color = color

func set_radius(radius: float) -> void:
    var sphere: SphereMesh = mesh as SphereMesh
    if not sphere:
        return

    sphere.radius = radius
    sphere.height = radius * 2
