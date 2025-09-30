@tool
class_name CSGCurve3D extends CSGPolygonResource3D


## Trigger the node to refresh internal tree
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR)
var refresh: bool = false:
    set(value):
        refresh = false
        if value and is_node_ready():
            _refresh()


var path: Path3D
var curve: Curve3D = Curve3D.new()
var points: Array[CSGCurvePoint3D]


func _init() -> void:
    # Always set
    mode = CSGPolygon3D.MODE_PATH
    path_local = true
    path_continuous_u = true

    # Change defaults (and avoid them)
    if path_rotation == CSGPolygon3D.PATH_ROTATION_POLYGON:
        path_rotation = CSGPolygon3D.PATH_ROTATION_PATH_FOLLOW
    if path_simplify_angle == 0.0:
        path_simplify_angle = 1.0

func _ready() -> void:
    super._ready()

    child_entered_tree.connect(_child_added)
    child_exiting_tree.connect(_child_removed)
    child_order_changed.connect(_children_reordered)

    _refresh.call_deferred()

func _notification(what: int) -> void:
    # NOTE: prevent saving the marker 3d
    # NOTE: however, do not search children to delete them!
    if what == NOTIFICATION_EDITOR_PRE_SAVE:
        if path_node:
            path_node = NodePath()
    elif what == NOTIFICATION_EDITOR_POST_SAVE:
        if path:
            path_node = get_path_to(path)


func _child_added(node: Node) -> void:
    var point: CSGCurvePoint3D = node as CSGCurvePoint3D
    if not point:
        return

    point.modified.connect(update_points)

func _child_removed(node: Node) -> void:
    var point: CSGCurvePoint3D = node as CSGCurvePoint3D
    if not point:
        return

    point.modified.disconnect(update_points)

func _children_reordered() -> void:
    update_children()
    update_points()

func update_children() -> void:
    points.clear()
    var last: CSGCurvePoint3D = null
    for node in get_children():
        if node is CSGCurvePoint3D:
            if last == null:
                node._is_first = true
            last = node
            points.append(node)
            if not node.modified.is_connected(update_points):
                node.modified.connect(update_points)
    if last:
        last._is_last = true

func _refresh() -> void:
    update_children()
    update_points()

    # Clean up the old path node
    if path:
        path_node = NodePath()
        path.curve = Curve3D.new()
        remove_child(path)
        path.queue_free()

    path = Path3D.new()
    add_child(path, false, Node.INTERNAL_MODE_BACK)
    path.curve = curve
    curve.up_vector_enabled = false

    path_node = get_path_to(path)

func update_points() -> void:
    if not is_node_ready():
        return

    # Compute number of needed points
    var point: CSGCurvePoint3D
    var total: int = 0
    var size: int = points.size()
    for i in range(size):
        point = points[i]
        total += 1
        if point.straight_length > 0:
            total += 1
            if i > 0 and i < size - 1:
                total += 1

    # Update curve point count
    if curve.point_count != total:
        curve.clear_points()
        for i in range(total):
            curve.add_point(Vector3.ZERO)

    # Add points
    var skip: int = 0
    for i in range(size):
        point = points[i]

        var is_first: bool = i == 0
        var is_last: bool = i == size - 1
        var tilt: float = point.rotation.z

        # Add entering straight point
        if point.straight_length > 0 and not is_first:
            var offset: Vector3 = -point.basis.z * point.straight_length
            if not is_last:
                offset *= 0.5

            curve.set_point_position(i + skip, point.position + offset)
            curve.set_point_tilt(i + skip, tilt)

            curve.set_point_out(i + skip, Vector3.ZERO)

            if point.handle_length > 0:
                curve.set_point_in(i + skip, -point.basis.z * point.handle_length)
            else:
                curve.set_point_in(i + skip, Vector3.ZERO)

            skip += 1

        # Add central point
        curve.set_point_position(i + skip, point.position)
        curve.set_point_tilt(i + skip, tilt)

        if not point.straight_length > 0 and point.handle_length > 0:
            if is_first:
                curve.set_point_in(i + skip, Vector3.ZERO)
            else:
                curve.set_point_in(i + skip, -point.basis.z * point.handle_length)
            if is_last:
                curve.set_point_out(i + skip, Vector3.ZERO)
            else:
                curve.set_point_out(i + skip, point.basis.z * point.handle_length)
        else:
            curve.set_point_in(i + skip, Vector3.ZERO)
            curve.set_point_out(i + skip, Vector3.ZERO)

        # Add exiting straight point
        if point.straight_length > 0 and (not is_last or size == 1):
            var offset: Vector3 = point.basis.z * point.straight_length
            if not is_first:
                offset *= 0.5

            curve.set_point_position(i + skip + 1, point.position + offset)
            curve.set_point_tilt(i + skip + 1, tilt)

            curve.set_point_in(i + skip + 1, Vector3.ZERO)

            if point.handle_length > 0:
                curve.set_point_out(i + skip + 1, point.basis.z * point.handle_length)
            else:
                curve.set_point_out(i + skip + 1, Vector3.ZERO)

            skip += 1
