extends Node

const GROUP_RESET_RATE = 5
var group_reset_ticks: int = 0

var group_nodes: Dictionary[StringName, Array] = {}

const SOUND_GROUP_PREFIX = &'sound_group:'

var Groups := preload("uid://cyl7gkx0y7oyu")
var Printer := preload("uid://dao0mebio8ua7")
var Sounds := preload("uid://bq40usjnjtfva")
var Log: TextLog:
    set(value):
        if Log and Log.on_message.is_connected(_handle_log_message):
            Log.on_message.disconnect(_handle_log_message)
        Log = value
        if Log:
            Log.on_message.connect(_handle_log_message)

## TODO: this is probably not implemented correctly for saving, please revisit
@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_STORAGE)
var game_time: int
var game_time_frac: float

var world: World

## Used to strip bbcode tags from text
var _rich_text_helper: RichTextLabel = RichTextLabel.new()


func _ready() -> void:
    # Simply attempt a mouse capture when clicking into the window when capture
    # mode is off
    get_tree().root.window_input.connect(
        func(event: InputEvent):
            if event.is_canceled():
                return
            if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
                return
            if event is InputEventMouseButton:
                if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
                    world.try_capture_mouse(false)
    )

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


## Get the local World node
func get_local_world() -> World:
    return get_nodes_in_group('world').front()

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
    if not world:
        return null

    return world.find_child("DynamicDay", false) as DynamicDay

## Print a message with the game time prepended
func print(message: String, add_game_time: bool = true, skip_log: bool = false, strip_bb: bool = false) -> void:
    var plain_text: String = strip_bbcode(message)

    if strip_bb:
        message = plain_text

    if add_game_time:
        var time: float = get_game_time()
        message = _format_time(time, true) + " " + message
        plain_text = _format_time(time) + " " + plain_text

    Printer._print(plain_text)

    if (not skip_log) and Log:
        Log.add_log(message)

func quit_game() -> void:
    get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
    get_tree().quit()

## Escapes tags from text. Plainly replaces '[' and ']' characters with the
## escaped equivalent '[lb]' and '[rb]' text.
func escape_bbcode(text: String) -> String:
    return RichTextLabel.escape_bbcode(text)

## Removes bbcode tags from text. This essentially wraps a call to
## RichTextLabel.append_text() with 'drop_tags' = true. As such, it does not
## simply delete anything that looks like a tag, so input like "[not_a_tag]"
## would return unchanged. It only drops known tags, and ignores text-outputing
## tags like '[lb]' and '[char=...]'.
func strip_bbcode(text: String) -> String:
    _rich_text_helper.clear()
    _rich_text_helper.append_text(text, true)
    var result: String = _rich_text_helper.get_parsed_text()
    _rich_text_helper.clear()
    return result

func _format_time(time: float, colors: bool = false) -> String:
    var time_str: String = "%.3f" % time
    if colors:
        return "[[color=thistle]" + time_str + "[/color]]"
    return "[" + time_str + "]"

func _handle_log_message(from_user: bool, message: String) -> void:
    if from_user:
        _handle_command(true, message)
    else:
        pass

@warning_ignore("unused_parameter")
func _handle_command(from_user: bool, command: String) -> void:
    if not command:
        return

    var is_command: bool = false

    if command == 'quit':
        quit_game.call_deferred()
        is_command = true
    elif command.begins_with('say'):
        self.print.call_deferred(command.lstrip('say').strip_edges(true, false))
        is_command = true
    # TODO: more commands ?
    # elif command == '...':

    if is_command:
        var time: float = get_game_time()
        Log.add_log(_format_time(time, true) + ' [color=pale_green]' + escape_bbcode(command) + '[/color]')
        Printer._print(_format_time(time) + " " + command)
    else:
        # text chat???
        self.print(command, true, false, true)

    if not is_command:
        self.print('[color=brown]Unknown command[/color]')
