@tool
class_name TerrainInstanceRegion extends Node3D


const INT_MAX: int = Vector2i.MAX.x
const CHUNK_SIZE: int = 16
const TerrainInstanceTemporary = preload("uid://dumv2y8oq3f1x")


@export var seed: int

@export_tool_button('Randomize Seed', 'RandomNumberGenerator')
var btn_randomize_seed = func():
    randomize()
    seed = randi()

@export
var settings: TerrainInstanceRegionSettings

var instance_node: TerrainInstanceNode

var shapes: Array[TerrainRegionPolygon]

var _update_shapes: bool = true
var _show_gizmo: bool = false
var _last_shape: TerrainRegionPolygon = null
var _solo_shape: bool = false


func _notification(what: int) -> void:
    if what == NOTIFICATION_EDITOR_PRE_SAVE:
        save_temporary_instances()

func _ready() -> void:
    # NOTE: should never be moving this
    set_meta(&'_edit_lock_', true)
    child_order_changed.connect(on_children_changed)

## Editor function, probably do some validation and maybe a confirmation dialog
func editor_clear_region() -> void:
    clear_region()

## Editor function, probably do some validation and maybe a confirmation dialog
func editor_populate_region() -> void:
    populate_region(true)

func show_gizmos() -> void:
    _show_gizmo = true
    update_gizmos()

func hide_gizmos() -> void:
    _show_gizmo = false
    update_gizmos()

func on_children_changed() -> void:
    if not Engine.is_editor_hint():
        return

    # First, drop any shapes that disappear
    var shapes_copy: Array[TerrainRegionPolygon] = shapes.duplicate()
    for polygon in shapes_copy:
        if polygon.get_parent() != self:
            shapes.erase(polygon)
            if polygon == _last_shape:
                _last_shape = null
            _update_shapes = true

    # Add any new shapes
    for child in get_children():
        if child is TerrainRegionPolygon and (not shapes.has(child)):
            shapes.append(child)
            _update_shapes = true

    update_shapes()

func update_shapes() -> void:
    if not _update_shapes:
        return

    for polygon in shapes:
        if not polygon.changed:
            continue
        polygon.changed = false

        polygon.mesh.clear_surfaces()

        var size: int = polygon.count()
        var verts: PackedVector2Array

        polygon.world_vertices.resize(size)
        verts.resize(size)

        var i: int = 0
        var v: Vector2
        while i < size:
            v = Vector2(polygon.get_vertex(i))
            verts[i] = v
            polygon.world_vertices[i] = instance_node.project_global(v)
            i += 1

        if polygon.count() < 3:
            polygon.triangle_mesh = TriangleMesh.new()
            polygon.triangle_mesh_faces.clear()
            continue

        var indices: PackedInt32Array = Geometry2D.triangulate_polygon(verts)
        if indices.size() == 0:
            polygon.triangle_mesh = TriangleMesh.new()
            polygon.triangle_mesh_faces.clear()
            continue

        var data: Array = []
        data.resize(Mesh.ARRAY_MAX)

        data[Mesh.ARRAY_VERTEX] = polygon.world_vertices
        data[Mesh.ARRAY_INDEX]  = indices

        polygon.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data)

        polygon.triangle_mesh = polygon.mesh.generate_triangle_mesh()
        polygon.triangle_mesh_faces = polygon.triangle_mesh.get_faces()

    _update_shapes = false

## Adds a vertex, returns true if the vertex was added
func add_vertex(vertex: Vector2i, index: int = -1) -> bool:
    if not _last_shape:
        return false

    var size: int = _last_shape.vertices.size()
    if index > size / 2:
        return false

    if index < 0 or index == size / 2:
        _last_shape.vertices.resize(size + 2)
        _last_shape.vertices[size]     = vertex.x
        _last_shape.vertices[size + 1] = vertex.y
    else:
        index *= 2
        # NOTE: insert Y then X
        _last_shape.vertices.insert(index, vertex.y)
        _last_shape.vertices.insert(index, vertex.x)

    _last_shape.changed = true
    _update_shapes = true

    return true

## Test if a vertex exists on any polygons, or just the selected polygon
func has_vertex(vertex: Vector2i, selected_only: bool = false) -> bool:
    if selected_only and (not _last_shape):
        return false
    for polygon in shapes:
        if selected_only and polygon != _last_shape:
            continue
        var size: int = polygon.vertices.size()
        var i: int = 0
        while i < size:
            if polygon.vertices[i] == vertex.x and polygon.vertices[i + 1] == vertex.y:
                return true
            i += 2
    return false

## Set the vertex by id. This does not perform a bounds check.
func set_vertex(index: int, new_vertex: Vector2i) -> void:
    index *= 2
    _last_shape.vertices[index]     = new_vertex.x
    _last_shape.vertices[index + 1] = new_vertex.y
    _last_shape.changed = true
    _update_shapes = true

## Remove a vertex. Also deletes any faces connected to the vertex. This does not
## perform a bounds check.
func remove_vertex(index: int) -> void:
    # NOTE: order matters
    _last_shape.vertices.remove_at(index * 2 + 1)
    _last_shape.vertices.remove_at(index * 2)

    _last_shape.changed = true
    _update_shapes = true

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
    update_shapes()

    if shapes.size() == 0:
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

    var box: AABB = AABB()
    for polygon in shapes:
        box = box.merge(polygon.mesh.get_aabb())
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

                    begin.x = xform.origin.x
                    begin.z = xform.origin.z

                    # Must intersect at least one ADD, and may not intersect any SUBTRACTS
                    var has_add: bool = false
                    var has_subtract: bool = false
                    for polygon in shapes:
                        if polygon.mode == TerrainRegionPolygon.Mode.ADD:
                            if has_add:
                                continue
                            if polygon.triangle_mesh.intersect_ray(begin, dir):
                                has_add = true
                        elif polygon.mode == TerrainRegionPolygon.Mode.SUBTRACT:
                            if polygon.triangle_mesh.intersect_ray(begin, dir):
                                has_subtract = true
                                break

                    if has_subtract or (not has_add):
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

