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


## Event to act on
var target_event: int

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

    # Look for the most recent and closest target in the group
    var event: int = -1
    var closest: float = INF
    for ev in sight_events:
        var travel: Array[Variant] = sens_memory.get_event_travel(t, ev)
        if travel.is_empty():
            continue

        var dist: float = travel[1]
        if dist >= closest:
            continue

        var target_path: NodePath = sens_memory.get_event_node_path(t, ev)
        if not target_path:
            continue

        var target: Node = mind.parent.get_node(target_path)
        var in_group: bool = false
        for group in target_groups:
            if target.is_in_group(group):
                in_group = true
                break
        if not in_group:
            continue

        var flags: int = sens_memory.get_event_flag(t, ev)
        if flags == -1:
            continue

        # Unstarted must be handled right away
        if not (flags & BehaviorMemorySensory.Flag.RESPONSE_STARTED):
            event = ev
            closest = dist
            continue

        # Check if the sense just set new data
        var update_time: float = sens_memory.get_event_game_time(t, ev, 2)
        if BehaviorMemorySensory.is_event_gametime(update_time):
            event = ev
            closest = dist
            continue

        continue

    if event != -1:
        target_event = event
        return BehaviorGoal.Priority.HIGH

    return 0


func perform_actions(mind: BehaviorMind) -> void:
    var sens_memory: BehaviorMemorySensory = mind.memory_bank.get_memory_reference(BehaviorMemorySensory.NAME)
    if not sens_memory:
        return

    var t: BehaviorMemorySensory.Type = BehaviorMemorySensory.Type.SIGHT
    var sight_events: PackedInt32Array = sens_memory.get_events(t)

    if not sight_events.has(target_event):
        return

    var event = target_event

    var flags: int = sens_memory.get_event_flag(t, event)
    if flags == -1:
        # Event not found?
        return
    var set_flags: bool = false

    # Mark started
    if not (flags & BehaviorMemorySensory.Flag.RESPONSE_STARTED):
        flags |= BehaviorMemorySensory.Flag.RESPONSE_STARTED
        set_flags = true
    # Otherwise, new data, clear complete flag
    elif flags & BehaviorMemorySensory.Flag.RESPONSE_COMPLETE:
        flags &= ~BehaviorMemorySensory.Flag.RESPONSE_COMPLETE
        set_flags = true

    var travel: Array[Variant] = sens_memory.get_event_travel(t, event)
    if not travel:
        push_error('Incomplete/ new sensory memory has no travel data! This is a mistake? Investigate!')
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
        last_attack_binding = complete_and_attack.bind(mind, target, event)

    # GlobalWorld.print('attack navigating! ' + str(navigate.direction))
    mind.act(navigate)
    mind.act(BehaviorActionSpeed.new(mind.parent.top_speed))

    if navigate.completed:
        flags |= BehaviorMemorySensory.Flag.RESPONSE_COMPLETE
        set_flags = true
        if target:
            last_attack_binding.call()
    elif target:
        last_navigate.on_complete.connect(last_attack_binding, CONNECT_ONE_SHOT)

    if set_flags:
        sens_memory.set_event_flag(t, event, flags)


func complete_and_attack(mind: BehaviorMind, target: Node3D, event: int) -> void:
    var sens_memory: BehaviorMemorySensory = mind.memory_bank.get_memory_reference(BehaviorMemorySensory.NAME)
    if sens_memory:
        var t: BehaviorMemorySensory.Type = BehaviorMemorySensory.Type.SIGHT
        var flags: int = sens_memory.get_event_flag(t, event)
        flags |= BehaviorMemorySensory.Flag.RESPONSE_COMPLETE
        sens_memory.set_event_flag(t, event, flags)

    var attack := BehaviorActionAttack.new(target)
    mind.act(attack)
