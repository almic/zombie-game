## Container for a memory bank, goals, actions, and senses
class_name BehaviorMind extends Resource


@export var senses: Array[BehaviorSense] = []
@export var secondary_senses: Array[BehaviorSense] = []
@export var goals: Array[BehaviorGoal] = []

@export_group('Memory', 'memory')

## Tick frequency for memory decay, higher values result in more frequent updates
## to memory. 60 = 1 update per second, 15 = 4 updates per second
@export var memory_decay_rate: int = 15:
    set(value):
        memory_decay_rate = value
        if memory_bank:
            memory_bank.decay_frequency = float(value) / 60.0


## Info for a previously called action
class CalledAction:
    ## The action that was called
    var action: BehaviorAction:
        set(value):
            if _locked:
                return
            action = value

    ## The goal that called the action
    var goal: BehaviorGoal:
        set(value):
            if _locked:
                return
            goal = value

    ## The reported priority of the goal when it ran the action
    var priority: int:
        set(value):
            if _locked:
                return
            priority = value

    # TODO: for dev only, should be removed
    var _locked: bool = false


var parent: CharacterBase
var memory_bank: BehaviorMemoryBank
var delta_time: float

var is_sorting_phase: bool = false

var _priority_list: Dictionary
var _current_goal: BehaviorGoal
var _current_priority: int
var _code_to_sense: Dictionary[StringName, BehaviorSense]
var _goal_minimum_period: Dictionary[StringName, float]
var _actions_called: Dictionary[StringName, CalledAction]


func _init() -> void:
    memory_bank = BehaviorMemoryBank.new()
    _priority_list = {}
    _code_to_sense = {}
    _goal_minimum_period = {}
    _actions_called = {}

    senses = senses.duplicate(true)
    secondary_senses = secondary_senses.duplicate(true)
    goals = goals.duplicate(true)
    memory_decay_rate = memory_decay_rate


## Retrieve a sense by name. If two senses are the same type, returns the first one.
func get_sense(name: StringName) -> BehaviorSense:
    for sense in senses:
        if name == sense.name():
            return sense
    for sense in secondary_senses:
        if name == sense.name():
            return sense
    return null

## Retrieve a sense by code name. Code names may be unique between senses of the
## same type, so it is possible to get a specific sense.
func get_sense_by_code_name(code_name: StringName) -> BehaviorSense:
    if _code_to_sense.has(code_name):
        return _code_to_sense.get(code_name)

    for sense in senses:
        if sense.code_name == code_name:
            _code_to_sense.set(code_name, sense)
            return sense

    for sense in secondary_senses:
        if sense.code_name == code_name:
            _code_to_sense.set(code_name, sense)
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

    # Process senses to update memories
    memory_bank.locked = false
    memory_bank.decay_memories(delta_time)
    for sense in senses:
        if sense.tick():
            sense.on_sense.emit(sense)
            sense.sense(self)
    for sense in secondary_senses:
        if sense.tick():
            sense.on_sense.emit(sense)
            sense.sense(self)
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
    var priorities: Array = _priority_list.keys()
    var task: Variant
    for i in range(priorities.size() - 1, -1, -1):
        _current_priority = priorities[i]
        task = _priority_list.get(_current_priority)
        if task is Array:
            for t in task:
                _current_goal = t
                (t as BehaviorGoal).perform_actions(self)
        else:
            _current_goal = task
            (task as BehaviorGoal).perform_actions(self)
    _priority_list.clear()

    # Clear sense activations
    for sense in senses:
        sense.activated = false
    for sense in secondary_senses:
        sense.activated = false


## Called by goals during the action phase.
## Calling this from a goal's 'update_priority()' method is an error.
func act(action: BehaviorAction) -> void:
    # NOTE: for development, should be removed
    if is_sorting_phase:
        push_error('BehaviorMind cannot `act()` during the goal sorting phase! Investigate!')
        return

    var name: StringName = action.name()
    var called_action: CalledAction = _actions_called.get(name)
    if not called_action:
        called_action = CalledAction.new()
        _actions_called.set(name, called_action)

    called_action._locked = false
    called_action.action = action
    called_action.goal = _current_goal
    called_action.priority = _current_priority
    called_action._locked = true

    if parent and parent._handle_action(action):
        return

    # Default action behaviors
    # TODO

## If an action of the given type has been called previously
func has_acted(action: StringName) -> bool:
    return _actions_called.has(action)

## Get the actions of the type that have previously been called on this update
func get_acted(action: StringName) -> CalledAction:
    return _actions_called.get(action)


func _can_goal_process(goal: BehaviorGoal) -> bool:
    if goal.sense_activated:
        if not _is_goal_sense_activated(goal):
            return false

    if goal.interest_activated:
        if not _is_goal_interest_activated(goal):
            return false

    return true

func _is_goal_sense_activated(goal: BehaviorGoal) -> bool:
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

func _is_goal_interest_activated(goal: BehaviorGoal) -> bool:
    var interest_memory: BehaviorMemoryInterest = memory_bank.get_memory_reference(BehaviorMemoryInterest.NAME)

    if not interest_memory:
        return false

    return interest_memory.get_interest() >= goal.interest_threshold

## Helper to check if any senses are currently marked as activated for goal
## processing.
func _any_senses_activated(code_names: Array[StringName]) -> bool:
    for name in code_names:
        var sense: BehaviorSense = get_sense_by_code_name(name)

        # NOTE: for development, should be removed
        if not sense:
            push_warning('missing sense code named "' + name + '" in BehaviorMind! Investigate!')
            continue

        if sense.activated:
            return true

    return false
