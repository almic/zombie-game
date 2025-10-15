## Responds to sightings of targets, will navigate to the most recently seen target.
## Marks responses as complete when reaching the last known location of the target.
class_name BehaviorGoalAttackTarget extends BehaviorGoal


const NAME = &"attack_target"

func name() -> StringName:
    return NAME


## Priority used when starting an attack
const NORMAL_PRIORITY = BehaviorGoal.Priority.HIGH

## Priority used when chaining an attack after a navigation
const CONTINUE_PRIORITY = BehaviorGoal.Priority.HIGH + 100


## Target groups to attack
@export var target_groups: Array[StringName]

## Activation range for attacking, targets in this range are checked. If melee
## is enabled, this is the range at which simple navigation is triggered to get
## within melee range
@export var activation_range: float = 1.5


@export_group("Melee", "melee")

## If this attack is melee
@export_custom(PROPERTY_HINT_GROUP_ENABLE, '')
var melee_enabled: bool = false

## Minimum distance to attack with melee. If not in this range when activated,
## will first navigate within this range to the target before attacking.
@export var melee_distance: float = 1.2


## Target to attack
var attack_target: Node3D

## Target travel for attack, may be set
var travel_target: Array = []


func update_priority(mind: BehaviorMind) -> int:
    # NOTE: can clear right away, always called after a completed travel, or we
    #       have data and will update the travel anyway
    travel_target.clear()

    # Check if we just finished a navigation in our attack
    if attack_target and mind.has_acted(BehaviorActionNavigate.NAME):
        var last_navigate := mind.get_acted(BehaviorActionNavigate.NAME)
        # If this is ours, and complete, we must be running from the completion
        # and should not check sensory memory
        if last_navigate.just_completed and last_navigate.goal.code_name == code_name:
            if last_navigate.action.is_success():
                # We should attack immediately with our attack target
                return CONTINUE_PRIORITY
            # Navigate failed, wait for new data
            return 0

        # Not ours or not complete, must have new sensory data
        pass

    attack_target = null

    var sens_memory: BehaviorMemorySensory = mind.memory_bank.get_memory_reference(BehaviorMemorySensory.NAME)
    if not sens_memory:
        return 0

    var t: BehaviorMemorySensory.Type = BehaviorMemorySensory.Type.SIGHT
    var sight_events: PackedInt32Array = sens_memory.get_events(t)

    if sight_events.is_empty():
        return 0

    # Look for the most recent and closest target in the group
    var event: int = -1
    var age: float = INF
    var target: Node3D = null
    for ev in sight_events:
        var travel: Array[Variant] = sens_memory.get_event_travel(t, ev)
        if travel.is_empty():
            continue

        var dist: float = travel[1]
        if dist > activation_range:
            continue

        var node_path: NodePath = sens_memory.get_event_node_path(t, ev)
        if not node_path:
            continue

        var node: Node3D = mind.parent.get_node(node_path) as Node3D
        if not node:
            continue

        var in_group: bool = false
        for group in target_groups:
            if node.is_in_group(group):
                in_group = true
                break
        if not in_group:
            continue

        # Check if the sense is relatively recent
        var update_time: float = sens_memory.get_event_game_time(t, ev, 2)
        var current_time: float = GlobalWorld.get_game_time()
        var delay: float = current_time - update_time
        if delay < age and delay <= 1.0:
            event = ev
            age = delay
            target = node
            continue

        continue

    if event != -1:
        attack_target = target
        travel_target = sens_memory.get_event_travel(t, event)
        return NORMAL_PRIORITY

    return 0

func perform_actions(mind: BehaviorMind) -> void:
    # Call this every time just in case, does nothing if action was not ours
    mind.disable_on_complete(BehaviorActionNavigate.NAME)

    if !melee_enabled:
        mind.act(BehaviorActionAttack.new(attack_target))
        return

    var me := mind.parent

    # For melee attacks, must be within melee range
    if attack_target.global_position.distance_squared_to(me.global_position) <= melee_distance * melee_distance:
        # Skip navigation if something else already navigated
        if not mind.is_recent_action(BehaviorActionNavigate.NAME):
            mind.act(BehaviorActionSpeed.new(me.top_speed))
            mind.act(BehaviorActionAttack.new(attack_target, true))
        return

    if travel_target.is_empty():
        return

    mind.act(
            BehaviorActionNavigate.new(travel_target[0], travel_target[1], melee_distance),
            true,
            BehaviorGoal.Priority.MEDIUM - 1
    )
