@tool
class_name TerrainInstanceRegion extends Node3D


const INT_MAX: int = Vector2i.MAX.x


@export_tool_button("Populate Region", "PointMesh")
var btn_populate = editor_populate_region

@export_tool_button("Clear Region", "Clear")
var btn_clear = editor_clear_region


@export
var settings: TerrainInstanceRegionSettings


@export_subgroup("Info")

## This is the ID used for data storage. It is displayed for convenience only,
## it should not be modified while the editor is running.
@export_custom(
    PROPERTY_HINT_RANGE,
    '0,10000,1,hide_slider',
    PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY
)
var region_id: int = 0
var _rd: TerrainInstanceRegionData


var instance_node: TerrainInstanceNode

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
func editor_clear_region() -> void:
    clear_region()

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

    return face_id

## Using a raycast, returns a face index, used to "pick" a face from the editor.
## Returns -1 if no face was hit.
func pick_face(begin: Vector3, direction: Vector3) -> int:
    update_mesh()

    if triangle_mesh_faces.size() == 0:
        return -1

    # Hit test on triangle mesh
    var hit: Dictionary = triangle_mesh.intersect_ray(begin, direction)
    if not hit:
        return -1

    # Retrieve vertex indices
    var tri_face: int = hit.face_index * 3
    var verts: Array[Vector2i]
    verts.resize(3)

    for i in range(3):
        var point: Vector3i = Vector3i(triangle_mesh_faces[tri_face + i].round())
        verts[i] = Vector2i(point.x, point.z)

    var face: PackedInt32Array
    face.resize(3)
    face.fill(-1)

    var i: int = 0
    var size: int = _rd.vertices.size()
    while i < size:
        var vertex: Vector2i = Vector2i(_rd.vertices[i], _rd.vertices[i + 1])
        for v in range(3):
            if vertex == verts[v]:
                face[v] = i / 2
                break
        i += 2

    # Test that we found all indexes
    i = 0
    size = 3
    while i < size:
        if face[i] == -1:
            push_error('Failed to match vertex %s with existing vertices!' % verts[i])
        i += 1

    # Sort vertices so face matching is trivial/ fast
    _sort_indexes(face)

    # Find face
    i = 0
    size = _rd.indexes.size()
    while i < size:
        if (
                    _rd.indexes[i]     == face[0]
                and _rd.indexes[i + 1] == face[1]
                and _rd.indexes[i + 2] == face[2]
        ):
            return i / 3
        i += 3

    push_error('Failed to match face %s with existing faces!' % face)

    return -1

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

## Remove a vertex. Also deletes any faces connected to the vertex. This does not
## perform a bounds check.
func remove_vertex(index: int) -> void:
    # NOTE: order matters
    _rd.vertices.remove_at(index * 2 + 1)
    _rd.vertices.remove_at(index * 2)

    # Remove/ update faces
    var i: int = 0
    var size: int = _rd.indexes.size()
    while i < size:
        if not (
                   _rd.indexes[i]     == index
                or _rd.indexes[i + 1] == index
                or _rd.indexes[i + 2] == index
        ):
            for v in range(3):
                if _rd.indexes[i + v] > index:
                    _rd.indexes[i + v] -= 1
                    _reload_mesh = true
            i += 3
            continue

        # NOTE: order matters
        _rd.indexes.remove_at(i + 2)
        _rd.indexes.remove_at(i + 1)
        _rd.indexes.remove_at(i)
        size -= 3

        _reload_mesh = true

## Removes a face. Does not delete any vertices. This does not perform a bounds
## check.
func remove_face(index: int) -> void:
    index *= 3

    # NOTE: order matters
    _rd.indexes.remove_at(index + 2)
    _rd.indexes.remove_at(index + 1)
    _rd.indexes.remove_at(index)

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

    a -= o
    b -= o
    c -= o

    # Convert each vector to an angle, but inverted so they sort in reverse
    # NOTE: this is slow for many vectors, but acceptable since this is done
    #       only one time when adding, and once when checking for duplicates
    var angle_a: float = TAU - (atan2(a.y, a.x) + PI)
    var angle_b: float = TAU - (atan2(b.y, b.x) + PI)
    var angle_c: float = TAU - (atan2(c.y, c.x) + PI)

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

