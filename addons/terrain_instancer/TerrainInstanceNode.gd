@tool
class_name TerrainInstanceNode extends Node3D


const CLASS_TERRAIN3D: StringName = &'Terrain3D'


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
var region_ids: Dictionary = {}


## Key Node3D to Value { snapped: Vector2i, cache: Variant, radius: int, modified: bool }
var node_data: Dictionary


func _ready() -> void:
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
    if parent.get_class() == CLASS_TERRAIN3D:
        terrain = parent
        # Terrain3DCollision.InstanceCollisionMode::INSTANCE_COLLISION_MANUAL
        terrain.collision_mode = 3

        for region in regions:
            load_region_data(region)

    update_configuration_warnings()

func create_node_data() -> Dictionary:
    return {
            snapped = Vector2i.MAX,
            cache = null,
            radius = 0,
            modified = false,
    }

func assign_region(region: TerrainInstanceRegion) -> void:
    if region.region_id == 0:
        var id: int = -1
        var max_attempts: int = 50
        while max_attempts > 0:
            var test_id: int = (randi() % 9900) + 100
            if not region_ids.has(test_id):
                id = test_id
                break
            max_attempts -= 1
        if id == -1:
            push_error('Exceeded 50 attepmts to produce a unique ID for region %s! Manual intervention required.' % region)
            return
        region.region_id = id
    elif region_ids.has(region.region_id):
        push_error('Adding region with existing id %d! Manual intervention required.' % region.region_id)
        return

    region_ids.set(region.region_id, null)

    # If we have terrain now, load the region data.
    # If not, it should be assigned later when the terrain is available
    if terrain:
        load_region_data(region)

    region.instance_node = self
    regions.append(region)

func update_regions() -> void:
    regions.clear()
    region_ids.clear()

    var children: Array[Node] = get_children()
    while not children.is_empty():
        var child: Node = children.pop_front()
        if child.get_child_count() > 0:
            children.append_array(child.get_children())
        if child is TerrainInstanceRegion:
            assign_region(child)

func load_region_data(region: TerrainInstanceRegion) -> void:
    if region.region_id == 0:
        push_error('Attempted to load data for region with no ID!')
        return

    if terrain.get_class() == CLASS_TERRAIN3D:
        var directory: String = terrain.data_directory + '/'
        var file_path: String = directory + ('ird_%04d.res' % region.region_id)
        var data: TerrainInstanceRegionData
        if ResourceLoader.exists(file_path):
            data = ResourceLoader.load(file_path, '', ResourceLoader.CACHE_MODE_IGNORE)
            print('loaded data "%s": %s' % [file_path, data])
            print(data.vertices.duplicate())
            print(data.indexes.duplicate())
        else:
            data = TerrainInstanceRegionData.new()
            data.take_over_path(file_path)
            ResourceSaver.save(data, file_path)
            print('new data "%s": %s' % [file_path, data])
        region.set_data(data)
        return

    push_warning('No terrain loaded, cannot provide regions with data')

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

    print(node_data)

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

    if terrain.get_class() == CLASS_TERRAIN3D:
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

    if terrain.get_class() == CLASS_TERRAIN3D:
        terrain.collision.set_instance_collision_cells(data)
        return

## Given a ray origin and direction, finds the point of intersection on the
## terrain.
func intersect_terrain(origin: Vector3, direction: Vector3) -> Vector3:
    if not terrain:
        return Vector3.INF

    if terrain.get_class() == CLASS_TERRAIN3D:
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

    if terrain.get_class() == CLASS_TERRAIN3D:
        return Vector2(point / terrain.vertex_spacing)

    return Vector2.INF

## Given a point in terrain vertex space, returns the world 3D position.
func project_global(point: Vector2) -> Vector3:
    if not terrain:
        return Vector3.INF

    if terrain.get_class() == CLASS_TERRAIN3D:
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

    if terrain.get_class() == CLASS_TERRAIN3D:
        location /= terrain.vertex_spacing
        var shape_size: int = terrain.collision_shape_size
        return Vector2i(
                floori(location.x / float(shape_size) + 0.5),
                floori(location.z / float(shape_size) + 0.5)
        ) * shape_size

    return Vector2i.MAX

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
