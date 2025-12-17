@tool
class_name TerrainInstanceRegion extends Resource


var instance_node: TerrainInstanceNode

@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_NO_EDITOR)
var vertices: PackedInt32Array = []

@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_NO_EDITOR)
var indexes: PackedInt32Array = []


## Adds a vertex, returns the new vertex id
func add_vertex(vertex: Vector2i) -> int:
    var vertex_count: int = vertices.size()
    var index_count: int = indexes.size()

    if index_count < 3:
        vertices.resize(vertex_count + 2)
        indexes.append(vertex_count / 2)
        vertices[vertex_count]     = vertex.x
        vertices[vertex_count + 1] = vertex.y

        if index_count == 2:
            _sort_indexes(indexes)

        print('Vertices: ', vertices)
        print('Indexes: ', indexes)
        return vertex_count / 2

    # TODO: reject vertices that lie within an existing face. My theory was to
    #       get the two closest points and check all their faces, this should
    #       quickly reduce the amount of computation needed and guarantee a result

    vertices.resize(vertex_count + 2)
    vertices[vertex_count]     = vertex.x
    vertices[vertex_count + 1] = vertex.y

    # TODO: get closest vertices that will not produce edges which overlap
    #       existing faces
    vertex_count /= 2
    var next_face: PackedInt32Array = [
        indexes[vertex_count - 2],
        indexes[vertex_count - 1],
        vertex_count
    ]
    _sort_indexes(next_face)

    indexes.append_array(next_face)
    print('Vertices: ', vertices)
    print('Indexes: ', indexes)
    return vertex_count

## Removes all vertices
func clear_vertices() -> void:
    vertices.clear()
    indexes.clear()

## Get the vertex count
func get_vertex_count() -> int:
    return vertices.size() / 2

## Get the vertex by id. This does not perform a bounds check.
func get_vertex(index: int) -> Vector2i:
    index *= 2
    return Vector2i(vertices[index], vertices[index + 1])

## Set the vertex by id. This does not perform a bounds check.
func set_vertex(index: int, new_vertex: Vector2i) -> void:
    index *= 2
    vertices[index]     = new_vertex.x
    vertices[index + 1] = new_vertex.y

## Get the ID of the vertex nearest to point, within some radius. Returns -1 if
## there was no vertex within the radius. If you need the vertex position
## instead, prefer `get_nearest_vertex()`.
func get_nearest_vertex_id(point: Vector2, range: float) -> int:
    var vertex_count: int = vertices.size()
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
        var vertex: Vector2 = Vector2(vertices[id], vertices[id + 1])
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
    return Vector2i(vertices[id], vertices[id + 1])

## Sorts the indexes in clockwise order
func _sort_indexes(arr: PackedInt32Array) -> void:
    var a: Vector2i = get_vertex(arr[0])
    var b: Vector2i = get_vertex(arr[1])
    var c: Vector2i = get_vertex(arr[2])

    var o: Vector2 = Vector2(
        a.x + b.x + c.x,
        a.y + b.y + c.y
    ) / 3.0

    # [0, 1, 2] == [1, 2, 0]
    if _compare_vertices(o, a, b):
        # a(0) <-> b(1)
        # print("b < a")
        var t: int = arr[0]
        arr[0] = arr[1]
        arr[1] = t
        if _compare_vertices(o, a, c):
            # a(1) <-> c(2)
            # print("c < a")
            arr[1] = arr[2]
            arr[2] = t
        elif _compare_vertices(o, b, c):
            # b(0) <-> c(2)
            # print("c < b")
            t = arr[0]
            arr[0] = arr[2]
            arr[2] = t
    elif _compare_vertices(o, a, c):
        # a(0) <-> c(2)
        # print("c < a")
        var t: int = arr[0]
        arr[0] = arr[2]
        arr[2] = t
        if _compare_vertices(o, b, c):
            # b(1) <-> c(0)
            # print("c < b")
            t = arr[1]
            arr[1] = arr[0]
            arr[0] = t
    elif _compare_vertices(o, b, c):
        # b(1) <-> c(2)
        # print("c < b")
        var t: int = arr[1]
        arr[1] = arr[2]
        arr[2] = t

## Comares two vertices, returns 'true' if b < a, 'false' if a <= b
static func _compare_vertices(c: Vector2, a: Vector2i, b: Vector2i) -> bool:
    var ac_x: float = a.x - c.x
    var bc_x: float = b.x - c.x

    # b  |  a
    if ac_x >= 0 and bc_x < 0:
        # print('b | a')
        return true
    # a  |  b
    if ac_x < 0 and bc_x >= 0:
        # print('a | b')
        return false
    # | a b |
    if ac_x == 0 and bc_x == 0:
        # print('| ab |')
        if (a.y - c.y) >= 0 or (b.y - c.y) >= 0:
            # print('a OR b > c')
            return b.y > a.y
        return b.y < a.y

    # compute the cross product of vectors (c -> a) x (c -> b)
    var ac_y: float = a.y - c.y
    var bc_y: float = b.y - c.y

    var det: float = (ac_x * bc_y) - (bc_x * ac_y)
    if det < 0:
        # print('det < 0')
        return true
    if det > 0:
        # print('det > 0')
        return false

    # points a and b are on the same line from the center
    # check which point is closer to the center
    var d1: float = (ac_x * ac_x) + (ac_y * ac_y)
    var d2: float = (bc_x * bc_x) + (bc_y * bc_y)
    return d2 < d1
