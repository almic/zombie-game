class_name BehaviorGoalInvestigate extends BehaviorGoal


const NAME = &"investigate"

func name() -> StringName:
    return NAME


## Falloff curve for events, use this to decay interest in older events.
@export var time_falloff: Curve

## Thresholds for interesting events related to sensory types. The order
## determines which type to select when they meet their thresholds. If no types
## meet their threshold, then the highest interest will be chosen.
@export var type_thresholds: Array[BehaviorGoalInvestigateThresholdSettings]


# Preprocessed target event to investigate
var target_event: int
var target_type := BehaviorMemorySensory.Type.MAX


func update_priority(mind: BehaviorMind) -> int:
    var sens_memory: BehaviorMemorySensory = mind.memory_bank.get_memory_reference(BehaviorMemorySensory.NAME)
    if not sens_memory:
        return 0

    var interest_memory: BehaviorMemoryInterest = mind.memory_bank.get_memory_reference(BehaviorMemoryInterest.NAME)
    if not interest_memory:
        return 0

    var any_best_interest: float = -INF
    var event: int = -1
    var t: BehaviorMemorySensory.Type = BehaviorMemorySensory.Type.MAX
    for type_threshold in type_thresholds:
        var type := type_threshold.type
        var threshold := type_threshold.threshold

        var events: PackedInt32Array = sens_memory.get_events(type)

        if events.is_empty():
            continue

        # Find most interesting event
        var best_event: int = -1
        var best_interest: float = 0

        for ev in events:
            var node_path := sens_memory.get_event_node_path_string(type, ev)
            if not node_path:
                continue

            # NOTE: revisit this, could potentially benefit from a set to check
            #       if a node has already been tested, or just a list

            var update_time: float = sens_memory.get_event_game_time(type, ev, 2)
            var delay: float = GlobalWorld.get_game_time() - update_time

            var node := interest_memory.get_node(node_path)
            var interest := interest_memory.node_get_interest(node)

            if time_falloff:
                if delay > time_falloff.max_domain:
                    continue
                interest *= time_falloff.sample_baked(delay)

            if interest > best_interest:
                best_event = ev
                best_interest = interest

        if best_event == -1:
            continue

        if best_interest >= threshold:
            event = best_event
            t = type
            break

        if best_interest > any_best_interest:
            any_best_interest = best_interest
            event = best_event
            t = type

    if event != -1:
        target_event = event
        target_type = t
        return BehaviorGoal.Priority.LOW

    return 0

func perform_actions(mind: BehaviorMind) -> void:
    var me: CharacterBase = mind.parent
    if not me:
        return

    var sens_memory: BehaviorMemorySensory = mind.memory_bank.get_memory_reference(BehaviorMemorySensory.NAME)
    if not sens_memory:
        return

    var travel := sens_memory.get_event_travel(target_type, target_event)
    if travel.is_empty():
        return

    var up: Vector3 = me.up_direction
    var direction: Vector3 = travel[0]
    direction -= up * up.dot(direction)
    if direction.is_zero_approx():
        # No turn needed
        return

    direction = direction.normalized()
    if is_equal_approx(direction.dot(me.global_basis.z), 1.0):
        # No turn needed
        return

    var angle: float = me.global_basis.z.signed_angle_to(direction, me.up_direction)

    var turn := BehaviorActionTurn.new(angle)
    mind.act(turn)
