class_name BehaviorSenseCuriosity extends BehaviorSense


const NAME = &"curiosity"

func name() -> StringName:
    return NAME


## How sensitive the curiosity sense is, multiplier to all interest events, after
## falloff curves are applied.
@export_range(0.0, 1.5, 0.01, 'or_greater')
var curiosity: float = 1.0

## Total interest that can be generated from all sources. This simply acts as
## a bound when reporting total interest to goals. If this is lower than any
## goal's interest threshold, that goal will never run.
@export_range(0, 100, 1, 'or_greater', 'hide_slider')
var maximum_curiosity: int = 100

## How much to multiply interest by based on distance. It is assumed that events
## further than the max_domain of the curve will be out of distance range and no
## longer create interest, even if the final point is greater than zero.
@export var distance_falloff: Curve

## Interesting group names with their base interest and interest threshold. If
## a node has multiple groups, the highest values will be used. The first number
## is the base interest, before falloff and curiosity multipliers. The second
## number is a maximum threshold, after which an individual node cannot
@export var target_groups: Array[BehaviorSenseCuriosityTargetSettings]


@export_subgroup("Debug", "debug")

@export_custom(PROPERTY_HINT_GROUP_ENABLE, '')
var debug_enabled: bool = false

## Print node interest values to console on sense updates
@export var debug_print_curious_nodes: bool = false


# Map of interesting nodes, key is the StringName nade path, the value is the
# group settings id and the interest to add
var interesting_nodes: Dictionary[StringName, Vector2]


func _init() -> void:
    target_groups = target_groups.duplicate(true)


func sense(mind: BehaviorMind) -> void:
    var sens_memory: BehaviorMemorySensory = mind.memory_bank.get_memory_reference(BehaviorMemorySensory.NAME)
    if not sens_memory:
        return

    interesting_nodes.clear()

    var events: PackedInt32Array = sens_memory.get_events(BehaviorMemorySensory.Type.SIGHT)
    for event in events:
        process_sight(mind, sens_memory, event)

    events = sens_memory.get_events(BehaviorMemorySensory.Type.SOUND)
    for event in events:
        process_sound(mind, sens_memory, event)

    # TODO: add other primary senses here

    if interesting_nodes.is_empty():
        return

    var interest_memory: BehaviorMemoryInterest = mind.memory_bank.get_memory_reference(BehaviorMemoryInterest.NAME)
    if not interest_memory:
        interest_memory = BehaviorMemoryInterest.new()

        interest_memory.assign_max_interest(maximum_curiosity)

        # Initialize inverse decay rates
        var rates := PackedFloat32Array()
        var size: int = target_groups.size()
        rates.resize(size)
        for i in range(size):
            var group := target_groups[i]
            rates[i] = 1.0 / group.decay_rate

        interest_memory.assign_decay_rates(rates)

        mind.memory_bank.save_memory_reference(interest_memory)

    for node_name in interesting_nodes.keys():
        var data: Vector2 = interesting_nodes.get(node_name)

        # NOTE: optimization
        if data.x == -1.0:
            continue

        var group_id: int = int(data.x)
        var group := target_groups[group_id]
        var add: float = data.y

        var node := interest_memory.get_node(node_name)
        var interest: float = interest_memory.node_get_interest(node)

        # NOTE: update decay group and reset timer so we don't start decaying instantly
        interest_memory.node_set_decay_rate_id(node, group_id)
        interest_memory.node_set_decay_timer(node, 0.0)

        # Only modify interest if not in refractory period
        var refractory: float = interest_memory.node_get_refresh_time(node)
        if refractory == 0.0:
            if not is_zero_approx(group.threshold) and is_equal_approx(group.threshold, minf(interest + add, group.threshold)):
                interest_memory.node_set_interest(node, group.threshold)
                interest_memory.node_set_refresh_time(node, group.refractory_period)
            else:
                interest_memory.node_set_interest(node, interest + add)

        if debug_enabled and debug_print_curious_nodes:
            interest = interest_memory.node_get_interest(node)
            print('Node ' + str(node_name) + ' interest : ' + str(interest))

        interest_memory.start_decay()
        activated = true


