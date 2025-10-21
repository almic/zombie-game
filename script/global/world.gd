extends Node

const GROUP_RESET_RATE = 5
var group_reset_ticks: int = 0

var group_nodes: Dictionary[StringName, Array] = {}

const SOUND_GROUP_PREFIX = &'sound_group:'

var Printer := preload("uid://dao0mebio8ua7")
var Sounds := preload("uid://bq40usjnjtfva")


## TODO: this is probably not implemented correctly for saving, please revisit
@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_STORAGE)
var game_time: int
var game_time_frac: float


func _physics_process(delta: float) -> void:
    group_reset_ticks += 1
    if group_reset_ticks >= GROUP_RESET_RATE:
        group_nodes.clear()
        group_reset_ticks = 0

    game_time_frac += delta
    var second_passed: bool = game_time_frac >= 1.0
    while game_time_frac >= 1.0:
        game_time += 1
        game_time_frac -= 1.0

    # Things to do once per second
    if second_passed:
        Sounds.trim()


# TODO: make this take all parameters instead of having Sounds pull out the
#       values from the player, that way physics bindings will always have the
#       correct values.
func sound_played(player: PositionalAudioPlayer, loudness: float) -> void:
    # NOTE: For dev only, remove later
    if not Engine.is_in_physics_frame():
        push_error('GlobalWorld.sound_played() can only be called during physics tick! Investigate!')
        return

    # self.print('playing sound from "' + player.name + ('" with loudness: %.2f' % loudness))
    Sounds.add_sound(player, loudness)

func get_sounds_played(
        seconds_in_past: float,
        location: Vector3,
        groups: Array[StringName],
        min_loudness: float,
        max_distance: float,
) -> Array:
    return Sounds.get_sounds(
            seconds_in_past,
            location,
            groups,
            min_loudness,
            max_distance,
    )

func get_nodes_in_group(group: StringName) -> Array[Node]:

    var nodes: Array[Node]
    if not group_nodes.has(group):
        nodes = get_tree().get_nodes_in_group(group)
        group_nodes.set(group, nodes)
    else:
        nodes = group_nodes.get(group)

    return nodes

func get_nodes_in_groups(groups: Array[StringName]) -> Array[Node]:

    # TODO: defer to single group call when array has 1 element
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

func get_closest_nodes_in_group(location: Vector3, count: int, group: StringName) -> Array[Node3D]:
    var nodes: Array[Node3D]
    for node in get_nodes_in_group(group):
        if is_instance_valid(node) and is_instance_of(node, Node3D):
            nodes.append(node)

    nodes.sort_custom(func(a: Node3D, b: Node3D):
        return a.global_position.distance_squared_to(location) < b.global_position.distance_squared_to(location)
    )

    nodes.resize(count)
    return nodes

## Get the current game time with fractional seconds
func get_game_time() -> float:
    return game_time + game_time_frac

## Returns the DynamicDay in the current scene
func get_day_time() -> DynamicDay:
    var world: World = get_tree().current_scene as World
    if not world:
        return null

    return world.find_child("DynamicDay", false) as DynamicDay

## Print a message with the game time prepended
func print(message: String) -> void:
    Printer._print(('[%.4f] ' % (game_time + game_time_frac)) + message)
