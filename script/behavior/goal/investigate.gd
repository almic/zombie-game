class_name BehaviorGoalInvestigate extends BehaviorGoal


const NAME = &"investigate"

func name() -> StringName:
    return NAME


## How much to multiply interest by based on distance. It is assumed that events
## further than the max_domain of the curve will be out of distance range and no
## longer create interest, even if the final point is greater than zero.
@export var distance_falloff: Curve

## How much to multiply interest by based on age of event. It is assumed that
## events older than the max_domain of the curve will be out of time range and
## no longer create interest, even if the final point is greater than zero.
@export var time_falloff: Curve

## Interesting groups and their base interest. If a node has multiple groups,
## highest value will be used.
@export var target_groups: Dictionary[StringName, int]


# Preprocessed list of interesting events by type. The array stores pairs of
# integers, the first is the event id, the second is the interest value
var interesting_events: Dictionary[BehaviorMemorySensory.Type, PackedInt32Array]

# Preprocessed list of interesting nodes, prevent double-adding interest on the
# same node
var interesting_nodes: Dictionary[NodePath, int]

# Preprocessed total interest to add
var interest_to_add: int




func update_priority(mind: BehaviorMind) -> int:
    var sens_memory: BehaviorMemorySensory = mind.memory_bank.get_memory_reference(BehaviorMemorySensory.NAME)
    if not sens_memory:
        return 0

    var t: BehaviorMemorySensory.Type = BehaviorMemorySensory.Type.SIGHT
    var sight_events: PackedInt32Array = sens_memory.get_events(t)

    if sight_events.is_empty():
        return 0

    # Collect any interesting events
    interesting_events.clear()
    interesting_nodes.clear()
    for ev in sight_events:

        # check distance
        var travel: Array[Variant] = sens_memory.get_event_travel(t, ev)
        if travel.is_empty():
            continue

        var dist: float = travel[1]
        if dist > distance_falloff.max_domain:
            continue

        # Check time
        var update_time: float = sens_memory.get_event_game_time(t, ev, 2)
        var delay: float = 0.0
        if not BehaviorMemorySensory.is_event_gametime(update_time):
            # Check if the sense is recent enough
            delay = GlobalWorld.get_game_time() - update_time
            if delay > time_falloff.max_domain:
                continue

        # Check multiplier
        var markiplier: float = 1.0
        markiplier *= distance_falloff.sample_baked(dist)
        markiplier *= time_falloff.sample_baked(delay) * mind.delta_time
        if is_zero_approx(markiplier):
            continue

        # Check groups
        var target_path: NodePath = sens_memory.get_event_node_path(t, ev)
        if not target_path:
            continue

        var target: Node = mind.parent.get_node(target_path)
        var interest: int = 0
        for group in target_groups.keys():
            if not target.is_in_group(group):
                continue
            interest = maxi(interest, target_groups.get(group, 0))

        interest = roundi(float(interest) * markiplier)

        if interest == 0:
            continue

        # Save to interesting events
        var events: PackedInt32Array = interesting_events.get_or_add(t, PackedInt32Array())
        var last: int = events.size()
        events.resize(last + 2)

        events[last] = ev
        events[last + 1] = interest

        interesting_nodes.set(
                target_path,
                maxi(interest, interesting_nodes.get(target_path, 0))
        )

        continue

    if interesting_nodes.is_empty():
        return 0

    # Compute amount of interest to add in perform actions
    interest_to_add = 0
    for node in interesting_nodes.keys():
        interest_to_add += interesting_nodes.get(node)

    if interest_to_add == 0:
        return 0

    # Earlier than HIGH since we plan to modify interest, which other goals may
    # use to determine if they should run at all
    return BehaviorGoal.Priority.HIGH + 10

func perform_actions(mind: BehaviorMind) -> void:
    var interest_memory: BehaviorMemoryInterest = mind.memory_bank.get_memory_reference(BehaviorMemoryInterest.NAME)
    if not interest_memory:
        interest_memory = BehaviorMemoryInterest.new()
        mind.memory_bank.save_memory_reference(interest_memory)

    interest_memory.interest += interest_to_add