func process_sight(
        mind: BehaviorMind,
        memory: BehaviorMemorySensory,
        event: int
) -> void:
    const t = BehaviorMemorySensory.Type.SIGHT

    # check distance
    var travel: Array[Variant] = memory.get_event_travel(t, event)
    if travel.is_empty():
        return

    # Check distance
    var dist: float = travel[1]
    if dist > distance_falloff.max_domain:
        return

    var dist_mult: float = distance_falloff.sample(dist)
    if is_zero_approx(dist_mult):
        return

    # Check time
    var update_time: float = memory.get_event_game_time(t, event, 2)
    var current_time: float = GlobalWorld.get_game_time()
    if int((current_time - update_time) / mind.delta_time) > frequency:
        return

    # Check node
    var node: StringName = memory.get_event_node_path_string(t, event)
    if node.is_empty():
        return

    var target: Node = mind.parent.get_node(NodePath(node))
    if not target:
        return

    # Get best group
    var last_interest: float = 0
    var group_id: int = -1
    var group: BehaviorSenseCuriosityTargetSettings = null
    if interesting_nodes.has(node):
        var data: Vector2 = interesting_nodes.get(node)

        # NOTE: optimization to avoid double checking bad nodes
        if data.x == -1.0:
            return

        group_id = int(data.x)
        group = target_groups[group_id]
        last_interest = data.y
    else:
        for i in range(target_groups.size()):
            var settings := target_groups[i]

            if settings.sense_type != t:
                continue

            if not target.is_in_group(settings.group_name):
                continue

            if group == null or settings.base_interest > group.base_interest:
                group_id = i
                group = settings

        # NOTE: optimization to avoid double checking nodes
        if group_id == -1:
            interesting_nodes.set(node, Vector2(-1.0, 0.0))

    if group_id == -1:
        return

    # TODO: investigate if we overwrite a 1 tick new event with the frequency
    #       tick older event correctly. Otherwise when a new event is made, we
    #       are losing some time from the immediately previous event.
    var initial_time: float = memory.get_event_game_time(t, event, 1)
    var time: float = minf(mind.delta_time * frequency, current_time - initial_time)
    var add: float = group.base_interest * dist_mult * time

    if is_zero_approx(add) or last_interest > add:
        return

    # Save to interesting nodes
    interesting_nodes.set(node, Vector2(group_id, add))

func process_sound(
        mind: BehaviorMind,
        memory: BehaviorMemorySensory,
        event: int
) -> void:
    const t = BehaviorMemorySensory.Type.SOUND

    # check distance
    var travel: Array[Variant] = memory.get_event_travel(t, event)
    if travel.is_empty():
        return

    # Check distance
    var dist: float = travel[1]
    if dist > distance_falloff.max_domain:
        return

    var dist_mult: float = distance_falloff.sample(dist)
    if is_zero_approx(dist_mult):
        return

    # Check time
    var event_time: float = memory.get_event_game_time(t, event)
    var current_time: float = GlobalWorld.get_game_time()
    if int((current_time - event_time) / mind.delta_time) > frequency:
        return

    # Check node
    var node: StringName = memory.get_event_node_path_string(t, event)
    if node.is_empty():
        return

    # Check groups
    var sound_groups: PackedInt32Array = memory.get_event_groups(t, event)
    if sound_groups.is_empty():
        return

    # Get best group
    var last_interest: float = 0
    var group_id: int = -1
    var group: BehaviorSenseCuriosityTargetSettings = null
    if interesting_nodes.has(node):
        var data: Vector2 = interesting_nodes.get(node)

        # NOTE: optimization to avoid double checking bad nodes
        if data.x == -1.0:
            return

        group_id = int(data.x)
        group = target_groups[group_id]
        last_interest = data.y
    else:
        for i in range(target_groups.size()):
            var settings := target_groups[i]

            if settings.sense_type != t:
                continue

            var sound_group_id: int = GlobalWorld.Groups.get_group_id(settings.group_name)
            if sound_group_id == -1:
                push_error('The target group "' + settings.group_name + '" is not a global group! Did you forget to add it, or typo?')
                continue

            if not sound_groups.has(sound_group_id):
                continue

            if group == null or settings.base_interest > group.base_interest:
                group_id = i
                group = settings

        # NOTE: optimization to avoid double checking nodes
        if group_id == -1:
            interesting_nodes.set(node, Vector2(-1.0, 0.0))

    if group_id == -1:
        return

    var add: float = group.base_interest * dist_mult

    if is_zero_approx(add) or last_interest > add:
        return

    # Save to interesting nodes
    interesting_nodes.set(node, Vector2(group_id, add))
