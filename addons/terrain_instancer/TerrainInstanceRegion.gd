@tool
class_name TerrainInstanceRegion extends Node3D


var instance_node: TerrainInstanceNode

## This is the ID used for data storage. It is displayed for convenience only,
## it should not be modified while the editor is running.
@export_custom(
    PROPERTY_HINT_RANGE,
    '0,10000,1,hide_slider',
    PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY
)
var region_id: int = 0
var _rd: TerrainInstanceRegionData

@export_tool_button("Populate Region", "PointMesh") var btn_populate = editor_populate_region

var mesh: ArrayMesh = ArrayMesh.new()
var triangle_mesh: TriangleMesh = TriangleMesh.new()
var triangle_mesh_faces: PackedVector3Array = PackedVector3Array()
var _reload_mesh: bool = true
var _show_gizmo: bool = false


func _notification(what: int) -> void:
    if what == NOTIFICATION_EDITOR_PRE_SAVE:
        if _rd:
            ResourceSaver.save(_rd, _rd.resource_path)

## Editor function, probably do some validation and maybe a confirmation dialog
func editor_populate_region() -> void:
    populate_region()

func set_data(data: TerrainInstanceRegionData) -> void:
    _rd = data

func show_gizmos() -> void:
    _show_gizmo = true
    update_gizmos()

func hide_gizmos() -> void:
    _show_gizmo = false
    update_gizmos()

func update_mesh() -> void:
    if not _reload_mesh:
        return

    mesh.clear_surfaces()

    if _rd.indexes.size() > 0:
        var data: Array = []
        data.resize(Mesh.ARRAY_MAX)

        var mapped_vertices: PackedVector3Array = PackedVector3Array()
        var size: int = _rd.vertices.size()
        mapped_vertices.resize(size / 2)
        var i: int = 0
        var mi: int = 0
        while i < size:
            mapped_vertices[mi] = instance_node.project_global(
                    Vector2(_rd.vertices[i], _rd.vertices[i + 1])
            )
            i += 2
            mi += 1

        data[Mesh.ARRAY_VERTEX] = mapped_vertices
        data[Mesh.ARRAY_INDEX]  = _rd.indexes.duplicate()

        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data)

        triangle_mesh = mesh.generate_triangle_mesh()
        triangle_mesh_faces = triangle_mesh.get_faces()
    else:
        triangle_mesh = TriangleMesh.new()
        triangle_mesh_faces.clear()

    _reload_mesh = false

## Adds a vertex, returns the new vertex id
func add_vertex(vertex: Vector2i, enable_checks: bool = true) -> int:
    if enable_checks:
        var id: int = get_vertex_id(vertex)
        if id != -1:
            push_error('Vertex %s already exists, id: %d' % [vertex, id])
            return -1
        # TODO: reject vertices that lie within an existing face.

    var vertex_count: int = _rd.vertices.size()
    _rd.vertices.resize(vertex_count + 2)
    _rd.vertices[vertex_count]     = vertex.x
    _rd.vertices[vertex_count + 1] = vertex.y

    print('Vertices: ', _rd.vertices.duplicate())
    return vertex_count / 2

## Adds a face using indexes, returns the new face id
func add_face(index_array: PackedInt32Array, enable_checks: bool = true) -> int:
    if enable_checks:
        var size: int = index_array.size()
        if size != 3:
            push_error('Index array must be length 3, got %d ints' % size)
            return -1
        var max_index: int = _rd.vertices.size() / 2
        for i in range(size):
            var index: int = index_array[i]
            if index < 0 or index >= max_index:
                push_error('Index value %d (element %d) is invalid, must be 0-%d' % [index, i, max_index])
                return -1
        # TODO: check that face does not already exist, would require deterministic index sorting

    # Sort and add
    var sorted: PackedInt32Array = index_array.duplicate()
    _sort_indexes(sorted)

    var face_id: int = _rd.indexes.size() / 3
    _rd.indexes.append_array(sorted)
    _reload_mesh = true

    print('Indexes: ', _rd.indexes.duplicate())
    return face_id

## Removes all vertices and faces
func clear_data() -> void:
    _rd.clear()
    _reload_mesh = true

## Get the vertex count
func get_vertex_count() -> int:
    return _rd.vertices.size() / 2

## Get the vertex by id. This does not perform a bounds check.
func get_vertex(index: int) -> Vector2i:
    index *= 2
    return Vector2i(_rd.vertices[index], _rd.vertices[index + 1])

## Find a vertex id from a position. Returns -1 if not found
func get_vertex_id(vertex: Vector2i) -> int:
    var index: int = 0
    var size: int = _rd.vertices.size()
    while index < size:
        if vertex.x == _rd.vertices[index] and vertex.y == _rd.vertices[index + 1]:
            return index / 2
        index += 2
    return -1

## Set the vertex by id. This does not perform a bounds check.
func set_vertex(index: int, new_vertex: Vector2i) -> void:
    index *= 2
    _rd.vertices[index]     = new_vertex.x
    _rd.vertices[index + 1] = new_vertex.y
    _reload_mesh = true

