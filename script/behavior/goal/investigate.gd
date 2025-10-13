class_name BehaviorGoalInvestigate extends BehaviorGoal


const NAME = &"investigate"

func name() -> StringName:
    return NAME


# Preprocessed target event to investigate
var target_event: int


func update_priority(mind: BehaviorMind) -> int:
    var sens_memory: BehaviorMemorySensory = mind.memory_bank.get_memory_reference(BehaviorMemorySensory.NAME)
    if not sens_memory:
        return 0

    var t: BehaviorMemorySensory.Type = BehaviorMemorySensory.Type.SIGHT
    var sight_events: PackedInt32Array = sens_memory.get_events(t)

    if sight_events.is_empty():
        return 0

    # Find most interesting event
    var event: int = -1
    for ev in sight_events:
        # TODO
        pass

    if event != -1:
        target_event = event
        return BehaviorGoal.Priority.LOW

    return 0

func perform_actions(mind: BehaviorMind) -> void:
    # TODO
    pass
