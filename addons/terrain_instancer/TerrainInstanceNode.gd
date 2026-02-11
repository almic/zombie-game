@tool
class_name TerrainInstanceNode extends Node3D


const Plugin = preload("uid://khsyydwj7rw2")


## Terrain node to manage instancing for
@export
var terrain: Node:
    set(value):
        terrain = value
        update_configuration_warnings()


@export_tool_button("Update Regions") var button_update_region = update_regions


@export_group("Collision Targets", "target")

@export_custom(PROPERTY_HINT_GROUP_ENABLE, 'checkbox_only')
var target_groups_enabled: bool = false

## Update target nodes for editor debugging
@export_tool_button('Update Targets', 'Loop')
var target_btn_update_targets = update_target_nodes

## Groups to build instance collision around, the value is the distance in
## meters around nodes in that group.
@export_custom(PROPERTY_HINT_DICTIONARY_TYPE, 'StringName;2/1:1,16,1')
var target_groups: Dictionary = {}


var regions: Array[TerrainInstanceRegion] = []


## Key Node3D to Value { snapped: Vector2i, cache: Variant, radius: int, modified: bool }
var node_data: Dictionary


func _ready() -> void:
    # NOTE: should never be moving this
    set_meta(&'_edit_lock_', true)

    setup_terrain.call_deferred()

    update_regions()
    update_target_nodes()

    get_tree().node_added.connect(on_node_added)
    get_tree().node_removed.connect(on_node_removed)

func _get_configuration_warnings() -> PackedStringArray:
    if not terrain:
        return [
            "This node must have a parent type of 'Terrain3D' to function!"
        ]
    return []

func _notification(what: int) -> void:
    if what == NOTIFICATION_PARENTED:
        setup_terrain()

func _physics_process(delta: float) -> void:
    if not target_groups_enabled:
        return

    update_tracked_node_locations()

    # Using current node target locations, prepares data for a collsion update
    var data = get_instance_collision_data()

    # Queues the collision update using prepared instance collision data
    if data != null:
        dispatch_instance_collision_update(data)

func setup_terrain() -> void:
    if terrain != null:
        update_configuration_warnings()
        return

    var parent: Node = get_parent()
    if not parent:
        update_configuration_warnings()
        return

    # For Terrain3D
    if parent.get_class() == Plugin.CLASS_TERRAIN3D:
        terrain = parent
        # Terrain3DCollision.InstanceCollisionMode::INSTANCE_COLLISION_MANUAL
        terrain.collision_mode = 3

    update_configuration_warnings()

func create_node_data() -> Dictionary:
    return {
            snapped = Vector2i.MAX,
            cache = null,
            radius = 0,
            modified = false,
    }

func assign_region(region: TerrainInstanceRegion) -> void:
    region.instance_node = self
    regions.append(region)

func update_regions() -> void:
    regions.clear()

    var children: Array[Node] = get_children()
    while not children.is_empty():
        var child: Node = children.pop_front()
        if child.get_child_count() > 0:
            children.append_array(child.get_children())
        if child is TerrainInstanceRegion:
            assign_region(child)

## Update tracking list. Call this when changing target_groups.
func update_target_nodes() -> void:
    node_data.clear()

    if not is_inside_tree():
        return

    var tree: SceneTree = get_tree()

    for group in target_groups:
        for node in tree.get_nodes_in_group(group):
            if node is not Node3D:
                continue
            if node_data.has(node):
                continue

            var data: Dictionary = create_node_data()
            data.radius = target_groups.get(group)
            data.modified = true
            node_data.set(node, data)

## Computes new locations for all tracked nodes
func update_tracked_node_locations() -> void:
    for node in node_data:
        if node is Node3D:
            var data: Dictionary = node_data.get(node)
            var new_pos: Vector2i = snap_terrain(node.global_position)

            if data.snapped == new_pos:
                continue

            data.snapped = new_pos
            data.modified = true

