extends EditorNode3DGizmoPlugin


const SQUARE_ROUND = preload('uid://be4m41arot64v')
const CIRCLE = preload('uid://cyv2f4x232fm4')

const COLOR_RED = Color("fc7f7fff")
const COLOR_BLUE = Color("8da5f3ff")


func _get_gizmo_name() -> String:
    return "CSGCurve3D"

func _has_gizmo(node: Node3D) -> bool:
    return is_instance_of(node, CSGCurvePoint3D)

func _init() -> void:
    create_icon_material("square", SQUARE_ROUND, true)
    create_icon_material("circle", CIRCLE, true)

    get_material("square").no_depth_test = true
    get_material("circle").no_depth_test = true

static func make_billboard(color: Color) -> ArrayMesh:
    const scale = 0.033

    var vs: PackedVector3Array = [
        Vector3(-scale,  scale, 0),
        Vector3( scale,  scale, 0),
        Vector3( scale, -scale, 0),
        Vector3(-scale, -scale, 0)
    ]

    var uv: PackedVector2Array = [
        Vector2(0, 0),
        Vector2(1, 0),
        Vector2(1, 1),
        Vector2(0, 1)
    ]

    var indices: PackedInt32Array = [ 0, 1, 2, 0, 2, 3 ]

    var colors: PackedColorArray = [ color, color, color, color ]

    var array: Array
    array.resize(Mesh.ARRAY_MAX)

    array[Mesh.ARRAY_VERTEX] = vs
    array[Mesh.ARRAY_TEX_UV] = uv
    array[Mesh.ARRAY_INDEX] = indices
    array[Mesh.ARRAY_COLOR] = colors

    var mesh: ArrayMesh = ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, array)
    mesh.custom_aabb = AABB(Vector3(-scale, -scale, -scale) * 100.0, Vector3(scale, scale, scale) * 200.0)

    return mesh


func _redraw(gizmo: EditorNode3DGizmo) -> void:
    gizmo.clear()

    var curve_point: CSGCurvePoint3D = gizmo.get_node_3d() as CSGCurvePoint3D
    if curve_point:
        if curve_point._show_gizmo:
            draw_curve_point(gizmo, curve_point)
        return

func draw_curve_point(gizmo: EditorNode3DGizmo, node: CSGCurvePoint3D) -> void:
    var transform: Transform3D = Transform3D.IDENTITY
    if node._is_first or node._is_last:
        var dir: Vector3
        if node._is_first:
            dir = Vector3.MODEL_FRONT
        else:
            dir = Vector3.MODEL_REAR
        if node.straight_length > 0:
            gizmo.add_mesh(make_billboard(COLOR_RED), get_material("square"), transform.translated_local(dir * node.straight_length))
        if node.handle_length > 0:
            gizmo.add_mesh(make_billboard(COLOR_BLUE), get_material("circle"), transform.translated_local(dir * (node.straight_length + node.handle_length)))
    else:
        if node.straight_length > 0:
            var t: Vector3 = Vector3.MODEL_FRONT * node.straight_length * 0.5
            var m: Mesh = make_billboard(COLOR_RED)
            gizmo.add_mesh(m, get_material("square"), transform.translated_local(t))
            gizmo.add_mesh(m, get_material("square"), transform.translated_local(-t))
        if node.handle_length > 0:
            var t: Vector3 = Vector3.MODEL_FRONT * (node.straight_length * 0.5 + node.handle_length)
            var m: Mesh = make_billboard(COLOR_BLUE)
            gizmo.add_mesh(m, get_material("circle"), transform.translated_local(t))
            gizmo.add_mesh(m, get_material("circle"), transform.translated_local(-t))

    gizmo.add_unscaled_billboard(get_material("square"), 0.05, COLOR_RED)
