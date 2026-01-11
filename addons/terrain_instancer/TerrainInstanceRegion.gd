@tool
class_name TerrainInstanceRegion extends Node3D


const INT_MAX: int = Vector2i.MAX.x
const CHUNK_SIZE: int = 16
const TerrainInstanceTemporary = preload("uid://dumv2y8oq3f1x")


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

        save_temporary_instances()

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

func save_temporary_instances() -> void:
    if not instance_node:
        return

    var temps: Array[TerrainInstanceTemporary]
    for child in get_children():
        if child is TerrainInstanceTemporary:
            temps.append(child)

    if not temps:
        return

    var data: Dictionary
    for temp_inst in temps:
        var id: int = temp_inst.instance_id
        var color: Color = temp_inst.instance_color
        var xform: Transform3D = temp_inst.global_transform

        if not data.has(id):
            var xforms: Array[Transform3D] = [xform]
            var colors: PackedColorArray = [color]
            data.set(id, { &'xforms': xforms, &'colors': colors })
            continue

        var inst_data: Dictionary = data.get(id)
        var xforms: Array[Transform3D] = inst_data.get(&'xforms')
        var colors: PackedColorArray = inst_data.get(&'colors')

        xforms.append(xform)
        colors.append(color)

        inst_data.set(&'xforms', xforms)
        inst_data.set(&'colors', colors)

    instance_node.add_instances(data)

    for child in temps:
        child.owner = null
        remove_child.call_deferred(child)