## Compute instance collision data, should be passed directly to
## dispatch_instance_collision_update()
func get_instance_collision_data() -> Variant:
    if not terrain:
        return null

    if terrain.get_class() == Plugin.CLASS_TERRAIN3D:
        # Produce an array of cells to have collision for
        # Using a dictionary for optimized set-like behavior
        var cell_set: Dictionary

        # Some constants
        const cell_size: int = 32
        const cell_max_size: Vector2 = Vector2(cell_size, cell_size)
        var region_size: int = terrain.region_size
        var cells_per_region: int = region_size / cell_size
        var vertex_spacing: float = terrain.vertex_spacing

        for node in node_data:
            var data: Dictionary = node_data[node]

            # If not modified and cache exists, add the cells from cache
            if (not data.modified) and data.cache != null:
                for cell in data.cache:
                    cell_set[cell] = null
                continue

            var cache: Array[Vector2i]
            if data.cache == null:
                data.cache = cache
            else:
                cache = data.cache
                cache.clear()

            # Reset modified flag
            data.modified = false

            var snapped_pos: Vector2i = data.snapped
            if snapped_pos == Vector2i.MAX:
                continue

            var radius: float = data.radius
            if radius < 1.0:
                continue

            radius /= vertex_spacing

            var radius_sq: float = radius * radius
            var cell_radius: int = ceili(radius / float(cell_size))

            var x: int = -cell_radius
            var y: int

            while x <= cell_radius:
                y = -cell_radius

                while y <= cell_radius:
                    var grid_pos: Vector2i = snapped_pos + Vector2i(x * cell_size, y * cell_size)
                    var region_loc: Vector2i = _v2i_divide_floor(grid_pos, region_size)

                    var region: Resource = terrain.data.get_region(region_loc)
                    if (not region) or region.is_deleted():
                        y += 1
                        continue

                    var region_local_coord: Vector2i = grid_pos - (region_loc * region_size)
                    var local_cell: Vector2i = _v2i_divide_floor(region_local_coord, cell_size)
                    var cell_loc: Vector2i = region_loc * cells_per_region + local_cell

                    var cell_min: Vector2 = Vector2(cell_loc) * float(cell_size)
                    var cell_max: Vector2 = cell_min + cell_max_size

                    var closest: Vector2 = Vector2(
                        clampf(snapped_pos.x, cell_min.x, cell_max.x),
                        clampf(snapped_pos.y, cell_min.y, cell_max.y)
                    )

                    if (closest - Vector2(snapped_pos)).length_squared() > radius_sq:
                        y += 1
                        continue

                    cache.append(cell_loc)
                    cell_set[cell_loc] = null

                    y += 1

                x += 1

        var cells_array: Array[Vector2i]
        cells_array.assign(cell_set.keys())
        return cells_array

    return null

func dispatch_instance_collision_update(data: Variant) -> void:
    if not terrain:
        return

    if terrain.get_class() == Plugin.CLASS_TERRAIN3D:
        if terrain.collision.instance_collision_mode == 3: # INSTANCE_COLLISION_MANUAL
            terrain.collision.set_instance_collision_cells(data)
        return

## Given a ray origin and direction, finds the point of intersection on the
## terrain. Returns Vector3.INF when it doesn't intersect terrain.
func intersect_terrain(origin: Vector3, direction: Vector3) -> Vector3:
    if not terrain:
        return Vector3.INF

    if terrain.get_class() == Plugin.CLASS_TERRAIN3D:
        var pos: Vector3 = terrain.get_intersection(origin, direction, true)
        if pos.z > 3.4e38 or is_nan(pos.y):
            return Vector3.INF
        return pos

    return Vector3.INF

## Given a point in world 2D space, returns the corresponding point in terrain
## vertex space.
func project_terrain(point: Vector2) -> Vector2:
    if not terrain:
        return Vector2.INF

    if terrain.get_class() == Plugin.CLASS_TERRAIN3D:
        return Vector2(point / terrain.vertex_spacing)

    return Vector2.INF

## Given a point in terrain vertex space, returns the world 3D position.
func project_global(point: Vector2) -> Vector3:
    if not terrain:
        return Vector3.INF

    if terrain.get_class() == Plugin.CLASS_TERRAIN3D:
        var pos: Vector3 = Vector3(point.x, 0.0, point.y)
        pos = pos * terrain.vertex_spacing
        pos.y = terrain.data.get_height(pos)
        if is_nan(pos.y):
            return Vector3.INF
        return pos

    return Vector3.INF

## Given a location, returns a snapped Vector2i position to be used for
## instance collision generation
func snap_terrain(location: Vector3) -> Vector2i:
    if not terrain:
        return Vector2i.MAX

    if terrain.get_class() == Plugin.CLASS_TERRAIN3D:
        location /= terrain.vertex_spacing
        var shape_size: int = terrain.collision_shape_size
        return Vector2i(
                floori(location.x / float(shape_size) + 0.5),
                floori(location.z / float(shape_size) + 0.5)
        ) * shape_size

    return Vector2i.MAX

