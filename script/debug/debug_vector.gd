@tool
class_name DebugVector extends Node3D


signal vector_changed(vector: DebugVector)


@export
var vector: Vector3 = Vector3.FORWARD:
    set = set_vector

@export var color: Color = Color.DEEP_SKY_BLUE:
    set = set_color

@export var normalized: bool = false:
    set(value):
        normalized = value
        vector = vector


var mesh_inst: MeshInstance3D
var mesh: Mesh


func _init() -> void:
    mesh = CylinderMesh.new()
    mesh.rings = 0
    mesh.top_radius = 0.07
    mesh.bottom_radius = 0.02

    var material := StandardMaterial3D.new()
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

    mesh.material = material

    mesh_inst = MeshInstance3D.new()
    mesh_inst.mesh = mesh
    add_child(mesh_inst)

    set_color(color)
    set_vector(vector)


func set_color(col: Color) -> void:
    color = col
    mesh.material.albedo_color = col

func set_vector(vec: Vector3) -> void:
    vector = vec
    mesh.height = vec.length()
    if is_zero_approx(mesh.height):
        mesh_inst.position = Vector3.ZERO
        vector_changed.emit(self)
        return

    if normalized:
        vector = vector / mesh.height
        mesh.height = 1.0

    var forward: Vector3 = vec / mesh.height
    var up: Vector3 = forward.cross(Vector3.UP)
    if up.is_zero_approx():
        up = forward.cross(Vector3.RIGHT)
    var right: Vector3 = forward.cross(up)

    # Up is our forward direction on cylinder meshes
    mesh_inst.basis = Basis(-right, -forward, up).orthonormalized()
    mesh_inst.position = Vector3.ZERO
    mesh_inst.transform = mesh_inst.transform.translated_local(Vector3.UP * -mesh.height * 0.5)

    vector_changed.emit(self)
