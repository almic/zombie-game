extends Node

const GROUP_RESET_RATE = 5
var group_reset_ticks: int = 0

var group_nodes: Dictionary[StringName, Array] = {}

## TODO: this is probably not implemented correctly for saving, please revisit
@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_STORAGE)
var game_time: int
var _second_delta: float


func _physics_process(delta: float) -> void:
    group_reset_ticks += 1
    if group_reset_ticks >= GROUP_RESET_RATE:
        group_nodes.clear()
        group_reset_ticks = 0

    _second_delta += delta
    while _second_delta >= 1.0:
        game_time += 1
        _second_delta -= 1.0


func get_nodes_in_group(group: StringName) -> Array[Node]:

    if not group_nodes.has(group):
        var nodes: Array[Node] = get_tree().get_nodes_in_group(group)
        group_nodes.set(group, nodes)

    return group_nodes.get(group)


func get_nodes_in_groups(groups: Array[StringName]) -> Array[Node]:

    const PREFIX = "_MULTIGROUP:"

    var groups_sorted: Array[StringName] = groups.duplicate()
    groups_sorted.sort()

    var key: StringName = PREFIX + ";".join(groups_sorted)
    if not group_nodes.has(key):
        var multi_group: Array[Node] = []
        var nodes: Array[Node]
        for group in groups:
            nodes = get_nodes_in_group(group)
            multi_group.append_array(nodes)
        group_nodes.set(key, multi_group)

    return group_nodes.get(key)

## Returns the DynamicDay in the current scene
func get_day_time() -> DynamicDay:
    var world: World = get_tree().current_scene as World
    if not world:
        return null

    return world.find_child("DynamicDay", false) as DynamicDay
