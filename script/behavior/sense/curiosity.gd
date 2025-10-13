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

## How much to multiply interest by based on age of event. It is assumed that
## events older than the max_domain of the curve will be out of time range and
## no longer create interest, even if the final point is greater than zero.
@export var time_falloff: Curve

## Interesting group names with their base interest and interest threshold. If
## a node has multiple groups, the highest values will be used. The first number
## is the base interest, before falloff and curiosity multipliers. The second
## number is a maximum threshold, after which an individual node cannot
@export var target_groups: Array[BehaviorSenseCuriosityTargetSettings]


# Map of interesting nodes, key is the StringName nade path, the value is the
# group settings id and the interest to add
var interesting_nodes: Dictionary[StringName, Vector2i]


func _init() -> void:
    target_groups = target_groups.duplicate(true)


func sense(mind: BehaviorMind) -> void:
    var sens_memory: BehaviorMemorySensory = mind.memory_bank.get_memory_reference(BehaviorMemorySensory.NAME)
    if not sens_memory:
        return

    interesting_nodes.clear()

    var sight_events: PackedInt32Array = sens_memory.get_events(BehaviorMemorySensory.Type.SIGHT)
    for event in sight_events:
        process_sight(mind, sens_memory, event)

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
        var data: Vector2i = interesting_nodes.get(node_name)
        var group := target_groups[data.x]
        var add = data.y

        var node: PackedByteArray = interest_memory.get_node(node_name)
        var interest = interest_memory.node_get_interest(node)

        interest_memory.node_set_decay_rate_id(node, data.x)

        # Only modify interest if not in refractory period
        var refractory: float = interest_memory.node_get_refresh_time(node)
        if refractory == 0.0:
            if interest + add >= group.threshold:
                interest_memory.node_add_interest(node, group.threshold - interest)
                interest_memory.node_set_refresh_time(node, group.refractory_period)
            else:
                interest_memory.node_add_interest(node, add)


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

    var dist_mult: float = distance_falloff.sample_baked(dist)
    if is_zero_approx(dist_mult):
        return

    # Check time
    var initial_time: float = memory.get_event_game_time(t, event, 1)
    var update_time: float = memory.get_event_game_time(t, event, 2)
    var current_time: float = GlobalWorld.get_game_time()
    if maxf(initial_time, current_time - (mind.delta_time * frequency)) - update_time > time_falloff.max_domain:
        return

    # Check node
    var node: StringName = memory.get_event_node_path_string(t, event)
    if node.is_empty():
        return

    var target: Node = mind.parent.get_node(NodePath(node))
    if not target:
        return

    # Get best group
    var interest: int = 0
    var group_id: int = -1
    var group: BehaviorSenseCuriosityTargetSettings = null
    if interesting_nodes.has(node):
        var data: Vector2i = interesting_nodes.get(node)
        group_id = data.x
        group = target_groups[group_id]
        interest = data.y
    else:
        for i in range(target_groups.size()):
            var settings := target_groups[i]

            if not target.is_in_group(settings.group_name):
                continue

            if group == null or settings.base_interest > group.base_interest:
                group_id = i
                group = settings

    # Count interest ticks before the last update, after initial event, and
    # use time falloff for ticks after the last update
    var max_count: int = frequency
    while max_count > 0 and current_time >= initial_time:
        var time_offset: float = current_time - update_time
        if time_offset <= time_falloff.max_domain:
            var markiplier: float = dist_mult
            markiplier *= time_falloff.sample_baked(maxf(0.0, time_offset))
            markiplier *= mind.delta_time

            # NOTE: round to nearest integer per tick multiplier, this keeps the
            #       result roughly consistent no matter the frequency
            interest += roundi(group.base_interest * markiplier)

        current_time -= mind.delta_time
        max_count -= 1

    if interest == 0:
        return

    # Save to interesting nodes
    interesting_nodes.set(node, Vector2i(group_id, interest))