## Attempts to edit the closest managed instance to 'near'. Creates and adds a
## temporary instance child, and selects it. Returns false if no instance could
## be edited.
func edit_instance(near: Vector3) -> bool:
    if (not instance_node) or (not settings):
        return false

    if not near.is_finite():
        return false

    # Build set of instance types to manage
    var ids: Array[int]
    for inst in settings.instances:
        if ids.has(inst.id):
            continue
        ids.append(inst.id)

    if ids.size() == 0:
        return false

    var area: Rect2 = Rect2(near.x - 1.0, near.z - 1.0, 2.0, 2.0)
    var indexes: Array = instance_node.get_instance_indexes(area)

    var nearest_sq_dist: float = INF
    var nearest_index: Variant
    var nearest_inst_id: int
    var nearest_cell_id: Vector2i
    var nearest_mesh_id: int
    var nearest_mesh_data: Dictionary
    var nearest_xform: Transform3D
    var nearest_color: Color

    for index in indexes:
        var inst_data: Dictionary = instance_node.get_instance_data(index)
        for inst_id in inst_data:
            if not ids.has(inst_id):
                continue

            var cell_data: Dictionary = inst_data.get(inst_id)
            for cell in cell_data:
                var mesh_data: Dictionary = cell_data.get(cell)
                var xforms: Array = mesh_data.get(&'xform')
                var i: int = 0
                var size: int = xforms.size()
                while i < size:
                    var xform: Transform3D = xforms[i]

                    if not area.has_point(Vector2(xform.origin.x, xform.origin.z)):
                        i += 1
                        continue

                    var dist_sq: float = near.distance_squared_to(xform.origin)
                    if dist_sq >= nearest_sq_dist:
                        i += 1
                        continue

                    nearest_sq_dist = dist_sq
                    nearest_index = index
                    nearest_inst_id = inst_id
                    nearest_cell_id = cell
                    nearest_mesh_id = i
                    nearest_mesh_data = mesh_data
                    nearest_xform = xform

                    var colors: PackedColorArray = mesh_data.get(&'color')
                    if colors.size() > i:
                        nearest_color = colors[i]
                    else:
                        nearest_color = Color.WHITE

                    i += 1

    if is_inf(nearest_sq_dist):
        return false

    # Remove instance from data and update
    # Only need to provide the one cell we changed
    var new_inst_data: Dictionary
    var new_cell_data: Dictionary

    var new_xforms: Array = nearest_mesh_data.get(&'xform')
    var new_colors: PackedColorArray = nearest_mesh_data.get(&'color')

    new_xforms.remove_at(nearest_mesh_id)
    if new_colors.size() > nearest_mesh_id:
        new_colors.remove_at(nearest_mesh_id)

    new_cell_data.set(nearest_cell_id, { &'xform' : new_xforms, &'color': new_colors })
    new_inst_data.set(nearest_inst_id, new_cell_data)
    instance_node.set_instance_data([nearest_index], [new_inst_data])

    # Create temporary and add child
    var t_instance := TerrainInstanceTemporary.new()
    t_instance.instance_id = nearest_inst_id
    t_instance.instance_color = nearest_color
    t_instance.region = self
    t_instance.name = instance_node.get_instance_name(nearest_inst_id)
    if t_instance.name == str(nearest_inst_id):
        # Use alternative name when defaulting to ID
        t_instance.name = 'T_Instance%d_1' % nearest_inst_id
    add_child(t_instance, true)
    t_instance.owner = self.owner
    t_instance.global_transform = nearest_xform
    EditorInterface.edit_node(t_instance)

    return true

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

    var instances: Array[TerrainInstanceSettings]
    for i in range(settings.instances.size()):
        var inst: TerrainInstanceSettings = settings.instances[i]
        if (not inst.enabled) or inst.id == -1:
            continue

        instances.append(inst)

    if instances.size() == 0:
        EditorInterface.get_editor_toaster().push_toast(
                "No enabled instances, nothing to populate",
                EditorToaster.SEVERITY_WARNING
        )
        return

    # Get the area rect from the mesh AABB
    var box: AABB = mesh.get_aabb().abs()
    var x1: int = box.position.x
    var y1: int = box.position.z
    var x2: int = x1 + box.size.x
    var y2: int = y1 + box.size.z

    # Compute "chunks" that will be populated
    var chunks: Dictionary
    var c_x1: int = floori(float(x1) / 16.0)
    var c_y1: int = floori(float(y1) / 16.0)
    var c_x2: int = ceili(float(x2) / 16.0) - 1
    var c_y2: int = ceili(float(y2) / 16.0) - 1

    var chunk: Vector2i
    var chunk_total: int = 0
    var chunk_max: int = (c_x2 - c_x1 + 1) * (c_y2 - c_y1 + 1) * instances.size()
    var full_total: int = 0
    var data: Dictionary

    for instance in instances:
        var xforms: Array[Transform3D]
        var colors: PackedColorArray
        var instance_total: int = 0

        chunk.y = c_y1
        while chunk.y <= c_y2:
            chunk.x = c_x1
            while chunk.x <= c_x2:
                var count_added: int = _populate_chunk(instance, chunk, chunks)

                if count_added > 0:
                    var positions: Array[Vector3] = chunks.get(instance.id).get(chunk)
                    xforms.resize(xforms.size() + count_added)
                    colors.resize(colors.size() + count_added)

                    var i: int = 0
                    while i < count_added:
                        var xform: Transform3D = Transform3D.IDENTITY
                        xform.origin = positions[i]
                        xform.origin.y += _vary(
                                instance.v_height_offset,
                                instance.v_height_low,
                                instance.v_height_high,
                                instance.v_height_deviation
                        )

                        xform.basis = xform.basis.rotated(
                                Vector3.DOWN,
                                _vary(
                                    instance.v_spin_offset,
                                    instance.v_spin_low,
                                    instance.v_spin_high,
                                    instance.v_spin_deviation
                                )
                        )

                        var tilt_amount: float = _vary(
                                instance.v_tilt_offset,
                                instance.v_tilt_low,
                                instance.v_tilt_high,
                                instance.v_tilt_deviation
                        )
                        if not is_zero_approx(tilt_amount):
                            var tilt_basis: Basis = Basis.IDENTITY
                            tilt_basis = tilt_basis.rotated(Vector3.UP, randf_range(0, TAU))
                            tilt_basis = tilt_basis.rotated(-tilt_basis.z, tilt_amount)
                            xform.basis = tilt_basis * xform.basis

                        var scale_amount: float = _vary(
                                instance.v_scale_multiplier,
                                instance.v_scale_low * instance.v_scale_multiplier,
                                instance.v_scale_high,
                                instance.v_scale_deviation
                        )
                        if not is_equal_approx(scale_amount, 1.0):
                            xform = xform.scaled_local(Vector3(scale_amount, scale_amount, scale_amount))

                        xforms[i + instance_total] = xform
                        colors[i + instance_total] = _vary_color(instance.v_colors)
                        i += 1

                instance_total += count_added
                full_total += count_added

                chunk.x += 1
                chunk_total += 1
                if chunk_total % (10 * instances.size()) == 0:
                    print(
                            '%.1f completed, %d instances total' % [
                                float(chunk_total) / float(chunk_max) * 100.0,
                                full_total
                            ]
                    )

                    await get_tree().process_frame

            chunk.y += 1

        # Save to data
        data.set(instance.id, { &'xforms': xforms, &'colors': colors })

    # NOTE: do not time the terrain placement side
    var end: int = Time.get_ticks_usec()

    print('Populated %d instances in %.3f seconds' % [full_total, float(end - start) / 1e6])

    start = Time.get_ticks_usec()
    # Add instances to terrain
    instance_node.add_instances(data)
    end = Time.get_ticks_usec()

    print('Terrain updated in %.3f seconds' % [float(end - start) / 1e6])

