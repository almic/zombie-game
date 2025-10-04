## Responds to sightings of targets, will navigate to the most recently seen target.
## Marks responses as complete when reaching the last known location of the target.
class_name BehaviorGoalAttackTarget extends BehaviorGoal


const NAME = &"attack_target"

func name() -> StringName:
    return NAME


@export var target_groups: Array[StringName]


func update_priority(mind: BehaviorMind) -> int:
    var sens_memory: BehaviorMemorySensory = mind.memory_bank.get_memory_reference(BehaviorMemorySensory.NAME)
    if not sens_memory:
        return 0

    var t: BehaviorMemorySensory.Type = BehaviorMemorySensory.Type.SIGHT
    var sight_events: PackedInt32Array = sens_memory.get_events(t)
    for event in sight_events:
        var response: int = sens_memory.get_event_response(t, event)
        if response == -1:
            continue

        if response & BehaviorMemorySensory.Response.STARTED:
            # Response started and not complete, we must be called
            if not response & BehaviorMemorySensory.Response.COMPLETE:
                return BehaviorGoal.Priority.HIGH

            # Ignore completed responses
            continue

        # TODO: more complex testing for a response
        return BehaviorGoal.Priority.HIGH

    return 0


func perform_actions(mind: BehaviorMind) -> void:
    var sens_memory: BehaviorMemorySensory = mind.memory_bank.get_memory_reference(BehaviorMemorySensory.NAME)
    if not sens_memory:
        return

    var t: BehaviorMemorySensory.Type = BehaviorMemorySensory.Type.SIGHT
    var sight_events: PackedInt32Array = sens_memory.get_events(t)

    for event in sight_events:
        var response: int = sens_memory.get_event_response(t, event)
        if response == -1:
            break

        # Events are well-ordered, if we reach a completed response, we are done
        if response & BehaviorMemorySensory.Response.COMPLETE:
            break

        # Only respond to the first non-started event, skip the rest
        if response & BehaviorMemorySensory.Response.STARTED:
            # TODO: check if navigation is finished, but always break out here
            response |= BehaviorMemorySensory.Response.COMPLETE
            sens_memory.set_event_response(t, event, response)

            break

        response |= BehaviorMemorySensory.Response.STARTED
        sens_memory.set_event_response(t, event, response)

        var travel: Array[Variant] = sens_memory.get_event_travel(t, event)
        if not travel:
            response |= BehaviorMemorySensory.Response.COMPLETE
            sens_memory.set_event_response(t, event, response)
            continue

        # TODO: variate the travel request
        mind.act(BehaviorActionNavigate.new(travel[0], travel[1]))