func populate_region(editor_mode: bool = false) -> void:
    var start: int = Time.get_ticks_usec()

    # Ensure triangle mesh is up-to-date
    update_shapes()

    if shapes.size() == 0:
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
    var box: AABB = AABB()
    for polygon in shapes:
        box = box.merge(polygon.mesh.get_aabb())

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

    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    var hash_inst: PackedInt64Array
    var hash_chunk_x: PackedInt64Array
    var hash_chunk_y: PackedInt64Array

    # Precompute instance and chunk coordinate hashes
    var size_x: int = (c_x2 - c_x1) + 1
    var size_y: int = (c_y2 - c_y1) + 1
    var chunks_to_process: int = size_x * size_y

    print('Starting region population, %d chunks with %d instance types' % [chunks_to_process, instances.size()])

    hash_chunk_x.resize(size_x)
    hash_chunk_y.resize(size_y)
    hash_inst.resize(instances.size())
    for i in range(size_x):
        hash_chunk_x[i] = hash((c_x1 + i) * seed)
    for i in range(size_y):
        hash_chunk_y[i] = hash((c_y1 + i) * 3_372_734_527)
    for i in range(instances.size()):
        hash_inst[i] = hash(seed ^ instances[i].seed)

    var i_hash: int
    var y_hash: int

    var inst_index: int = 0
    for instance in instances:
        var xforms: Array[Transform3D]
        var colors: PackedColorArray
        var instance_total: int = 0

        i_hash = hash_inst[inst_index]
        inst_index += 1

        chunk.y = c_y1
        var y_index: int = 0
        var x_index: int
        while chunk.y <= c_y2:
            chunk.x = c_x1
            y_hash = i_hash ^ hash_chunk_y[y_index]
            y_index += 1
            x_index = 0
            while chunk.x <= c_x2:
                rng.seed = y_hash ^ hash_chunk_x[x_index]
                x_index += 1
                var count_added: int = _populate_chunk(rng, instance, chunk, chunks)
                if count_added > 0:
                    var positions: Array[Vector3] = chunks.get(instance.id).get(chunk)
                    xforms.resize(xforms.size() + count_added)
                    colors.resize(colors.size() + count_added)

                    var i: int = 0
                    while i < count_added:
                        var xform: Transform3D = Transform3D.IDENTITY
                        xform.origin = positions[i]
                        xform.origin.y += instance.rand_height(rng)

                        xform.basis = xform.basis.rotated(Vector3.DOWN, instance.rand_spin(rng))

                        var tilt_amount: float = instance.rand_tilt(rng)
                        if not is_zero_approx(tilt_amount):
                            var tilt_basis: Basis = Basis.IDENTITY
                            tilt_basis = tilt_basis.rotated(Vector3.UP, rng.randf_range(0, TAU))
                            tilt_basis = tilt_basis.rotated(-tilt_basis.z, tilt_amount)
                            xform.basis = tilt_basis * xform.basis

                        var scale_amount: float = instance.rand_scale(rng)
                        if not is_equal_approx(scale_amount, 1.0):
                            xform = xform.scaled_local(Vector3(scale_amount, scale_amount, scale_amount))

                        xforms[i + instance_total] = xform
                        colors[i + instance_total] = instance.rand_color(rng).srgb_to_linear()
                        i += 1

                instance_total += count_added
                full_total += count_added

                chunk.x += 1
                if not editor_mode:
                    continue

                chunk_total += 1
                if chunk_total % (2048 * instances.size()) == 0:
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

    if editor_mode:
        print(
                'Populated %d instances in %.3f seconds' % [
                    full_total,
                    float(end - start) / 1e6
                ]
        )
        start = Time.get_ticks_usec()

    # Add instances to terrain
    instance_node.add_instances(data)

    if editor_mode:
        end = Time.get_ticks_usec()
        print('Terrain updated in %.3f seconds' % [float(end - start) / 1e6])

func _populate_chunk(
        rng: RandomNumberGenerator,
        instance: TerrainInstanceSettings,
        chunk: Vector2i,
        chunks: Dictionary,
) -> int:
    var count: int = roundi(rng.randfn(instance.density, instance.density_deviation))
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
        var slope_prob: float = rng.randf()
        pos.x = minf(rng.randf() * CHUNK_SIZE, float(CHUNK_SIZE) - 0.0001)
        pos.y = minf(rng.randf() * CHUNK_SIZE, float(CHUNK_SIZE) - 0.0001)

        pos.x += chunk.x * CHUNK_SIZE
        pos.y += chunk.y * CHUNK_SIZE

        ray_pos.x = pos.x
        ray_pos.z = pos.y

        # Must intersect at least one ADD, and may not intersect any SUBTRACTS
        var has_add: bool = false
        var has_subtract: bool = false
        for polygon in shapes:
            if polygon.mode == TerrainRegionPolygon.Mode.ADD:
                if has_add:
                    continue
                if polygon.triangle_mesh.intersect_ray(ray_pos, dir):
                    has_add = true
            elif polygon.mode == TerrainRegionPolygon.Mode.SUBTRACT:
                if polygon.triangle_mesh.intersect_ray(ray_pos, dir):
                    has_subtract = true
                    break

        if has_subtract or (not has_add):
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

            if slope_prob > probability:
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