## Test if a point in world 2D space maps to a height on the terrain, i.e.
## passing this point to the method get_height() /should/ return a finite value
func terrain_has(point: Vector2) -> bool:
    if not terrain:
        return false

    if terrain.get_class() == Plugin.CLASS_TERRAIN3D:
        # Annoyingly, hole test returns FALSE when outside of regions!
        var pos := Vector3(point.x, 0, point.y)
        if terrain.data.get_control(pos) == 4294967295:
            # Outside of terrain
            return false
        return (not terrain.data.get_control_hole(pos))

    return false

## Get the height of a point on the terrain from world 2D space, returns NAN if
## the point is invalid for the terrain
func get_height(point: Vector2) -> float:
    if not terrain:
        return NAN

    if terrain.get_class() == Plugin.CLASS_TERRAIN3D:
        return terrain.data.get_height(Vector3(point.x, 0.0, point.y))

    return NAN

## Get the normal of a point on the terrain from world 2D space. Returns a zero
## vector if the point is invalid for the terrain
func get_normal(point: Vector2) -> Vector3:
    if not terrain:
        return Vector3.ZERO

    if terrain.get_class() == Plugin.CLASS_TERRAIN3D:
        var n: Vector3 = terrain.data.get_normal(Vector3(point.x, 0.0, point.y))
        if n.is_finite():
            return n
        return Vector3.ZERO

    return Vector3.ZERO

## Return an array of indexes that can be used to access and modify instance data
func get_instance_indexes(area: Rect2) -> Array:
    if not terrain:
        return []

    # Terrain3D indexes is an array of region locations
    if terrain.get_class() == Plugin.CLASS_TERRAIN3D:
        var vertex_spacing: float = terrain.vertex_spacing
        var region_size: int = terrain.region_size
        var region_scale: float = region_size * vertex_spacing

        # Snap area to regions
        var x1: int = floori(area.position.x / region_scale)
        var y1: int = floori(area.position.y / region_scale)
        var x2: int = ceili(area.end.x / region_scale)
        var y2: int = ceili(area.end.y / region_scale)

        var indexes: Array[Vector2i]

        var loc: Vector2i
        var x: int = x1
        var y: int
        while x < x2:
            loc.x = x
            y = y1
            while y < y2:
                loc.y = y
                if terrain.data.has_region(loc):
                    indexes.append(loc)
                y += 1
            x += 1

        return indexes

    return []

## Obtain instance data from an instance data index, obtained from a call to
## 'get_instance_indexes()'. After modifying, call 'set_instance_data()'.
## {
##     id: int {
##         cell: Vector2i {
##             xform: Array[Transform3D],
##             color: PackedColorArray,
##         }
##     }
## }
func get_instance_data(index: Variant) -> Dictionary:
    if not terrain:
        return {}

    if terrain.get_class() == Plugin.CLASS_TERRAIN3D:
        # Index is a region location
        var vertex_spacing: float = terrain.vertex_spacing
        var region_size: int = terrain.region_size

        var region = terrain.data.get_region(index)
        if (not region) or region.is_deleted():
            return {}

        var region_global_offset := Vector3(
            region.location.x * region_size * vertex_spacing,
            0.0,
            region.location.y * region_size * vertex_spacing
        )

        var data: Dictionary
        for mesh_id in region.instances:
            var inst_data: Dictionary = data.get_or_add(mesh_id, Dictionary())
            var cells: Dictionary = region.instances.get(mesh_id)
            for cell in cells:
                inst_data.set(cell, {
                    &'xform': Array(),
                    &'color': null, # Will set later
                })
                var cell_data: Dictionary = inst_data.get(cell)

                var r_data: Array = cells[cell]

                # Translate region-local offsets to global
                var r_xforms: Array = r_data[0]
                var xform_data: Array = cell_data[&'xform']
                xform_data.resize(r_xforms.size())

                for i in range(r_xforms.size()):
                    xform_data[i] = r_xforms[i].translated(region_global_offset)

                cell_data[&'color'] = r_data[1].duplicate()

        return data

    return {}

