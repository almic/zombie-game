@tool

## Simple step CSG shape that can also use ramp colliders
class_name CSGSteps3D extends CSGBox3D


@export_range(2, 20, 1.0, 'or_greater')
var steps: int = 3:
    set = set_steps


var steps_shape: CSGPolygon3D
var last_size: Vector3


func _ready() -> void:
    create_steps()
    update_steps()

func _process(_delta: float) -> void:
    if not Engine.is_editor_hint():
        return

    if steps_shape.material != material:
        steps_shape.material = material

    if size == last_size:
        return

    update_steps()
    last_size = size

func set_steps(value: int) -> void:
    if value < 2:
        return

    if steps == value:
        return

    steps = value

    if not is_node_ready():
        return

    if not steps_shape:
        create_steps()
    update_steps()

func create_steps() -> void:
    steps_shape = CSGPolygon3D.new()
    steps_shape.operation = CSGShape3D.OPERATION_INTERSECTION
    steps_shape.material = material
    add_child(steps_shape)

func update_steps() -> void:
    var step_height: float = size.y / steps
    var step_length: float = size.x / steps

    var step_array: PackedVector2Array = PackedVector2Array([
            Vector2(size.x / 2.0, -size.y / 2.0),
            Vector2(-size.x / 2.0, -size.y / 2.0)
    ])

    var x: float = -size.x / 2.0
    var y: float = size.y / 2.0

    for i in range(steps):
        step_array.append(Vector2(x, y))
        step_array.append(Vector2(x + step_length, y))
        x += step_length
        y -= step_height

    steps_shape.polygon = step_array
    steps_shape.depth = size.z
    steps_shape.position.z = size.z / 2.0