func clear_region() -> void:
    update_mesh()
    if triangle_mesh_faces.size() == 0:
        EditorInterface.get_editor_toaster().push_toast(
                "No faces for this region, cannot clear",
                EditorToaster.SEVERITY_WARNING
        )
        return

    # Build set of instance types to manage
    var ids: Array[int]
    for inst in settings.instances:
        if ids.has(inst.id):
            continue
        ids.append(inst.id)

    var box: AABB = mesh.get_aabb().abs()
    var area: Rect2 = Rect2(box.position.x, box.position.z, box.size.x, box.size.z)

    var begin := Vector3(0, 1e6, 0)
    var dir := Vector3.DOWN

    var indexes: Array = instance_node.get_instance_indexes(area)
    var new_data: Array[Dictionary]
    var new_indexes: Array

    for index in indexes:
        var inst_data: Dictionary = instance_node.get_instance_data(index)
        var new_inst_data: Dictionary
        for inst_id in inst_data:
            if not ids.has(inst_id):
                continue

            var new_cell_data: Dictionary
            var cell_data: Dictionary = inst_data.get(inst_id)
            for cell in cell_data:
                var mesh_data: Dictionary = cell_data.get(cell)
                var xforms: Array = mesh_data.get(&'xform')
                var colors: PackedColorArray = mesh_data.get(&'color')
                var modified: bool = false

                var i: int = 0
                var size: int = xforms.size()
                while i < size:
                    var xform: Transform3D = xforms[i]

                    # CRITICAL TODO!!!
                    # Make sure to not remove transforms that exist in the custom instances dict

                    begin.x = xform.origin.x
                    begin.z = xform.origin.z

                    if not triangle_mesh.intersect_ray(begin, dir):
                        i += 1
                        continue

                    xforms.remove_at(i)
                    colors.remove_at(i)
                    modified = true
                    size -= 1

                if modified:
                    mesh_data.set(&'color', colors)
                    new_cell_data.set(cell, mesh_data)

            if new_cell_data.size() > 0:
                new_inst_data.set(inst_id, new_cell_data)

        if new_inst_data.size() > 0:
            new_data.append(new_inst_data)
            new_indexes.append(index)

    instance_node.set_instance_data(new_indexes, new_data)

