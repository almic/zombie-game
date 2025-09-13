@tool
class_name CSGCurve3D extends CSGPolygon3D


const HALF_PI = PI * 0.5


## Trigger the node to refresh internal tree
@export var refresh: bool = false:
    set(value):
        refresh = false
        if value:
            _setup()
            use_end_marker = use_end_marker

## Enable to place a marker in the scene for the end point. Turn off after you
## have the end where you like it. The marker is automatically deleted when the
## scene saves.
@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_EDITOR)
var use_end_marker: bool = false:
    set = set_use_end_marker

## Width and height of the mesh to curve
@export var size: Vector2 = Vector2(1.0, 1.0):
    set(value):
        size = value
        update_shape()

## Angle of the first node in the curve
@export_range(-90.0, 90.0, 0.001, 'radians_as_degrees')
var start_angle: float = 0.0:
    set(value):
        start_angle = value
        update_points()

## Length of the "straight" section from the starting point
@export_range(0.001, 4.0, 0.001, 'or_greater')
var start_straight_length: float = 1.0:
    set(value):
        start_straight_length = value
        update_points()

## Length of the first handle in the curve
@export_range(0.0, 10.0, 0.001, 'or_greater')
var start_handle_length: float = 1.0:
    set(value):
        start_handle_length = value
        update_points()

## End offset from the starting point
@export var end_point: Vector3 = Vector3(0.0, 0.0, -4.0):
    set(value):
        end_point = value
        update_points()

## Angle of the last node in the curve
@export_range(-180.0, 180.0, 0.001, 'radians_as_degrees')
var end_angle: float = 0.0:
    set(value):
        end_angle = value
        update_points()

## Length of the "straight" section from the ending point
@export_range(0.001, 4.0, 0.001, 'or_greater')
var end_straight_length: float = 1.0:
    set(value):
        end_straight_length = value
        update_points()

## Length of the last handle in the curve
@export_range(0.0, 10.0, 0.001, 'or_greater')
var end_handle_length: float = 1.0:
    set(value):
        end_handle_length = value
        update_points()


var end_marker: Marker3D
var path: Path3D
var curve: Curve3D = Curve3D.new()


func _ready() -> void:
    _setup.call_deferred()

func _notification(what: int) -> void:
    # NOTE: prevent saving the marker 3d
    # NOTE: however, do not search children to delete them!
    if what == NOTIFICATION_EDITOR_PRE_SAVE:
        if end_marker:
            end_marker.owner = null
            use_end_marker = false

func _process(_delta: float) -> void:
    if not use_end_marker:
        return

    if not end_marker:
        use_end_marker = false
        return

    if not Engine.is_editor_hint():
        return

    if not end_point.is_equal_approx(end_marker.position):
        end_point = end_marker.position

    if not is_equal_approx(end_angle, -end_marker.rotation.y):
        end_angle = -end_marker.rotation.y


func _setup() -> void:
    update_shape()
    update_points()

    # Delete end marker
    use_end_marker = false

    # Clean up the old path node
    if path:
        path_node = NodePath()
        path.curve = Curve3D.new()
        remove_child(path)
        path.queue_free()

    path = Path3D.new()
    add_child(path)
    path.curve = curve

    mode = CSGPolygon3D.MODE_PATH
    path_node = get_path_to(path)
    path_local = true
    path_continuous_u = true

func update_shape() -> void:
    if not is_node_ready():
        return

    var w: float = size.x * 0.5
    var h: float = size.y * 0.5

    if polygon.size() != 4:
        polygon.clear()
        polygon.resize(4)

    polygon[0] = Vector2(-w, -h)
    polygon[1] = Vector2(-w,  h)
    polygon[2] = Vector2( w,  h)
    polygon[3] = Vector2( w, -h)

func update_points() -> void:
    if not is_node_ready():
        return

    curve.clear_points()

    # First point at self position
    curve.add_point(Vector3.ZERO)

    # Second point at the angle and distance set
    var angle: Vector3 = Vector3(cos(start_angle - HALF_PI), 0.0, sin(start_angle - HALF_PI))
    curve.add_point(
            angle * start_straight_length,
            Vector3.ZERO,
            angle * start_handle_length
    )

    # Third point at the end straight length
    angle = Vector3(cos(end_angle + HALF_PI), 0.0, sin(end_angle + HALF_PI))
    curve.add_point(
            end_point + (angle * end_straight_length),
            angle * end_handle_length
    )

    # Fourth point at the exit position
    curve.add_point(end_point)

func set_use_end_marker(use: bool) -> void:
    use_end_marker = use

    if end_marker:
        end_point = end_marker.position
        end_angle = -end_marker.rotation.y
        remove_child(end_marker)
        end_marker.queue_free()
        end_marker = null

    if not use:
        return

    end_marker = Marker3D.new()
    end_marker.gizmo_extents = 1.0

    add_child(end_marker)
    end_marker.owner = owner
    end_marker.name = &"TempCurveEndMarker"

    end_marker.position = end_point
    end_marker.rotation.y = -end_angle
