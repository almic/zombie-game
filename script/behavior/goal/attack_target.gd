class_name BehaviorGoalAttackTarget extends BehaviorGoal


const NAME = &"attack_target"

func name() -> StringName:
    return NAME


@export var target_groups: Array[StringName]


func update_priority(mind: BehaviorMind) -> int:
    var sens_memory: BehaviorMemorySensory = mind.memory_bank.get_memory_reference(BehaviorMemorySensory.NAME)
    if not sens_memory:
        return 0

    for i in range(sens_memory.count()):
        var target: CharacterBase = sens_memory.get_character(i)
        var in_group: bool = false
        for group in target_groups:
            if target.is_in_group(group):
                in_group = true
                break
        if not in_group:
            continue

        var t: BehaviorMemorySensory.Type = BehaviorMemorySensory.Type.SIGHT
        var sight_events: PackedInt32Array = sens_memory.get_events(t)
        for event in sight_events:
            var time: int = sens_memory.get_event_location(t, event)

    return 0


func perform_actions(mind: BehaviorMind) -> void:
    pass