## Get the ID of the vertex nearest to point, within some radius. Returns -1 if
## there was no vertex within the radius. If you need the vertex position
## instead, prefer `get_nearest_vertex()`.
func get_nearest_vertex_id(point: Vector2, range: float) -> int:
    var vertex_count: int = _rd.vertices.size()
    if vertex_count < 1:
        return -1

    var range_sq: float = range * range
    var offset: Vector2 = Vector2.ONE * range
    var max_pos: Vector2 = point + offset
    var min_pos: Vector2 = point - offset

    var best_dist: float = INF
    var best_id: int = -1
    var id: int = 0
    while id < vertex_count:
        var vertex: Vector2 = Vector2(_rd.vertices[id], _rd.vertices[id + 1])
        if (
               vertex.x < min_pos.x or vertex.x > max_pos.x
            or vertex.y < min_pos.y or vertex.y > max_pos.y
        ):
            id += 2
            continue
        var dist_sq: float = point.distance_squared_to(vertex)
        if dist_sq <= range_sq and dist_sq < best_dist:
            best_dist = dist_sq
            best_id = id
        id += 2

    if best_id == -1:
        return -1
    return best_id / 2

## Get the vertex nearest to point, within some range. Returns Vector2i.MAX if
## there was no vertex within the radius.
func get_nearest_vertex(point: Vector2, range: float) -> Vector2i:
    var id: int = get_nearest_vertex_id(point, range)
    if id == -1:
        return Vector2i.MAX
    id *= 2
    return Vector2i(_rd.vertices[id], _rd.vertices[id + 1])

## Sorts the indexes in clockwise order
func _sort_indexes(arr: PackedInt32Array) -> void:
    # Get vectors relative to center point
    var ia: int = arr[0]
    var ib: int = arr[1]
    var ic: int = arr[2]
    var a: Vector2 = get_vertex(ia)
    var b: Vector2 = get_vertex(ib)
    var c: Vector2 = get_vertex(ic)

    # invert z
    a.y = -a.y
    b.y = -b.y
    c.y = -c.y

    var o: Vector2 = Vector2(
        a.x + b.x + c.x,
        a.y + b.y + c.y
    ) / 3.0
    # print("o: %s" % o)
    a -= o
    b -= o
    c -= o

    # Convert each vector to an angle, but inverted so they sort in reverse
    # NOTE: this is slow for many vectors, but acceptable since this is done
    #       only one time when adding, and once when checking for duplicates
    var angle_a: float = TAU - (atan2(a.y, a.x) + PI)
    var angle_b: float = TAU - (atan2(b.y, b.x) + PI)
    var angle_c: float = TAU - (atan2(c.y, c.x) + PI)

    # print('angles:\n  a: %s = %f\n  b: %s = %f\n  c: %s = %f' % [a, angle_a, b, angle_b, c, angle_c])

    # Sort by angle normally
    var sorted: Array = Array(arr)
    sorted.sort_custom(
        func(a: int, b: int) -> bool:
            var f: float
            if a == ia:
                f = angle_a
            elif a == ib:
                f = angle_b
            else:
                f = angle_c

            if b == ia:
                return f < angle_a
            if b == ib:
                return f < angle_b
            return f < angle_c
    )

    # print('first sort: %s' % str(sorted))

    # Place lowest index first, followed by the remaining indexes
    # NOTE: this step is to make the resulting set of indexes deterministic
    #       for any input ordering of the same three vertices
    var old := sorted.duplicate()
    var i: int = 0
    var best: int = 0
    var lowest: int = Vector2i.MAX.x
    while i < 3:
        if old[i] < lowest:
            lowest = old[i]
            best = i
        i += 1

    i = 0
    while i < 3:
        arr[i] = old[best]
        i += 1
        best = posmod(best + 1, 3)

    # print('index sort: %s' % arr)

func populate_region() -> void:
    # Ensure triangle mesh is up-to-date
    update_mesh()

    if triangle_mesh_faces.size() == 0:
        EditorInterface.get_editor_toaster().push_toast(
                "No faces for this region, nothing to populate",
                EditorToaster.SEVERITY_WARNING
        )
        return

    # CRITICAL NOTE!!!
    # ONLY add transforms, you provide a list of transforms, colors, by instance
    # id to Node, and it will add them to the terrain.
    # Support a clear button, which will search for instances by managed id, and
    # delete any within the regions.
    # This should be a whole lot simpler and faster.
    # Make sure to not remove transforms that exist in the custom instances dict

    # Get the area rect from the mesh AABB
    var box: AABB = mesh.get_aabb().abs()
    var x1: int = box.position.x
    var y1: int = box.position.z
    var x2: int = x1 + box.size.x
    var y2: int = y1 + box.size.z

    # Place instances at vertices within the triangles, allow edges
    var data: Dictionary = {}

    var instance_data: Dictionary = data.get_or_add(0, Dictionary())

    var xforms: Array[Transform3D]
    xforms = instance_data.get_or_add(&'xforms', xforms)
    var colors: PackedColorArray
    colors = instance_data.get_or_add(&'colors', colors)

    var pos: Vector3 = Vector3(0, 1e6, 0)
    var dir: Vector3 = Vector3.DOWN

    var x: int = x1
    var y: int
    while x <= x2:
        pos.x = x
        y = y1
        while y <= y2:
            pos.z = y

            if not triangle_mesh.intersect_ray(pos, dir):
                y += 1
                continue

            var height: float = instance_node.get_height(Vector2(pos.x, pos.z))
            if is_nan(height):
                y += 1
                continue

            # For now, 1/10
            if randf() > 0.1:
                y += 1
                continue

            xforms.append(Transform3D(Basis.IDENTITY, Vector3(pos.x, height, pos.z)))
            y += 1
        x += 1

    instance_node.add_instances(data)