func _populate_chunk(
        instance: TerrainInstanceSettings,
        chunk: Vector2i,
        chunks: Dictionary,
) -> int:
    var count: int = roundi(randfn(instance.density, instance.density_deviation))
    var count_added: int = 0
    var positions: Array[Vector3]
    var our_chunks: Dictionary

    if chunks.has(instance.id):
        our_chunks = chunks.get(instance.id)
        if our_chunks.has(chunk):
            positions = our_chunks.get(chunk)

    var slope_curve: Curve = instance.density_slope

    # Vars for mesh hit testing
    var pos: Vector2
    var ray_pos: Vector3 = Vector3(0, 1e6, 0)
    var dir: Vector3 = Vector3.DOWN

    for i in range(count):
        pos.x = randi_range(0, CHUNK_SIZE - 1) + minf(randf(), 0.999)
        pos.y = randi_range(0, CHUNK_SIZE - 1) + minf(randf(), 0.999)

        pos.x += chunk.x * 16
        pos.y += chunk.y * 16

        ray_pos.x = pos.x
        ray_pos.z = pos.y

        if not triangle_mesh.intersect_ray(ray_pos, dir):
            continue

        if not instance_node.terrain_has(pos):
            continue

        if slope_curve:
            var normal: Vector3 = instance_node.get_normal(pos)
            if normal.is_zero_approx():
                continue
            var angle: float = rad_to_deg(acos(normal.dot(Vector3.UP)))
            var probability: float = slope_curve.sample_baked(angle)

            if is_zero_approx(probability):
                continue

            if randf() > probability:
                continue

        var height: float = instance_node.get_height(pos)
        if is_nan(height):
            continue

        var pos_3d: Vector3 = Vector3(pos.x, height, pos.y)

        if _is_pos_too_close(pos_3d, instance, chunk, chunks):
            continue

        # Place in chunk now
        positions.append(pos_3d)
        our_chunks.set(chunk, positions)

        if not chunks.has(instance.id):
            chunks.set(instance.id, our_chunks)

        count_added += 1

    return count_added

func _is_pos_too_close(
        pos: Vector3,
        instance: TerrainInstanceSettings,
        chunk: Vector2i,
        chunks: Dictionary,
) -> bool:
    var pos2: Vector2 = Vector2(pos.x, pos.z)
    for other_id in instance.minimum_distances:
        var other_chunks: Dictionary = chunks.get(other_id, {})
        if not other_chunks:
            continue

        var minimum_distance: float = instance.minimum_distances.get(other_id)
        var minimum_distance_squared = minimum_distance * minimum_distance

        var chunk_range: int = ceili(minimum_distance / 16.0)
        var x_start: int = chunk.x - chunk_range
        var y_start: int = chunk.y - chunk_range
        var x_end: int = chunk.x + chunk_range
        var y_end: int = chunk.y + chunk_range

        var x: int = x_start
        var y: int
        while x <= x_end:
            y = y_start
            while y <= y_end:
                var positions: Variant = other_chunks.get(Vector2i(x, y))
                if not positions:
                    y += 1
                    continue

                for other_pos in positions:
                    # Ignore height
                    var other2: Vector2 = Vector2(other_pos.x, other_pos.z)
                    if pos2.distance_squared_to(other2) < minimum_distance_squared:
                        return true

                y += 1
            x += 1

    return false

func _vary(base: float, low: float, high: float, d: float) -> float:
    if is_zero_approx(low) and is_zero_approx(high):
        if is_zero_approx(d):
            return base

        return randfn(base, d)

    if is_zero_approx(d):
        return randf_range(base - low, base + high)

    return clampf(randfn(base, d), base - low, base + high)

func _vary_color(colors: Array[TerrainInstanceColorSettings]) -> Color:
    # Compute ticket range
    var max_ticket: int = 0
    for choice in colors:
        max_ticket += choice.weight

    if max_ticket < 1:
        return Color.WHITE

    var ticket: int = randi_range(1, max_ticket)
    var color_setting: TerrainInstanceColorSettings
    for choice in colors:
        ticket -= choice.weight
        if ticket <= 0:
            color_setting = choice

    if not color_setting:
        # Make it clear this was an error
        return Color.PURPLE

    var color: Color = color_setting.color
    var h: float = color.ok_hsl_h
    var s: float = color.ok_hsl_s
    var l: float = color.ok_hsl_l

    if not is_zero_approx(color_setting.hue_deviation):
        h += clampf(
                randfn(0.0, color_setting.hue_deviation),
                -color_setting.hue_variation,
                 color_setting.hue_variation,
        )
    else:
        h += randf_range(
                -color_setting.hue_variation,
                 color_setting.hue_variation
        )

    if not is_zero_approx(color_setting.lit_deviation):
        l += clampf(
                randfn(0.0, color_setting.lit_deviation),
                -color_setting.lit_variation,
                 color_setting.lit_variation,
        )
    else:
        l += randf_range(
                -color_setting.lit_variation,
                 color_setting.lit_variation
        )

    if not is_zero_approx(color_setting.sat_deviation):
        s += clampf(
                randfn(0.0, color_setting.sat_deviation),
                -color_setting.sat_variation,
                 color_setting.sat_variation,
        )
    else:
        s += randf_range(
                -color_setting.sat_variation,
                 color_setting.sat_variation
        )

    return Color.from_ok_hsl(h, s, l)