## Apply instance data in bulk, accepts an array of indexes and an equally sized
## array of data which matches to each index. Set as much as possible to gain
## the benefits of bulk updates.
func set_instance_data(indexes: Array, data: Array[Dictionary]) -> void:
    if not terrain:
        return

    if terrain.get_class() == Plugin.CLASS_TERRAIN3D:
        for i in range(indexes.size()):
            var region_loc: Vector2i = indexes[i]
            var region = terrain.data.get_region(region_loc)
            if (not region) or region.is_deleted():
                continue

            var region_data: Dictionary = data[i]
            for mesh_id in region_data:
                var r_instances: Dictionary = region.instances.get(mesh_id)

                var cell_data: Dictionary = region_data.get(mesh_id)
                var xforms: Array[Transform3D]
                var colors: PackedColorArray

                for cell in cell_data:
                    # Clear the old cell data
                    if r_instances and r_instances.has(cell):
                        var r_data: Array = r_instances.get(cell)
                        r_data[0] = Array()
                        r_data[1] = PackedColorArray()
                        r_data[2] = true
                        terrain.instancer.update_mmis(mesh_id, region_loc)

                    # Copy data
                    var inst_data: Dictionary = cell_data.get(cell)
                    xforms.append_array(inst_data.get(&'xform'))
                    colors.append_array(inst_data.get(&'color'))

                terrain.instancer.add_transforms(mesh_id, xforms, colors, true)

        return

    return

func add_instances(instance_data: Dictionary) -> void:
    if not terrain:
        return

    if terrain.get_class() == Plugin.CLASS_TERRAIN3D:
        for id in instance_data:
            var data: Dictionary = instance_data.get(id)
            terrain.instancer.add_transforms(
                    id,
                    data[&'xforms'],
                    data[&'colors'],
                    true
            )
        return

    return

## Get the user-specified name of an instance, returns the number as a string
## if it does not exist or has an empty name.
func get_instance_name(instance_id: int) -> String:
    if not terrain:
        return str(instance_id)

    if terrain.get_class() == Plugin.CLASS_TERRAIN3D:
        var asset = terrain.assets.get_mesh_asset(instance_id)
        if not asset:
            return str(instance_id)

        var n: String = asset.name
        if not n:
            return str(instance_id)
        return n

    return str(instance_id)

## Get the mesh of an instance, optionally at a given LOD
func get_instance_lod_mesh(instance_id: int, lod: int = 0) -> Mesh:
    if not terrain:
        return null

    if terrain.get_class() == Plugin.CLASS_TERRAIN3D:
        var asset = terrain.assets.get_mesh_asset(instance_id)
        if not asset:
            return null

        return asset.get_mesh(lod)

    return null

## Get a thumbnail image of an instance, useful for UI elements
func get_instance_scene(instance_id: int) -> PackedScene:
    if not terrain:
        return null

    if terrain.get_class() == Plugin.CLASS_TERRAIN3D:
        var asset = terrain.assets.get_mesh_asset(instance_id)
        if not asset:
            return null

        return asset.scene_file

    return null

func show_gizmos() -> void:
    for region in regions:
        region.show_gizmos()

func hide_gizmos() -> void:
    for region in regions:
        region.hide_gizmos()

func on_node_added(node: Node) -> void:
    if node is TerrainInstanceRegion:
        var top: Node = get_tree().current_scene
        var next: Node = node.get_parent()
        var max_count: int = 7
        while max_count > 0 and next and next != top:
            if next is TerrainInstanceNode:
                if next == self:
                    assign_region(node)
                return
            next = next.get_parent()
            max_count -= 1
        return

    if node is Node3D:
        if node_data.has(node):
            return

        for group in node.get_groups():
            if target_groups.has(group):
                var data: Dictionary = create_node_data()
                data.radius = target_groups.get(group)
                data.modified = true
                node_data.set(node, data)
                return

func on_node_removed(node: Node) -> void:
    node_data.erase(node)

#region Utility methods for some stuff

# From Terrain3D
func _int_divide_floor(n: int, d: int) -> int:
    # T result = ((numer) < 0) != ((denom) < 0) ? ((numer) - ((denom) < 0 ? (denom) + 1 : (denom)-1)) / (denom) : (numer) / (denom);
    if (n < 0) != (d < 0):
        if d < 0:
            return (n - (d + 1)) / d
        return (n - (d - 1)) / d
    return n / d

func _v2i_divide_floor(v: Vector2i, d: int) -> Vector2i:
    #define V2I_DIVIDE_FLOOR(v, f) Vector2i(int_divide_floor(v.x, int32_t(f)), int_divide_floor(v.y, int32_t(f)))
    return Vector2i(_int_divide_floor(v.x, d), _int_divide_floor(v.y, d))

#endregion
