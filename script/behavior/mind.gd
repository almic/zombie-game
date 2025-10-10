## Container for a memory bank, goals, actions, and senses
class_name BehaviorMind extends Resource


@export var senses: Array[BehaviorSense] = []
@export var goals: Array[BehaviorGoal] = []


var parent: CharacterBase
var memory_bank: BehaviorMemoryBank
var delta_time: float

var is_sorting_phase: bool = false

var _priority_list: Dictionary
var _code_to_sense: Dictionary[StringName, BehaviorSense]
var _goal_minimum_period: Dictionary[StringName, float]
var _actions_called: Dictionary[StringName, Array]


func _init() -> void:
    memory_bank = BehaviorMemoryBank.new()
    _priority_list = {}
    _code_to_sense = {}
    _goal_minimum_period = {}
    _actions_called = {}

    senses = senses.duplicate(true)
    goals = goals.duplicate(true)


## Retrieve a sense by name. If two senses are the same type, returns the first one.
func get_sense(name: StringName) -> BehaviorSense:
    for sense in senses:
        if name == sense.name():
            return sense
    return null

## Retrieve a goal by name. If two goals are the same type, returns the first one.
func get_goal(name: StringName) -> BehaviorGoal:
    for goal in goals:
        if name == goal.name():
            return goal
    return null

## Call during the physics frame to do behavior stuff
func update(delta: float) -> void:
    delta_time = delta

    # Clear actions called
    _actions_called.clear()

    # Process senses to update memories
    memory_bank.locked = false
    for sense in senses:
        if sense.tick():
            sense.on_sense.emit(sense)
            sense.sense(self)
    memory_bank.decay_memories(delta_time)
    memory_bank.locked = true

    # Get goal call order
    var priority: int
    is_sorting_phase = false
    for goal in goals:
        if not _can_goal_process(goal):
            continue

        priority = goal.update_priority(self)
        if priority < 1:
            continue

        if not _priority_list.has(priority):
            _priority_list.set(priority, goal)
            continue

        var value: Variant = _priority_list.get(priority)
        if value is Array:
            value.append(goal)
            continue

        _priority_list.set(priority, [value, goal])
    is_sorting_phase = false

    # Perform goals
    _priority_list.sort()
    var tasks: Array[Variant] = _priority_list.values()
    var task: Variant
    for i in range(tasks.size() - 1, -1, -1):
        task = tasks[i]
        if task is Array:
            for t in task:
                (t as BehaviorGoal).perform_actions(self)
        else:
            (task as BehaviorGoal).perform_actions(self)
    _priority_list.clear()

    # Clear sense activations
    for sense in senses:
        sense.activated = false


## Called by goals during the action phase.
## Calling this from a goal's 'update_priority()' method is an error.
func act(action: BehaviorAction) -> void:
    # NOTE: for development, should be removed
    if is_sorting_phase:
        push_error('BehaviorMind cannot `act()` during the goal sorting phase! Investigate!')
        return

    var name: StringName = action.name()
    if not _actions_called.has(name):
        var called: Array[BehaviorAction] = [action]
        _actions_called.set(name, called)
    else:
        _actions_called.get(name).append(action)

    if parent and parent._handle_action(action):
        return

    # Default action behaviors
    # TODO

## If an action of the given type has been called previously this update
func has_acted(action: StringName) -> bool:
    return _actions_called.has(action)

## Get the number of times an action has been called previously on this update
func get_acted_count(action: StringName) -> int:
    return _actions_called.get(action).size()

## Get the actions of the type that have previously been called on this update
func get_acted_list(action: StringName) -> Array[BehaviorAction]:
    return _actions_called.get(action)


func _can_goal_process(goal: BehaviorGoal) -> bool:
    if not goal.sense_activated:
        return true

    if _any_senses_activated(goal.sense_code_names):
        return true

    # Goal requires a sense to be processed
    if goal.minimum_period == 0:
        return false

    # Otherwise, the goal may be periodically processed anyway

    var timer: float = _goal_minimum_period.get_or_add(goal.code_name, 0)
    timer += delta_time

    if timer > goal.minimum_period:
        # NOTE: activate only once per timer, even if a big delta happens
        _goal_minimum_period.set(goal.code_name, 0)
        return true

    _goal_minimum_period.set(goal.code_name, timer)
    return false

## Helper to check iy any senses are currently marked as activated for goal
## processing.
func _any_senses_activated(code_names: Array[StringName]) -> bool:
    for name in code_names:
        if not _code_to_sense.has(name):
            for sense in senses:
                if sense.code_name == name:
                    _code_to_sense.set(name, sense)
                    break
        var sense: BehaviorSense = _code_to_sense.get(name)

        # NOTE: for development, should be removed
        if not sense:
            push_warning('missing sense code named "' + name + '" in BehaviorMind! Investigate!')
            continue

        if sense.activated:
            return true
    return false
