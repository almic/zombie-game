@tool

## Simple ramp CSG shape
class_name CSGRamp3D extends CSGBox3D

var ramp_shape: CSGPolygon3D
var last_size: Vector3 = Vector3.ZERO

## Read only, purely to see the slope angle in the inspector
@export_custom(0, "radians_as_degrees", PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY)
var read_only_slope: float = 0.0


func _ready() -> void:
    create_ramp()
    update_ramp()

func _process(_delta: float) -> void:
    if not Engine.is_editor_hint():
        return

    if ramp_shape.material != material:
        ramp_shape.material = material

    if size == last_size:
        return

    update_ramp()
    last_size = size

func create_ramp() -> void:
    ramp_shape = CSGPolygon3D.new()
    ramp_shape.operation = CSGShape3D.OPERATION_INTERSECTION
    ramp_shape.material = material
    add_child(ramp_shape)

func update_ramp() -> void:
    ramp_shape.polygon = PackedVector2Array([
        Vector2(size.x / 2.0, -size.y / 2.0),
        Vector2(-size.x / 2.0, -size.y / 2.0),
        Vector2(-size.x / 2.0, size.y / 2.0)
    ])
    ramp_shape.depth = size.z
    ramp_shape.position.z = size.z / 2.0

    read_only_slope = acos(Vector2(size.x, size.y).normalized().dot(Vector2(1.0, 0.0)))
