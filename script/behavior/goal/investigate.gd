class_name BehaviorGoalInvestigate extends BehaviorGoal


const NAME = &"investigate"

func name() -> StringName:
    return NAME


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

    var any_best_interest: int = -1
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
        var best_interest: int = 0
        for ev in events:
            # TODO
            pass

        if best_event == -1:
            continue

        if best_interest >= threshold:
            event = best_event
            break

        if best_interest > any_best_interest:
            any_best_interest = best_interest
            event = best_event

    if event != -1:
        target_event = event
        target_type = t
        return BehaviorGoal.Priority.LOW

    return 0

func perform_actions(mind: BehaviorMind) -> void:
    # TODO
    pass
