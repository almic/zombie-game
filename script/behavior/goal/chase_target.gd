class_name BehaviorGoalChaseTarget extends BehaviorGoal


const NAME = &"chase_target"

func name() -> StringName:
    return NAME


## Target groups to chase
@export var target_groups: Array[StringName]

## Target distance for chase
@export var target_distance: float = 1.2

## Base distance to travel during chase
@export var chase_distance: float = 5.0


## Event to act on
var target_event: int

## Most recent navigate request
var last_navigate: BehaviorActionNavigate = null

## Most recent chase bind for navigation signals
var last_chase_binding: Callable


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
        return BehaviorGoal.Priority.MEDIUM

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

    # Get the best travel information
    var navigate := get_best_travel(sens_memory, t, event)
    var next_direction: Vector3 = get_next_direction(sens_memory, t, event)

    if not navigate:
        navigate = BehaviorActionNavigate.new(next_direction, chase_distance)

    navigate.target_distance = target_distance

    # Addition for chasing, connect to complete and continue chase
    if mind.has_acted(BehaviorActionNavigate.NAME):
        var navigations: Array[BehaviorAction] = mind.get_acted_list(BehaviorActionNavigate.NAME)
        var oldest: BehaviorActionNavigate = navigations.back()

        # Must bind to the signal for later
        if not oldest.completed:
            # GlobalWorld.print('connecting chase nav')
            connect_chase(mind, oldest, navigate, next_direction)
        return

    # GlobalWorld.print('chasing now')
    continue_chase(mind, navigate, next_direction)

func get_best_travel(
        memory: BehaviorMemorySensory,
        t: BehaviorMemorySensory.Type,
        event: int
) -> BehaviorActionNavigate:
    # TODO: variate the travel request

    # Direct sense
    var travel: Array[Variant] = memory.get_event_travel(t, event)
    if travel:
        return BehaviorActionNavigate.new(travel[0], travel[1])

    return null

func get_next_direction(
        memory: BehaviorMemorySensory,
        t: BehaviorMemorySensory.Type,
        event: int
) -> Vector3:

    var last_direction: Vector3 = memory.get_event_forward(t, event)

    # TODO: other senses need their "next" direction?

    # TODO: variate the direction
    return last_direction

func connect_chase(
        mind: BehaviorMind,
        after: BehaviorActionNavigate,
        next: BehaviorActionNavigate,
        next_direction: Vector3 = Vector3.ZERO
) -> void:
    if last_navigate and last_chase_binding and last_navigate.on_complete.is_connected(last_chase_binding):
        last_navigate.on_complete.disconnect(last_chase_binding)

    last_navigate = after
    last_chase_binding = continue_chase.bind(mind, next, next_direction)
    last_navigate.on_complete.connect(last_chase_binding, CONNECT_ONE_SHOT)

func continue_chase(
        mind: BehaviorMind,
        navigate: BehaviorActionNavigate,
        last_direction: Vector3 = Vector3.ZERO
) -> void:
    if not BehaviorMemorySensory.is_event_gametime(navigate.time):
        if last_direction.is_zero_approx():
            return
        navigate.direction = last_direction
        navigate.distance = chase_distance

    # GlobalWorld.print('chase navigating! ' + str(navigate.direction))
    mind.act(navigate)
    mind.act(BehaviorActionSpeed.new(mind.parent.top_speed))

    # Connect back to this same navigation to continue chasing
    if not navigate.completed:
        if last_direction.is_zero_approx():
            return
        var next := BehaviorActionNavigate.new(last_direction, chase_distance)
        connect_chase(mind, navigate, next)
