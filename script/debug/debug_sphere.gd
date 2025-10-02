class_name DebugSphere extends Node3D

@onready var mesh: MeshInstance3D = %MeshInstance3D


func set_color(color: Color) -> void:
    if not is_node_ready():
        ready.connect(set_color.bind(color))
        return

    var mat: StandardMaterial3D = mesh.mesh.surface_get_material(0) as StandardMaterial3D
    if not mat:
        return

    mat.albedo_color = color

func set_radius(radius: float) -> void:
    if not is_node_ready():
        ready.connect(set_radius.bind(radius))
        return

    var sphere: SphereMesh = mesh.mesh as SphereMesh
    if not sphere:
        return

    sphere.radius = radius
    sphere.height = radius * 2