func populate_region() -> void:
    var start: int = Time.get_ticks_usec()

    # Ensure triangle mesh is up-to-date
    update_mesh()

    if triangle_mesh_faces.size() == 0:
        EditorInterface.get_editor_toaster().push_toast(
                "No faces for this region, nothing to populate",
                EditorToaster.SEVERITY_WARNING
        )
        return

    if settings.instances.size() == 0:
        EditorInterface.get_editor_toaster().push_toast(
                "No instances to place in settings, nothing to populate",
                EditorToaster.SEVERITY_WARNING
        )
        return

    # Build structures for placing instances
    var instances: Dictionary
    for instance_setting in settings.instances:
        if (not instance_setting.enabled) or instance_setting.id == -1:
            continue

        var inst_data: Dictionary
        for inst_id in instance_setting.minimum_distances:
            inst_data.set(
                    inst_id,
                    {
                        &'last_column': INT_MAX,
                        &'closest': Vector2i.MAX,
                    }
            )

        # Ensure itself is present for density logic
        if not inst_data.has(instance_setting.id):
            inst_data.set(
                    instance_setting.id,
                    {
                        &'last_column': INT_MAX,
                        &'closest': Vector2i.MAX,
                    }
            )

        instances.set(instance_setting, inst_data)

    if instances.size() == 0:
        EditorInterface.get_editor_toaster().push_toast(
                "No enabled instances, nothing to populate",
                EditorToaster.SEVERITY_WARNING
        )
        return

    # Track "nearest" targets in a smaller set
    #
    # With pruning
    # {
    #     [id; int] {
    #         [column; int] {
    #             [used; bool],
    #             [left; column],
    #             [right; column],
    #             [row; int],
    #         }
    #     }
    # }
    #
    # Without pruning
    # {
    #     [id; int] {
    #         [column; int] : [row; int]
    #     }
    # }
    #
    var tracking: Dictionary

    # Locations to output, map instance id to vertex array
    var output: Dictionary
    for inst in instances:
        output.set(inst.id, PackedInt32Array())

    # Vars for mesh hit testing
    var pos: Vector3 = Vector3(0, 1e6, 0)
    var dir: Vector3 = Vector3.DOWN

    # Get the area rect from the mesh AABB
    var box: AABB = mesh.get_aabb().abs()
    var x1: int = box.position.x
    var y1: int = box.position.z
    var x2: int = x1 + box.size.x
    var y2: int = y1 + box.size.z

    # Mesh vertex loop
    var v: Vector2i
    var vx: int
    var vy: int = y1
    while vy <= y2:
        # _prune_tracking(tracking, vy)
        print('-------\nrow %d' % vy)

        pos.z = vy
        v.y = vy

        vx = x1
        while vx <= x2:
            pos.x = vx
            if not triangle_mesh.intersect_ray(pos, dir):
                vx += 1
                continue

            v.x = vx
            if not instance_node.terrain_has(v):
                vx += 1
                continue

            for inst in instances:
                _populate_instance(
                        inst,
                        instances.get(inst),
                        v,
                        tracking,
                        output,
                )
            print(v)
            print(tracking)

            vx += 1

        vy += 1

        if (vy - y1) % 100 == 0:
            var total: int = 0
            for inst_id in output:
                total += output.get(inst_id).size() / 2
            print(
                    '%.1f completed, %d instances total' % [
                        (float(vy - y1) / (y2 - y1)) * 100.0,
                        total
                    ]
            )

            await get_tree().process_frame

    # Clean up some stuff (maybe not needed but i want my memory back now!)
    tracking.clear()
    instances.clear()

    # Build final transforms and colors
    var data: Dictionary = {}
    var keys = output.keys()
    var total: int = 0
    for inst_id in keys:
        var vertices: PackedInt32Array = output.get(inst_id)

        var size: int = vertices.size()

        var xforms: Array[Transform3D]
        var colors: PackedColorArray
        xforms.resize(size / 2)
        colors.resize(size / 2)

        var i: int = 0
        var k: int = 0
        while i < size:
            var tx: float = vertices[i]
            var tz: float = vertices[i + 1]

            # wiggle a little
            #tx += 0.7 * randf() - 0.35
            #tz += 0.7 * randf() - 0.35

            # check that we are still in the mesh
            pos.x = tx
            pos.z = tz
            if not triangle_mesh.intersect_ray(pos, dir):
                tx = vertices[i]
                tz = vertices[i + 1]

            var ty: float = instance_node.get_height(Vector2(tx, tz))
            if is_nan(ty):
                tx = vertices[i]
                tz = vertices[i + 1]
                ty = instance_node.get_height(Vector2(tx, tz))
                if is_nan(ty):
                    push_error('Guh')
                    i += 2
                    # Shrink arrays
                    xforms.resize(xforms.size() - 1)
                    colors.resize(colors.size() - 1)
                    continue

            # TODO: height variation option
            # TODO: rotation variation
            # TODO: scale variation

            xforms[k] = Transform3D(
                    Basis.IDENTITY, Vector3(tx, ty, tz)
            )

            # TODO: color variation (list of weighted options)
            colors[k] = Color.WHITE

            i += 2
            k += 1
            total += 1

        # Progressively free memory
        output.erase(inst_id)

        # Save to data
        data.set(inst_id, { &'xforms': xforms, &'colors': colors })

    # NOTE: do not time the terrain placement side
    var end: int = Time.get_ticks_usec()

    print('Populated %d instances in %.3f seconds' % [total, float(end - start) / 1e6])

    start = Time.get_ticks_usec()
    # Add instances to terrain
    instance_node.add_instances(data)
    end = Time.get_ticks_usec()

    print('Terrain updated in %.3f seconds' % [float(end - start) / 1e6])

