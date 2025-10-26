## Container for a memory bank, goals, actions, and senses
class_name BehaviorMind extends Resource


static var DEBUG_SCENE: PackedScene = preload("uid://cma3vinjxx686")


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


@export_group('Debug', 'debug')

@export_custom(PROPERTY_HINT_GROUP_ENABLE, '')
var debug_enabled: bool = false

## Show a log of actions taken by goals
@export var debug_show_actions: bool = false

## Print actions taken to the console
@export var debug_print_actions: bool = false



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

    ## If the goal should update when the action completes, regardless of any
    ## trigger settings.
    var update_on_complete: bool:
        set(value):
            if _locked:
                return
            update_on_complete = value

    ## Will be true only if the action is complete and caused a goal to process
    var just_completed: bool:
        set(value):
            if _locked:
                return
            just_completed = value

    ## Goals that also want to be updated when this action completes
    var watching_goals: Array[BehaviorGoal]

    # TODO: for dev only, should be removed
    var _locked: bool = false


var parent: CharacterBase
var memory_bank: BehaviorMemoryBank
var delta_time: float

var is_sorting_phase: bool = false

var _priority_list: Dictionary[int, Array]
var _current_goal: BehaviorGoal
var _current_priority: int
var _code_to_sense: Dictionary[StringName, BehaviorSense]
var _goal_minimum_period: Dictionary[StringName, float]
var _actions_called: Dictionary[StringName, CalledAction]
var _recent_actions: Array[StringName]

var debug: BehaviorDebugScene
var debug_root: Node3D


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

    if debug_enabled and debug_root:
        if not debug:
            debug = DEBUG_SCENE.instantiate()
            debug_root.add_child(debug)

    _recent_actions.clear()

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
        if not goal.enabled or not _can_goal_process(goal):
            continue

        priority = goal.process_memory(self)
        if priority < 1:
            continue

        if not _priority_list.has(priority):
            _priority_list.set(priority, [goal])
            continue

        var value: Array = _priority_list.get(priority)
        value.append(goal)
        continue

    is_sorting_phase = false

    # Perform goals
    _priority_list.sort()
    var priorities: Array = _priority_list.keys()
    var tasks: Array
    for i in range(priorities.size() - 1, -1, -1):
        _current_priority = priorities[i]
        tasks = _priority_list.get(_current_priority)
        for t in tasks:
            _current_goal = t
            # GlobalWorld.print('Goal: ' + t.code_name)
            (t as BehaviorGoal).perform_actions(self)
    _current_goal = null
    _priority_list.clear()

    # Clear sense activations
    for sense in senses:
        sense.activated = false
    for sense in secondary_senses:
        sense.activated = false

    # Clear action completions
    for action_name in _actions_called.keys():
        var action: CalledAction = _actions_called.get(action_name)
        action._locked = false
        action.just_completed = false
        action._locked = true


## Called by goals during the action phase. Can pass `true` for `update_on_complete`
## to request running the goal again when the given action completes. Use
## `custom_priority` to set a priority on the action, but it cannot be higher
## than the calling goal's current priority.
## Calling this from a goal's 'update_priority()' method is an error.
func act(action: BehaviorAction, update_on_complete: bool = false, custom_priority: int = 0) -> void:
    # NOTE: for development, should be removed
    if is_sorting_phase:
        push_error('BehaviorMind cannot `act()` during the goal sorting phase! Investigate!')
        return

    var name: StringName = action.name()
    var called_action: CalledAction = _actions_called.get(name)
    if not called_action:
        called_action = CalledAction.new()
        _actions_called.set(name, called_action)

    if not _recent_actions.has(name):
        _recent_actions.append(name)

    if debug_enabled and debug_show_actions:
        _debug_action(action)

    called_action._locked = false
    called_action.action = action
    called_action.goal = _current_goal
    if custom_priority == 0:
        called_action.priority = _current_priority
    else:
        called_action.priority = mini(_current_priority, custom_priority)
    called_action.update_on_complete = update_on_complete
    called_action.just_completed = false
    called_action.watching_goals = []
    called_action._locked = true

    if parent and parent._handle_action(action):
        return

    # Default action behaviors
    # TODO

## If an action of the given type has been called previously
func has_acted(action: StringName) -> bool:
    return _actions_called.has(action)

## Get the actions of the type that have been called previously
func get_acted(action: StringName) -> CalledAction:
    return _actions_called.get(action)

## Test if an action was recently called on this update
func is_recent_action(action: StringName) -> bool:
    return _recent_actions.has(action)

## Called by goals to disable 'update_on_complete' for certain actions. Does
## nothing if the last action goal does not match the currently processing goal.
func disable_on_complete(action: StringName) -> void:
    if not _current_goal:
        return

    if not _actions_called.has(action):
        return

    var called: CalledAction = _actions_called.get(action)
    if called.goal != _current_goal:
        return

    called._locked = false
    called.update_on_complete = false
    called._locked = true

## Adds the calling goal as a candidate for 'update_on_complete' actions. The
## priority of the action must be equal or lower priority than the calling goal.
## Does nothing if the action has not been called, or does have 'update_on_complete'
## set to `true`.
func add_on_complete(action: StringName) -> void:
    if not _current_goal:
        return

    if not _actions_called.has(action):
        return

    var called: CalledAction = _actions_called.get(action)
    if !called.update_on_complete:
        return

    if called.priority > _current_priority:
        return

    if called.watching_goals.has(_current_goal):
        return

    # NOTE: because arrays... _locked is pointless
    # called._locked = false
    called.watching_goals.append(_current_goal)
    # called._locked = true

func _can_goal_process(goal: BehaviorGoal) -> bool:
    if _is_goal_action_update(goal):
        return true

    if goal.sense_activated:
        if not _is_goal_sense_activated(goal):
            return false

    if goal.interest_activated:
        if not _is_goal_interest_activated(goal):
            return false

    return true

func _is_goal_action_update(goal: BehaviorGoal) -> bool:
    for action_name in _actions_called.keys():
        var action: CalledAction = _actions_called.get(action_name)
        if not action or !action.update_on_complete or !action.action.is_complete():
            continue
        if action.goal == goal or action.watching_goals.has(goal):
            if !action.just_completed:
                action._locked = false
                action.just_completed = true
                action._locked = true
            return true

    return false

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

func _debug_action(action: BehaviorAction) -> void:
    if not debug:
        return

    var message: String = (
        ("[[color=thistle]%.3f[/color]] " % GlobalWorld.get_game_time()) +
        "[color=light_cyan]" + _current_goal.code_name + "[/color] >> " +
        "[color=wheat]" + action.name() + "[/color]"
    )

    debug.add_action(message)

    if debug_print_actions:
        GlobalWorld.print(message, false)
