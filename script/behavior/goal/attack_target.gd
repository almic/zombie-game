## Responds to sightings of targets, will navigate to the most recently seen target.
## Marks responses as complete when reaching the last known location of the target.
class_name BehaviorGoalAttackTarget extends BehaviorGoal


const NAME = &"attack_target"

func name() -> StringName:
    return NAME


## Target groups to attack
@export var target_groups: Array[StringName]

## Target distance for an attack
@export var target_distance: float = 1.2


## Most recent navigate request
var last_navigate: BehaviorActionNavigate = null

## Most recent attack bind for navigation signals
var last_attack_binding: Callable


func update_priority(mind: BehaviorMind) -> int:
    var sens_memory: BehaviorMemorySensory = mind.memory_bank.get_memory_reference(BehaviorMemorySensory.NAME)
    if not sens_memory:
        return 0

    var t: BehaviorMemorySensory.Type = BehaviorMemorySensory.Type.SIGHT
    var sight_events: PackedInt32Array = sens_memory.get_events(t)

    if sight_events.is_empty():
        return 0

    # Only respond to the first event
    var event = sight_events[0]

    var flags: int = sens_memory.get_event_flag(t, event)
    if flags == -1:
        return 0

    if not (flags & BehaviorMemorySensory.Flag.RESPONSE_STARTED):
        return BehaviorGoal.Priority.HIGH

    return BehaviorGoal.Priority.HIGH


func perform_actions(mind: BehaviorMind) -> void:
    var sens_memory: BehaviorMemorySensory = mind.memory_bank.get_memory_reference(BehaviorMemorySensory.NAME)
    if not sens_memory:
        return

    var t: BehaviorMemorySensory.Type = BehaviorMemorySensory.Type.SIGHT
    var sight_events: PackedInt32Array = sens_memory.get_events(t)

    if sight_events.is_empty():
        return

    # Only respond to the first event
    var event = sight_events[0]

    var flags: int = sens_memory.get_event_flag(t, event)
    if flags == -1:
        # Event not found?
        return
    var set_flags: bool = false

    # Mark started
    if not (flags & BehaviorMemorySensory.Flag.RESPONSE_STARTED):
        flags |= BehaviorMemorySensory.Flag.RESPONSE_STARTED
        set_flags = true
    else:
        # Check if the sense just set new data, then clear the flag
        var update_time: float = sens_memory.get_event_game_time(t, event, 2)
        var game_time: float = sens_memory.calc_rounded_game_time(
            float(GlobalWorld.game_time) + GlobalWorld.game_time_frac
        )
        if not is_equal_approx(update_time, game_time):
            #print('update time ' + str(update_time) + ' != ' + str(game_time))
            return
        #print('equivalent! ' + str(update_time))

        if flags & BehaviorMemorySensory.Flag.RESPONSE_COMPLETE:
            flags &= ~BehaviorMemorySensory.Flag.RESPONSE_COMPLETE
            set_flags = true

    var travel: Array[Variant] = sens_memory.get_event_travel(t, event)
    if not travel:
        push_warning('Incomplete/ new sensory memory has no travel data! This is a mistake? Investigate!')
        flags |= BehaviorMemorySensory.Flag.RESPONSE_COMPLETE
        sens_memory.set_event_flag(t, event, flags)
        return

    # TODO: variate the travel request
    var navigate := BehaviorActionNavigate.new(travel[0], travel[1])
    navigate.target_distance = target_distance

    # Bind navigation signals
    if (
                last_navigate
            and last_attack_binding
            and last_navigate.on_complete.is_connected(last_attack_binding)
    ):
        last_navigate.on_complete.disconnect(last_attack_binding)

    last_navigate = navigate
    var target_path: NodePath = sens_memory.get_event_node_path(t, event)
    var target: Node3D

    if target_path:
        target = mind.parent.get_node(target_path) as Node3D

    if target:
        last_attack_binding = do_attack.bind(mind, target)

    #print('Navigating torwards ' + str(travel[0].snappedf(0.01)) + ' for ' + str(snappedf(travel[1], 0.1)) + 'm!')
    mind.act(navigate)

    if navigate.completed:
        flags |= BehaviorMemorySensory.Flag.RESPONSE_COMPLETE
        set_flags = true
        if target:
            last_attack_binding.call()
    elif target:
        last_navigate.on_complete.connect(last_attack_binding)

    if set_flags:
        sens_memory.set_event_flag(t, event, flags)

func do_attack(mind: BehaviorMind, target: Node3D) -> void:
    var attack := BehaviorActionAttack.new(target)
    #print('I have reached my goal! Attacking!')
    mind.act(attack)
