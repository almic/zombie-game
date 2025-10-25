class_name BehaviorGoalInvestigate extends BehaviorGoal


const NAME = &"investigate"

func name() -> StringName:
    return NAME


## Priority for investigations
const NORMAL_PRIORITY = BehaviorGoal.Priority.LOW


## Relative speed to travel at when investigating. Multiplied by
## `CharacterBase.top_speed` when navigating.
@export_range(0.0, 1.0, 0.001, 'or_greater')
var navigate_speed: float = 0.5

## Target distance for navigation.
@export_range(0.0, 5.0, 0.001, 'or_greater')
var navigate_target_distance: float = 2.0

## Falloff curve for events, use this to decay interest in older events.
@export var time_falloff: Curve

## Parameters for interesting events related to sensory types. This is used to
## favor certain senses for turning and navigation, as well as priority when
## multiple senses compete for a response. In the event two senses are equally
## favorable, the first one in the list will be selected.
@export var type_interests: Array[BehaviorGoalInvestigateInterestSettings]


## Travel target for investigation
var turn_target: Vector3

## Navigation target for investigation, can be separate from turning
var nav_target: Array

## If the investigation should include a navigation
var is_nav_response: bool


func process_memory(mind: BehaviorMind) -> int:
    is_nav_response = false

    if not time_falloff:
        push_error('Investigate goal requires a time falloff curve!')
        return 0

    var sens_memory: BehaviorMemorySensory = mind.memory_bank.get_memory_reference(BehaviorMemorySensory.NAME)
    if not sens_memory:
        return 0

    var interest_memory: BehaviorMemoryInterest = mind.memory_bank.get_memory_reference(BehaviorMemoryInterest.NAME)
    if not interest_memory:
        return 0

    var best_interest: float = -INF
    for interest in type_interests:
        var type := interest.type
        var events: PackedInt32Array = sens_memory.get_events(type)

        # TODO: dev only, should be removed later
        if interest.turn > interest.navigate:
            push_error('Interest type ' + str(interest.type) + ' has `turn` higher than `navigate`. This does not make sense, turn should be lower! Change it!')

        if events.is_empty():
            continue

        # Find most interesting event
        for ev in events:

            # NOTE: revisit this, could potentially benefit from a set to check
            #       if a node has already been tested, or just a list

            var event_time: float = sens_memory.get_event_game_time(type, ev, 2)
            if event_time == -1:
                event_time = sens_memory.get_event_game_time(type, ev)

            if event_time == -1:
                continue

            # If this event is too old, we can stop here, the rest will be older
            var delay: float = GlobalWorld.get_game_time() - event_time
            if delay > time_falloff.max_domain:
                break

            var travel: Array = sens_memory.get_event_travel(type, ev)
            if not travel:
                continue

            var node_path := sens_memory.get_event_node_path_string(type, ev)
            if not node_path:
                continue

            var node := interest_memory.get_node(node_path)
            var node_interest := interest_memory.node_get_interest(node)
            node_interest *= time_falloff.sample(delay)

            if node_interest < interest.turn:
                continue

            if node_interest > best_interest:
                turn_target = travel[0]
                if node_interest >= interest.navigate:
                    nav_target = travel
                    is_nav_response = true

                best_interest = node_interest * interest.multiplier

    if best_interest > 0:
        if is_nav_response:
            # Check that no equal or higher priority navigate is running, but we
            # may update ours
            var last_navigate := mind.get_acted(BehaviorActionNavigate.NAME)
            if last_navigate and not last_navigate.action.is_complete():
                if last_navigate.priority > NORMAL_PRIORITY:
                    is_nav_response = false
                elif last_navigate.priority == NORMAL_PRIORITY:
                    is_nav_response = last_navigate.goal.code_name == code_name

        return NORMAL_PRIORITY

    return 0

func perform_actions(mind: BehaviorMind) -> void:
    var me: CharacterBase = mind.parent
    if not me:
        return

    if is_nav_response and not mind.is_recent_action(BehaviorActionNavigate.NAME):
        mind.act(BehaviorActionSpeed.new(me.top_speed * navigate_speed))
        mind.act(BehaviorActionNavigate.new(nav_target[0], nav_target[1], navigate_target_distance))

    var up: Vector3 = me.up_direction
    var direction: Vector3 = turn_target

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
