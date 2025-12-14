@tool
class_name TerrainInstanceNode extends Node


## Terrain node to manage instancing for
@export
var terrain: Node:
    set(value):
        terrain = value
        update_configuration_warnings()

@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_NO_EDITOR)
var regions: Array[TerrainInstanceRegion] = []

@export_tool_button("Add Region") var button_add_region = add_region
@export_tool_button("Clear Regions") var button_clear_regions = clear_regions

var active_region: TerrainInstanceRegion = null


func _ready() -> void:
    setup_terrain.call_deferred()

func _get_configuration_warnings() -> PackedStringArray:
    if not terrain:
        return [
            "This node must have a parent type of 'Terrain3D' to function!"
        ]
    return []

func _notification(what: int) -> void:
    if what == NOTIFICATION_PARENTED:
        setup_terrain()

func setup_terrain() -> void:
    if terrain != null:
        update_configuration_warnings()
        return

    var parent: Node = get_parent()
    if not parent:
        update_configuration_warnings()
        return

    # For Terrain3D
    if parent.get_class() == &'Terrain3D':
        terrain = parent
        return

    update_configuration_warnings()

## Given a ray origin and direction, finds the point of intersection on the
## terrain.
func intersect_terrain(origin: Vector3, direction: Vector3) -> Vector3:
    if not terrain:
        return Vector3.INF

    if terrain.get_class() == &'Terrain3D':
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

    if terrain.get_class() == &'Terrain3D':
        return Vector2(point / terrain.vertex_spacing)

    return Vector2.INF

## Given a point in terrain vertex space, returns the world 3D position.
func project_global(point: Vector2) -> Vector3:
    if not terrain:
        return Vector3.INF

    if terrain.get_class() == &'Terrain3D':
        var pos: Vector3 = Vector3(point.x, 0.0, point.y)
        pos = pos * terrain.vertex_spacing
        pos.y = terrain.data.get_height(pos)
        if is_nan(pos.y):
            return Vector3.INF
        return pos

    return Vector3.INF

func add_region() -> void:
    active_region = TerrainInstanceRegion.new()
    regions.append(active_region)

func clear_regions() -> void:
    active_region = null
    regions.clear()
