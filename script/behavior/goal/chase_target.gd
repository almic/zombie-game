class_name BehaviorGoalChaseTarget extends BehaviorGoal


const NAME = &"chase_target"

func name() -> StringName:
    return NAME


const NORMAL_PRIORITY = BehaviorGoal.Priority.MEDIUM
const CONTINUE_PRIORITY = BehaviorGoal.Priority.LOW


## Target groups to chase
@export var target_groups: Array[StringName]

## Target distance for chase
@export var target_distance: float = 1.2

## Base distance to travel during chase
@export var chase_distance: float = 5.0


## Travel data for navigation
var travel_target: Array

## Most recent navigation action, acted on for chase continuation
var last_navigate: BehaviorMind.CalledAction

## Next direction for chase
var next_chase_direction: Vector3

## Target node for chase
var chase_target: NodePath


func update_priority(mind: BehaviorMind) -> int:

    if mind.has_acted(BehaviorActionNavigate.NAME):
        # If the last navigate is completed and is equal or higher priority than
        # our priority, run with a lower continue priority
        last_navigate = mind.get_acted(BehaviorActionNavigate.NAME)
        if last_navigate.action.is_complete():

            # If it was successful and equal or higher priority, we will continue it
            if last_navigate.action.is_success() and last_navigate.priority >= NORMAL_PRIORITY:
                travel_target.clear()
                if last_navigate.goal.code_name != code_name:
                    chase_target = NodePath()
                    next_chase_direction = Vector3.ZERO
                return CONTINUE_PRIORITY

        # Skip if the incomplete nav is higher priority
        elif last_navigate.priority > NORMAL_PRIORITY:
            return 0
        elif last_navigate.priority == NORMAL_PRIORITY:
            # If this was our navigate, we have new data and should update
            if last_navigate.goal.code_name != code_name:
                return 0

    last_navigate = null
    next_chase_direction = Vector3.ZERO
    chase_target = NodePath()

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
    var path: NodePath
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

        # Check if the sense just set new data
        var update_time: float = sens_memory.get_event_game_time(t, ev, 2)
        if BehaviorMemorySensory.is_event_gametime(update_time):
            event = ev
            closest = dist
            path = target_path
            continue

        continue

    if event != -1:
        travel_target = sens_memory.get_event_travel(t, event)
        next_chase_direction = sens_memory.get_event_forward(t, event)
        chase_target = path
        return BehaviorGoal.Priority.MEDIUM

    return 0


func perform_actions(mind: BehaviorMind) -> void:
    # Continue the last navigation for chase distance
    if last_navigate:
        if next_chase_direction.is_zero_approx():
            next_chase_direction = mind.parent.global_basis.z
        var distance: float = chase_distance
        # HACK: this is cheating the sensory system but idk a better way
        # If we are close to the target node of the chase, end the chase
        if chase_target:
            var me := mind.parent
            var node: Node3D = me.get_node(chase_target) as Node3D
            if node and node.global_position.distance_squared_to(me.global_position) <= target_distance * target_distance:
                # If the target is still moving, predict future slightly
                var character: CharacterBase = node as CharacterBase
                if character and character.last_velocity.length_squared() > 0.01:
                    next_chase_direction = (
                            (character.global_position + character.last_velocity * 0.5)
                            - me.global_position
                    )
                    if not next_chase_direction.is_zero_approx():
                        distance = next_chase_direction.length()
                        next_chase_direction /= distance
                else:
                    distance = 0.0
        var chase := BehaviorActionNavigate.new(next_chase_direction, distance)
        chase.target_distance = target_distance
        mind.act(chase)
        return

    if travel_target.is_empty():
        return

    var navigate := BehaviorActionNavigate.new(travel_target[0], travel_target[1])
    navigate.target_distance = target_distance

    mind.act(navigate, true)