## Probability test using a given density of the instance, and a distance to
## the nearest interfering instance
func _populate_probability(density: float, nearest: float) -> bool:
    var s: float = 271828.0 / density
    var x: float = clampf(nearest, 0.0, s)

    var p: float = tanh((-cos(x * (PI / s)) + 1.0) / PI)
    return p >= randf()

## Clears instances from the tracking dictionary if later instances are provably
## always closer to 'row'. An instance must have a left and right neighbor on
## the same row or below, and closer in the X-dimension than 'row'.
func _prune_tracking(
        tracking: Dictionary,
        row: int
) -> void:
    # Switch to turn this off for timings tests
    const enable: bool = true
    if not enable:
        return

    # NOTE: due to memory use needed for pruning, I'm gonna leave this
    #       unimplemented until I do timings with large regions, and if locating
    #       the closest neighbor is the biggest time usage.
    pass

## Main logic for instance placement relating to settings
func _populate_instance(
        instance: TerrainInstanceSettings,
        data: Dictionary,
        vertex: Vector2i,
        tracking: Dictionary,
        output: Dictionary
) -> void:

    # Optimize, skip distance tests
    var skip_tests: bool = true
    for inst_id in instance.minimum_distances:
        if tracking.has(inst_id):
            skip_tests = false
            break

    if skip_tests:
        print('first run/ no instances')
        if _populate_probability(instance.density, INF):
            _put_instance(instance, data, vertex, tracking, output)
        return

    # Compute closest distance
    var nearest_sq: int = INT_MAX

    # Tracking
    # {
    #     [id; int] {
    #         [column; int] : [row; int]
    #     }
    # }

    if vertex.x < data.get(instance.id).last_column:
        # Gone back, must get new closest

        var best_sq: int = INT_MAX
        var point: Vector2i

        for inst_id in instance.minimum_distances:
            var inst_data: Dictionary = data.get(inst_id)
            inst_data.last_column = vertex.x

            if not tracking.has(inst_id):
                continue

            var is_self: bool = inst_id == instance.id
            var closest: Vector2i = Vector2i.MAX
            var inst_map: Dictionary = tracking.get(inst_id)

            var min_dist_sq: float = instance.minimum_distances.get(inst_id, 0)
            min_dist_sq *= min_dist_sq

            for column in inst_map:
                # Stop early if it is impossible to be closer than best, and
                # further than most distant instance
                if column > vertex.x:
                    var max_sq: int = column - vertex.x
                    max_sq *= max_sq
                    if is_self:
                        if max_sq > max(best_sq, min_dist_sq):
                            break
                    elif max_sq > min_dist_sq:
                        break

                point.x = column
                point.y = inst_map[column]

                var dist_sq: int = vertex.distance_squared_to(point)

                # If we are ever too close...
                if dist_sq <= min_dist_sq:
                    inst_data.closest = point
                    print('Found %s that was too close, dist_sq: %d' % [inst_id, dist_sq])
                    return

                # The rest is only for density
                if not is_self:
                    continue

                # NOTE: favor right-most point when equal distance
                if dist_sq <= best_sq:
                    best_sq = dist_sq
                    closest = point

            if is_self:
                if best_sq != INT_MAX:
                    print('closest to %s was %s' % [vertex, closest])
                    inst_data.closest = closest
                    nearest_sq = best_sq
                else:
                    print('nothing found near %s' % vertex)
            else:
                # This instance is no longer too close, clear the closest point
                inst_data.closest = Vector2i.MAX

        if _populate_probability(instance.density, sqrt(nearest_sq)):
            _put_instance(instance, data, vertex, tracking, output)

        return

    # Optimized testing when moving right on the same row

    # Check that we are at least far enough from all of our "closest" instances
    var best_sq: int = INT_MAX
    for inst_id in data:
        var inst_data: Dictionary = data.get(inst_id)
        if inst_data.closest == Vector2i.MAX:
            continue

        var min_sq: float = instance.minimum_distances.get(inst_id, 0)
        min_sq *= min_sq

        var dist_sq: int = vertex.distance_squared_to(inst_data.closest)
        if dist_sq <= min_sq:
            print('Still close to last %s, dist_sq: %d' % [inst_id, best_sq])
            return # Still too close

        if inst_id == instance.id:
            best_sq = dist_sq
            nearest_sq = best_sq
        else:
            # This instance is no longer too close, clear the closest point
            inst_data.closest = Vector2i.MAX

    var point: Vector2i

    for inst_id in instance.minimum_distances:
        var inst_data: Dictionary = data.get(inst_id)

        if not tracking.has(inst_id):
            inst_data.last_column = vertex.x
            continue

        var last_column: int = inst_data.last_column
        inst_data.last_column = vertex.x

        var closest := Vector2i.MAX
        var is_self: bool = inst_id == instance.id
        var inst_map: Dictionary = tracking.get(inst_id)

        var min_dist_sq: float = instance.minimum_distances.get(inst_id, 0)
        min_dist_sq *= min_dist_sq

        for column in inst_map:
            # Skip columns prior to last column, they would have been
            # tested already
            if column <= last_column:
                continue

            # Stop early if the best option is too far
            if column > vertex.x:
                var max_sq: int = column - vertex.x
                max_sq *= max_sq
                if is_self:
                    if max_sq > max(best_sq, min_dist_sq):
                        break
                elif max_sq > min_dist_sq:
                    break

            point.x = column
            point.y = inst_map[column]

            var dist_sq: int = vertex.distance_squared_to(point)

            # If we are ever too close...
            if dist_sq <= min_dist_sq:
                inst_data.closest = point
                print('Too close to %s, dist_sq: %d' % [inst_id, dist_sq])
                return

            # The rest is only for density
            if not is_self:
                continue

            # NOTE: favor right-most point when equal distance
            if dist_sq <= best_sq:
                closest = point
                best_sq = dist_sq

        if is_self:
            if closest != Vector2i.MAX and closest != inst_data.closest:
                print('NEW closest to %s was %s' % [vertex, closest])
                inst_data.closest = closest
                nearest_sq = best_sq
            else:
                print('Nothing closer to %s than %s' % [vertex, inst_data.closest])

    if _populate_probability(instance.density, sqrt(nearest_sq)):
        _put_instance(instance, data, vertex, tracking, output)

func _put_instance(
        instance: TerrainInstanceSettings,
        data: Dictionary,
        vertex: Vector2i,
        tracking: Dictionary,
        output: Dictionary
) -> void:
    output.get(instance.id).append_array([vertex.x, vertex.y])
    if not tracking.has(instance.id):
        tracking.set(instance.id, { vertex.x: vertex.y })
        print('First instance of %d: %s' % [instance.id, { vertex.x: vertex.y }])
    else:
        var inst_map: Dictionary = tracking.get(instance.id)
        var do_sort: bool = not inst_map.has(vertex.x)
        inst_map.set(vertex.x, vertex.y)
        if do_sort:
            inst_map.sort()
        print('New instance of %d: %s' % [instance.id, inst_map])

    data.get(instance.id).closest = vertex
