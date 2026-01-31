@tool
class_name TerrainRegionPolygon extends Node3D

enum Mode {
    ADD,
    SUBTRACT,
}

@export var mode: Mode

@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_NO_EDITOR)
var vertices: PackedInt32Array

var changed: bool = true

var mesh: ArrayMesh = ArrayMesh.new()
var world_vertices: PackedVector3Array
var triangle_mesh: TriangleMesh
var triangle_mesh_faces: PackedVector3Array


func _ready() -> void:
    # NOTE: should never be moving this
    set_meta(&'_edit_lock_', true)
